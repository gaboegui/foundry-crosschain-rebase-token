// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";


contract Vault {

    IRebaseToken private immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);
    
    error Vault__RedeemTransferFoundsFailed();

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }
    
    /**
     * @notice Its purpose is to allow a smart contract to accept incoming Ether that is sent to it without 
     * any associated data (i.e., via a plain transfer or .send() / .transfer() calls).
     */
    receive() external payable {}

    function deposit() external payable {
        uint256 interestRate = i_rebaseToken.getInterestRate();
        i_rebaseToken.mint(msg.sender, msg.value, interestRate);
        emit Deposit(msg.sender, msg.value);
    }

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

    function getRebaseTokenAddress() public view returns (address) {
        return address(i_rebaseToken);
    }
}



