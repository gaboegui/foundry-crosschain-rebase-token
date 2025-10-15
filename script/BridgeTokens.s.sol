// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";

import { Client } from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import { IRouterClient } from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import { IERC20 } from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";


contract BridgeTokens is Script{
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
        tokenAmounts[0] = Client.EVMTokenAmount({ token: address(tokenToSendAddress), amount: amountToSend});

        vm.startBroadcast();
        // set the message data
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverAddress), data: "",
            tokenAmounts: tokenAmounts,
            feeToken: linkTokenAddress,  // could be LINK or other token
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV2({gasLimit: 500_000, allowOutOfOrderExecution: false}))
        });

        // get the fee on the destination chain and found the account to pay it
        uint256 ccipFee = IRouterClient(routerAddress).getFee(destinationChainSelector, message);
        // aprove to spend
        IERC20(linkTokenAddress).approve(address(routerAddress), ccipFee);
        IERC20(tokenToSendAddress).approve(address(routerAddress), amountToSend);
        // finally send the tokens
        IRouterClient(routerAddress).ccipSend(destinationChainSelector, message);
        vm.stopBroadcast();
    
    }
}