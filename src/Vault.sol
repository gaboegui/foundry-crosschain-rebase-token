// SPDX-License-Identifier: MIT
/**
 * @title Vault
 * @author Gabriel Eguiguren
 * @notice This contract serves as a vault for the RebaseToken.
 * Users can deposit Ether and receive RebaseTokens, and redeem their RebaseTokens for Ether.
 */
pragma solidity ^0.8.24;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";


contract Vault {

    IRebaseToken private immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);
    
    error Vault__RedeemTransferFoundsFailed();

    /**
     * @notice Constructor for the Vault.
     * @param _rebaseToken The address of the RebaseToken contract.
     */
    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }
    
    /**
     * @notice Receives Ether sent to the contract.
     */
    receive() external payable {}

    /**
     * @notice Deposits Ether and mints RebaseTokens to the sender.
     */
    function deposit() external payable {
        uint256 interestRate = i_rebaseToken.getInterestRate();
        i_rebaseToken.mint(msg.sender, msg.value, interestRate);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Redeems RebaseTokens for Ether.
     * @param _amount The amount of RebaseTokens to redeem.
     */
    function redeem(uint256 _amount) external payable {
        if(_amount == type(uint256).max){
            _amount = i_rebaseToken.balanceOf(msg.sender); // avoid dust due long time passing in TXs
        }
        
        i_rebaseToken.burn(msg.sender, _amount); // first burn
        
        (bool success,)= payable(msg.sender).call{value: _amount}(""); // then redeem
        if (!success) {
            revert Vault__RedeemTransferFoundsFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    /**
     * @notice Gets the address of the RebaseToken contract.
     * @return The address of the RebaseToken contract.
     */
    function getRebaseTokenAddress() public view returns (address) {
        return address(i_rebaseToken);
    }
}