// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { RebaseToken } from "../../src/RebaseToken.sol";
import { IRebaseToken } from "../../src/interfaces/IRebaseToken.sol";
import { Vault } from "../../src/Vault.sol";
import { RebaseTokenPool } from "../../src/RebaseTokenPool.sol";

import { CCIPLocalSimulatorFork, Register } from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import { IERC20 } from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import { RegistryModuleOwnerCustom } from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import { TokenAdminRegistry } from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import { TokenPool } from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import { RateLimiter } from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import { Client } from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import { IRouterClient } from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";

contract CrossChainRebaseToken is Test {

    uint256 constant FOUND_VALUE = 1 ether;

    uint256 sepholiaFork;
    uint256 arbitrumSepoliaFork;
    
    address public owner = makeAddr("owner");
    address user = makeAddr("user");

    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;

    RebaseToken private sepoliaToken;
    RebaseToken private arbitrumSepoliaToken;
    Vault private vault;

    RebaseTokenPool private sepoliaPool;
    RebaseTokenPool private arbitrumSepoliaPool;

    Register.NetworkDetails public sepoliaNetworkDetails;
    Register.NetworkDetails public arbitrumSepoliaNetworkDetails;

    RegistryModuleOwnerCustom public registryModuleOwnerCustom;
    TokenAdminRegistry public tokenAdminRegistry;

    function setUp() public {
        
        // string memory DESTINATION_RPC_URL = vm.envString("ETHEREUM_SEPOLIA_RPC_URL");
        // sepholiaFork = vm.createSelectFork(DESTINATION_RPC_URL);
        
        //defined in foundry.toml -> rpc_endpoints
        sepholiaFork = vm.createSelectFork("sepholia-eth");
        arbitrumSepoliaFork = vm.createFork("arbitrun-sepolia");

        // Chain Link Local
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork)); // to be used in the two blockchains

        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        
        // Origin Blockchain 1) Deploy and configure on sepolia
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        // 1.1 create pool with chainlink local
        sepoliaPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)), 
            new address[](0), // allow list
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );
        vault = new Vault(IRebaseToken(address(sepoliaToken)));
        vm.deal(address(vault), FOUND_VALUE);
        sepoliaToken.grantMintAndBurnRole(address(vault));

        // 1.2 Set permissions to pool
        sepoliaToken.grantMintAndBurnRole(address(sepoliaPool));
        // claim role on sepolia
        registryModuleOwnerCustom = RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress);
        registryModuleOwnerCustom.registerAdminViaOwner(address(sepoliaToken));
        // accept admin role on sepolia
        tokenAdminRegistry = TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress);
        tokenAdminRegistry.acceptAdminRole(address(sepoliaToken));
        // 1.3 Linking tokens to pools
        tokenAdminRegistry.setPool(address(sepoliaToken), address(sepoliaPool));
        vm.stopPrank();

        // Destiny Blockchain 2) Deploy and configure on arbitrum-sepolia
        vm.selectFork(arbitrumSepoliaFork);
        vm.startPrank(owner);
        arbitrumSepoliaToken = new RebaseToken();

        // 2.1 create pool with chainlink local
        arbitrumSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        arbitrumSepoliaPool = new RebaseTokenPool(
            IERC20(address(arbitrumSepoliaToken)), 
            new address[](0), // allow list
            arbitrumSepoliaNetworkDetails.rmnProxyAddress,
            arbitrumSepoliaNetworkDetails.routerAddress
        );
        // 2.2 Set permissions to pool, register owner and accept admin role
        arbitrumSepoliaToken.grantMintAndBurnRole(address(arbitrumSepoliaPool));
        registryModuleOwnerCustom = RegistryModuleOwnerCustom(arbitrumSepoliaNetworkDetails.registryModuleOwnerCustomAddress);
        registryModuleOwnerCustom.registerAdminViaOwner(address(arbitrumSepoliaToken));

        tokenAdminRegistry = TokenAdminRegistry(arbitrumSepoliaNetworkDetails.tokenAdminRegistryAddress);
        tokenAdminRegistry.acceptAdminRole(address(arbitrumSepoliaToken));
        // 2.3 Set pool
        tokenAdminRegistry.setPool(address(arbitrumSepoliaToken), address(arbitrumSepoliaPool));
        vm.stopPrank();
        // 2.4 Configure pools
        configureTokenPool(sepholiaFork, 
            address(sepoliaPool), 
            address(arbitrumSepoliaPool),
            arbitrumSepoliaNetworkDetails.chainSelector,
            address(arbitrumSepoliaToken));
        configureTokenPool(
            arbitrumSepoliaFork, 
            address(arbitrumSepoliaPool), 
            address(sepoliaPool),
            sepoliaNetworkDetails.chainSelector,
            address(sepoliaToken));
  

    }

    /**
     * @dev function to configure and Updates Token Pools with all neccesary data    
     */
    function configureTokenPool(uint256 networkFork, 
            address originPool, 
            address remotePool, 
            uint64 remoteChainSelector, 
            address remoteTokenAddress
    ) public{
        vm.selectFork(networkFork);
        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(remotePool);
        
        // fill the required struct
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            remotePoolAddresses: remotePoolAddresses,
            remoteTokenAddress: abi.encode(remoteTokenAddress),
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

        vm.prank(owner);
        TokenPool(originPool).applyChainUpdates(
            new uint64[](0), // blockchains to remove
            chainsToAdd
        ); 
    }

    /*
     * @dev Function that will send the tokens between two chains
     * @dev some assertions are perfomed inside this function to simplify the calls in test methods
     * 
     * @param amountToBridge 
     * @param originFork 
     * @param destinationFork 
     * @param originNetworkDetails 
     * @param destinationNetworkDetails 
     * @param originToken 
     * @param destinationToken 
     */
    function bridgeTokens(uint256 amountToBridge, uint256 originFork, uint256 destinationFork,
        Register.NetworkDetails memory originNetworkDetails, 
        Register.NetworkDetails memory destinationNetworkDetails,
        RebaseToken originToken, RebaseToken destinationToken
    ) public {
        vm.selectFork(originFork);
     
        // set the amount
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(originToken),
            amount: amountToBridge
        });
        // set the message data
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(address(user)),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: originNetworkDetails.linkAddress,  // we will pay with LINK
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV2({gasLimit: 500_000, allowOutOfOrderExecution: false}))
        });

        // get the fee on the destination chain and found the account to pay it
        uint256 fee = IRouterClient(originNetworkDetails.routerAddress)
            .getFee(destinationNetworkDetails.chainSelector, message);
        ccipLocalSimulatorFork.requestLinkFromFaucet(user, fee);
        
        // and aprove it to spend the fee and amountToBridge
        vm.prank(user);
        IERC20(originNetworkDetails.linkAddress)
            .approve(address(originNetworkDetails.routerAddress), fee);
        vm.prank(user);
        IERC20(address(originToken))
            .approve(address(originNetworkDetails.routerAddress), amountToBridge);
        
        uint256 originBalanceBefore = originToken.balanceOf(user);
        uint256 originUserInterest = originToken.getUserInterestRate(user);

        // finally send the tokens
        vm.prank(user);
        IRouterClient(originNetworkDetails.routerAddress)
            .ccipSend(destinationNetworkDetails.chainSelector, message);
        
        uint256 originBalanceAfter = originToken.balanceOf(user);
        assertEq(originBalanceAfter, originBalanceBefore - amountToBridge);

        vm.selectFork(destinationFork);
        vm.warp(block.timestamp + 20 minutes);
        uint256 destinationBalanceBefore = destinationToken.balanceOf(user);

        // this propagates the message and send it crosschain
        vm.selectFork(originFork);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(destinationFork);

        uint256 destinationBalanceAfter = destinationToken.balanceOf(user);
        uint256 destinationUserInterest = destinationToken.getUserInterestRate(user);

        assertEq(destinationBalanceAfter, destinationBalanceBefore + amountToBridge);
        assertEq(originUserInterest, destinationUserInterest);
    }

    function testBridgeAllTokens() public {
        vm.selectFork(sepholiaFork);
        vm.deal(user, FOUND_VALUE);
        vm.prank(user);
        Vault(payable (address(vault))).deposit{value: FOUND_VALUE}();

        // from sepolia to arbitrum-sepolia
        bridgeTokens(FOUND_VALUE, sepholiaFork, arbitrumSepoliaFork, 
            sepoliaNetworkDetails, arbitrumSepoliaNetworkDetails, 
            sepoliaToken, arbitrumSepoliaToken);
        
        // from arbitrum-sepolia to sepolia
        vm.selectFork(arbitrumSepoliaFork);
        vm.warp(block.timestamp + 20 minutes);

        bridgeTokens(arbitrumSepoliaToken.balanceOf(user), arbitrumSepoliaFork, sepholiaFork, 
            arbitrumSepoliaNetworkDetails, sepoliaNetworkDetails, 
            arbitrumSepoliaToken, sepoliaToken);
    }
}