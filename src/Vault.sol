// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

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
        i_rebaseToken.mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function redeem(uint256 _amount) external payable {
        i_rebaseToken.burn(msg.sender, msg.value); // first burn
        
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



