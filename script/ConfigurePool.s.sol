// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
import { TokenPool } from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import { RateLimiter } from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";

contract ConfigurePool is Script {
    
    /*
     * 
     * @dev could be improved passing: outboundRateLimiterConfig and inboundRateLimiterConfig values
     * @param originPool 
     * @param remotePool 
     * @param remoteChainSelector 
     * @param remoteToken 
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