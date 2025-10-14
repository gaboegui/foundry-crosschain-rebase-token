// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { TokenPool } from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import { Pool  } from "@ccip/contracts/src/v0.8/ccip/libraries/Pool.sol";
import { IERC20 } from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import { IRebaseToken } from "./interfaces/IRebaseToken.sol";

/**
 * @title Token Pool to be implemented with CCIP functionality
 * @author Gabriel Eguiguren P.
 * @notice IERC20 should be the same version of TokenPool.sol
 */
contract RebaseTokenPool is TokenPool {

    uint8 private constant DECIMALS = 18;
    
    constructor (IERC20 token, address[] memory allowlist, address rmnProxy, address router) 
        TokenPool (token, DECIMALS, allowlist, rmnProxy, router) {
    }

    /*
     * 
     * @param lockOrBurnIn 
     */
    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn) 
        external returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut){
        
        _validateLockOrBurn(lockOrBurnIn); // Risk Manag. Network
        // i_token belongs to TokenPool
        uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(lockOrBurnIn.originalSender);
        // the pool is who burns the tokens, but the receiver previously should authorize that burn 
        IRebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);

        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userInterestRate)   // this is the extra data sended crosschain
        });

    }

    /*
     * 
     * @param releaseOrMintIn 
     */
    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn) 
        external returns (Pool.ReleaseOrMintOutV1 memory){

        _validateReleaseOrMint(releaseOrMintIn); // Risk Manag. Network
        // decode the extra data
        uint256 userInterestRate = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));
        
        IRebaseToken(address(i_token)).mint(releaseOrMintIn.receiver, 
            releaseOrMintIn.amount, userInterestRate);
        return Pool.ReleaseOrMintOutV1({ destinationAmount: releaseOrMintIn.amount });
    
    }

}