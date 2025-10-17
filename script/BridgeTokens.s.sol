// SPDX-License-Identifier: MIT
/**
 * @title Bridge Tokens Script
 * @author Gabriel Eguiguren
 * @notice This script facilitates the bridging of tokens to a different blockchain using Chainlink's CCIP.
 * It approves the necessary tokens and initiates a cross-chain message to transfer the specified amount.
 */
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";

import { Client } from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import { IRouterClient } from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import { IERC20 } from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";


contract BridgeTokens is Script{

    /**
     * @notice Executes the token bridging process.
     * @param receiverAddress The address of the receiver on the destination chain.
     * @param destinationChainSelector The chain selector for the destination blockchain.
     * @param tokenToSendAddress The address of the token to be bridged.
     * @param amountToSend The amount of tokens to send.
     * @param linkTokenAddress The address of the LINK token for paying fees.
     * @param routerAddress The address of the CCIP router.
     */
    function run(
        address receiverAddress,
        uint64 destinationChainSelector,
        address tokenToSendAddress,
        uint256 amountToSend,
        address linkTokenAddress,
        address routerAddress
    ) public{
        
        // set the amount
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({ token: tokenToSendAddress, amount: amountToSend});

        // set the message data
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverAddress), data: "",
            tokenAmounts: tokenAmounts,
            feeToken: linkTokenAddress,  // could be LINK or other token
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0}))
        });

        // get the fee on the destination chain and found the account to pay it
        vm.startBroadcast();
        uint256 ccipFee = IRouterClient(routerAddress).getFee(destinationChainSelector, message);
        // aprove to spend
        IERC20(linkTokenAddress).approve(routerAddress, ccipFee);
        IERC20(tokenToSendAddress).approve(routerAddress, amountToSend);
        // finally send the tokens
        IRouterClient(routerAddress).ccipSend(destinationChainSelector, message);
        vm.stopBroadcast();
    }
}