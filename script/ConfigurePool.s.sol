// SPDX-License-Identifier: MIT
/**
 * @title Configure Pool Script
 * @author Gabriel Eguiguren
 * @notice This script is used to configure a token pool for Chainlink's CCIP.
 * It sets up the connection to a remote pool on another blockchain, allowing for cross-chain token transfers.
 */
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
import { TokenPool } from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import { RateLimiter } from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";

contract ConfigurePool is Script {
    
    /**
     * @notice Configures the token pool with the details of a remote chain.
     * @dev could be improved passing: outboundRateLimiterConfig and inboundRateLimiterConfig values
     * @param originPool The address of the token pool on the current chain.
     * @param remotePool The address of the token pool on the remote chain.
     * @param remoteChainSelector The chain selector for the remote blockchain.
     * @param remoteToken The address of the token on the remote chain.
     */
    function run(
        address originPool, 
        address remotePool, 
        uint64 remoteChainSelector, 
        address remoteToken
    ) public{
        vm.startBroadcast();
        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(remotePool);
        
        // fill the required struct
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            remotePoolAddresses: remotePoolAddresses,
            remoteTokenAddress: abi.encode(remoteToken),
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            })
        });
        
        TokenPool(originPool).applyChainUpdates(
            new uint64[](0), // blockchains to remove
            chainsToAdd
        );
        vm.stopBroadcast();
    
    }     
    

}