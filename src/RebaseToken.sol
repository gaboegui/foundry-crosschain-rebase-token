// SPDX-License-Identifier: MIT
/**
 * @title Rebase Token
 * @author Gabriel Eguiguren
 * @notice This contract implements a cross-chain rebase token.
 * The token's supply adjusts automatically based on a defined interest rate.
 * It's designed to incentivize users to deposit their tokens into a vault to earn interest.
 */
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @notice This is a cross-chain rebase token that incentivates users to deposit into a vault and gain interest.
 * @notice The interest rate in the smart contract can only decrease by the owner of the contract.
 * @notice Each user will have their own interest rate that is the global interest rate at the time of depositing
 */
contract RebaseToken is ERC20, Ownable, AccessControl {

    error RebaseToken__InterestRateCanOnlyDecrease(uint256 _interestRate, uint256 s_interestRate);

    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private constant PRECISION_FACTOR = 1e18;  // avoid truncation errors
    uint256 private s_interestRate = (5 * PRECISION_FACTOR) / 1e8; // interest per second
    mapping (address => uint256) private s_userInterestRate;
    mapping (address => uint256) private s_userLastUpdatedTimeStamp;
    

    event InterestRateSet(uint256 interestRate);

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {
    }

    /**
     * @notice Grants the mint and burn role to a specified user.
     * @param _user The address to grant the role to.
     */
    function grantMintAndBurnRole(address _user) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _user);
    }

    /**
     * @notice Sets the interest rate for the token.
     * @dev The new interest rate must be lower than the current rate.
     * @param _newInterestRate The new interest rate to set.
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if(_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(_newInterestRate, s_interestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(s_interestRate);
    }
    
    /**
     * @notice Mints new tokens to a specified address.
     * @dev This function can only be called by addresses with the MINT_AND_BURN_ROLE.
     * @param _to The address to mint the tokens to.
     * @param _amount The amount of tokens to mint.
     * @param _userInterestRate The interest rate for the user.
     */
    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAcumulatedInterest(_to); // is the value adquired since the first mint
        s_userInterestRate[_to] = _userInterestRate; 
        _mint(_to, _amount);
    }

    /**
     * @notice Burns tokens from a specified address.
     * @dev This function can only be called by addresses with the MINT_AND_BURN_ROLE.
     * @param _from The address to burn the tokens from.
     * @param _amount The amount of tokens to burn.
     */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if(_amount == type(uint256).max ){
            _amount = balanceOf(_from); // mitigation of dust due to rounding errors
        }
        _mintAcumulatedInterest(_from); // we add interest to value adquired since the first mint
        _burn(_from, _amount);
    }

    /**
     * @notice Overrides the default balanceOf function to include accumulated interest.
     * @param _user The address to get the balance of.
     * @return linearInterest The user's balance including interest.
     */
    function balanceOf(address _user) public view override returns (uint256 linearInterest) {
        // every interaction will call this, even small amounts. That could lead to compound interest
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    /**
     * @notice Overrides the default transfer function to mint accumulated interest for both sender and recipient.
     * @param _recipient The address of the recipient.
     * @param _amount The amount to transfer.
     * @return success A boolean indicating whether the transfer was successful.
     */
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

    /**
     * @notice Overrides the default transferFrom function to mint accumulated interest for both sender and recipient.
     * @param _sender The address of the sender.
     * @param _recipient The address of the recipient.
     * @param _amount The amount to transfer.
     * @return success A boolean indicating whether the transfer was successful.
     */
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

    /**
     * @notice Calculates the accumulated interest for a user since their last update.
     * @param _user The address of the user.
     * @return linearInterest The accumulated interest.
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user) internal view 
        returns (uint256 linearInterest ) {
        uint256 timePassed = block.timestamp - s_userLastUpdatedTimeStamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timePassed);
    }

    /**
     * @notice Mints the accumulated interest to the user since the last interaction with the protocol.
     * @param _user The destination for the interest.
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

    function getUserInterestRate(address _user) external view returns (uint256) {
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
    function getInterestRate() external view returns (uint256 interest) {
        return s_interestRate;
    }
}