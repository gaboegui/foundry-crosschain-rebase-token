// SPDX-License-Identifier: MIT
/**
 * @title Rebase Token Pool
 * @author Gabriel Eguiguren
 * @notice This contract extends the CCIP TokenPool to handle the cross-chain transfer of RebaseTokens.
 * It manages the burning of tokens on the source chain and the minting of tokens on the destination chain,
 * ensuring that the user's interest rate is preserved across chains.
 */
pragma solidity ^0.8.24;

import { TokenPool } from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import { Pool  } from "@ccip/contracts/src/v0.8/ccip/libraries/Pool.sol";
import { IERC20 } from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import { IRebaseToken } from "./interfaces/IRebaseToken.sol";

/**
 * @notice This contract is a token pool for the RebaseToken, designed to be used with the Chainlink CCIP.
 * It handles the locking and burning of tokens on the source chain and the releasing and minting of tokens on the destination chain.
 */
contract RebaseTokenPool is TokenPool {

    uint8 private constant DECIMALS = 18;
    
    /**
     * @notice Constructor for the RebaseTokenPool.
     * @param token The address of the RebaseToken.
     * @param allowlist An array of addresses that are allowed to interact with the pool.
     * @param rmnProxy The address of the Risk Management Network proxy.
     * @param router The address of the CCIP router.
     */
    constructor (IERC20 token, address[] memory allowlist, address rmnProxy, address router) 
        TokenPool (token, DECIMALS, allowlist, rmnProxy, router) {
    }

    /**
     * @notice Burns the specified amount of tokens and sends the user's interest rate to the destination chain.
     * @param lockOrBurnIn A struct containing the details of the lock or burn operation.
     * @return lockOrBurnOut A struct containing the details of the lock or burn operation.
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

    /**
     * @notice Mints the specified amount of tokens to the receiver with the user's interest rate from the source chain.
     * @param releaseOrMintIn A struct containing the details of the release or mint operation.
     * @return ReleaseOrMintOutV1 A struct containing the details of the release or mint operation.
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