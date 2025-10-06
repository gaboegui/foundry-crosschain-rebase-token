// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Rebase Token
 * @author Gabriel Eguiguren P.
 * @notice This is a cross-chain rebase token that incentivates users to deposit into a vault and gain interest.
 * @notice The interest rate in the smart contract can only decrease by the owner of the contract.
 * @notice Each user will have their own interest rate that is the global interest rate at the time of depositing
 */
contract RebaseToken is ERC20, Ownable, AccessControl {

    error RebaseToken__InterestRateCanOnlyDecrease(uint256 _interestRate, uint256 s_interestRate);

    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private s_interestRate = 5e10; 
    mapping (address => uint256) private s_userInterestRate;
    mapping (address => uint256) private s_userLastUpdatedTimeStamp;
    

    event InterestRateSet(uint256 interestRate);

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {
    }

    // uses AccessControl: _grantRole function
    function grantMintAndBurnRole(address _user) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _user);
    }


    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if(_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(_newInterestRate, s_interestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(s_interestRate);
    }
    
    // implemented access control based on an specific role
    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAcumulatedInterest(_to); // is the value adquired since the first mint
        s_userInterestRate[_to] = s_interestRate; // set user interest rate to global interest rate
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if(_amount == type(uint256).max ){
            _amount = balanceOf(_from); // mitigation of dust due to rounding errors
        }
        _mintAcumulatedInterest(_from); // we add interest to value adquired since the first mint
        _burn(_from, _amount);
    }

    // overrides balanceOf function from ERC20 contract, includes the acumulated interest  
    function balanceOf(address _user) public view override returns (uint256 linearInterest) {
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    function transfer(address _recipient, uint256 _amount) public override returns (bool success) {
        _mintAcumulatedInterest(msg.sender);
        _mintAcumulatedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        // If the recipient dont have founds yet, inherit the sender interest rate
        if(balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool success) {
        _mintAcumulatedInterest(_sender);
        _mintAcumulatedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        // If the recipient dont have founds yet, inherit the sender interest rate
        if(balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transferFrom(_sender,_recipient, _amount);
    }

    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user) internal view 
        returns (uint256 linearInterest ) {
        uint256 timePassed = block.timestamp - s_userLastUpdatedTimeStamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timePassed);
    }

    /**
     * @notice Mint the acumulated interest to the user since the last interaction with the protocol(ex: burn, mint, transfer)
     * @param _user the destination for the interest
     */
    function _mintAcumulatedInterest(address _user) internal {
        // (1) current balance of rebase tokens that have been minted to the user
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        // (2) calculate their current balance including accumulated interest
        uint256 currentBalance = balanceOf(_user);
        // Total to mint in this operation 2-1
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;
        // set the user last time updated 
        s_userLastUpdatedTimeStamp[_user] = block.timestamp;
        _mint(_user, balanceIncrease);
    }

    function getUserInterestRate(address _user) public view returns (uint256) {
        return s_userInterestRate[_user];
    }
    /**
     * @notice Gets the total of minted tokens to the user not including interest since the last interaction with the protocol
     * @param _user the user to get the balance of
     * @return the balance of the user
     */
    function principleBalanceOf(address _user) public view returns (uint256) {
        return super.balanceOf(_user);
    }

    /**
     * @notice This is the global interest rate of the protocol
     * @return interest the global interest rate
     */
    function getInterestRate() public view returns (uint256 interest) {
        return s_interestRate;
    }
}
