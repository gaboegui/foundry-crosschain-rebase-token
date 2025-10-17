// SPDX-License-Identifier: MIT
/**
 * @title Cross-Chain Rebase Token Test
 * @author Gabriel Eguiguren
 * @notice This test suite validates the cross-chain functionality of the RebaseToken,
 * ensuring that tokens can be bridged between different blockchains while maintaining their interest rate properties.
 * @dev IMPORTANT: If you are using via_ir = true in foundry.toml or forge build --via-ir
 *   the functions that will use vm.warp are not working due a know BUG
 */
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

    /**
     * @notice Sets up the test environment by forking blockchains, deploying contracts, and configuring CCIP.
     */
    function setUp() public {
        
        string memory ETHEREUM_SEPOLIA = vm.envString("SEPOLIA_RPC_URL");
        string memory ARBITRUM_SEPOLIA = vm.envString("ARB_SEPOLIA_RPC_URL");
        sepholiaFork = vm.createSelectFork(ETHEREUM_SEPOLIA);
        arbitrumSepoliaFork = vm.createFork(ARBITRUM_SEPOLIA);
        
        //defined in foundry.toml -> rpc_endpoints (not used because I dont want to commit the RPC_URLs)
        //sepholiaFork = vm.createSelectFork("sepholia-eth");
        //arbitrumSepoliaFork = vm.createFork("arbitrun-sepolia");

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
     * @notice Configures and updates token pools with necessary data.
     * @param networkFork The fork of the network to select.
     * @param originPool The address of the origin pool.
     * @param remotePool The address of the remote pool.
     * @param remoteChainSelector The chain selector for the remote chain.
     * @param remoteTokenAddress The address of the remote token.
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

    /**
     * @notice Bridges tokens between two chains and performs assertions.
     * @param amountToBridge The amount of tokens to bridge.
     * @param originFork The fork of the origin chain.
     * @dev Function that will send the tokens between two chains
     * @dev some assertions are perfomed inside this function to simplify the calls in test methods
     * @param destinationFork The fork of the destination chain.
     * @param originNetworkDetails The network details of the origin chain.
     * @param destinationNetworkDetails The network details of the destination chain.
     * @param originToken The RebaseToken on the origin chain.
     * @param destinationToken The RebaseToken on the destination chain.
     */
    function bridgeTokens(
        uint256 amountToBridge,
        uint256 originFork,
        uint256 destinationFork,
        Register.NetworkDetails memory originNetworkDetails,
        Register.NetworkDetails memory destinationNetworkDetails,
        RebaseToken originToken,
        RebaseToken destinationToken
    ) public {
        vm.selectFork(originFork);

        Client.EVM2AnyMessage memory message = _buildCcipMessage(
            amountToBridge,
            address(originToken),
            originNetworkDetails.linkAddress
        );

        _approveCcipTokens(
            amountToBridge,
            originNetworkDetails.routerAddress,
            destinationNetworkDetails.chainSelector,
            message,
            originNetworkDetails.linkAddress,
            address(originToken)
        );

        _executeAndVerifyCcipSend(
            originFork,
            destinationFork,
            originNetworkDetails,
            destinationNetworkDetails,
            originToken,
            destinationToken,
            message,
            amountToBridge
        );
    }

    /**
     * @notice Builds the CCIP message for bridging tokens.
     * @param amountToBridge The amount of tokens to bridge.
     * @param tokenAddress The address of the token to bridge.
     * @param feeTokenAddress The address of the fee token.
     * @return message The constructed CCIP message.
     */
    function _buildCcipMessage(
        uint256 amountToBridge,
        address tokenAddress,
        address feeTokenAddress
    ) internal view returns (Client.EVM2AnyMessage memory message) {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](
            1
        );
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: tokenAddress,
            amount: amountToBridge
        });

        message = Client.EVM2AnyMessage({
            receiver: abi.encode(address(user)),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: feeTokenAddress,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV2({
                    gasLimit: 500_000,
                    allowOutOfOrderExecution: false
                })
            )
        });
    }

    /**
     * @notice Approves tokens for CCIP transfer.
     * @param amountToBridge The amount of tokens to bridge.
     * @param routerAddress The address of the CCIP router.
     * @param destinationChainSelector The chain selector of the destination chain.
     * @param message The CCIP message.
     * @param linkAddress The address of the LINK token.
     * @param tokenAddress The address of the token to bridge.
     */
    function _approveCcipTokens(
        uint256 amountToBridge,
        address routerAddress,
        uint64 destinationChainSelector,
        Client.EVM2AnyMessage memory message,
        address linkAddress,
        address tokenAddress
    ) internal {
        uint256 fee = IRouterClient(routerAddress).getFee(
            destinationChainSelector,
            message
        );
        ccipLocalSimulatorFork.requestLinkFromFaucet(user, fee);

        vm.prank(user);
        IERC20(linkAddress).approve(routerAddress, fee);
        vm.prank(user);
        IERC20(tokenAddress).approve(routerAddress, amountToBridge);
    }

    /**
     * @notice Executes the CCIP send and verifies the cross-chain transfer.
     * @param originFork The fork of the origin chain.
     * @param destinationFork The fork of the destination chain.
     * @param originNetworkDetails The network details of the origin chain.
     * @param destinationNetworkDetails The network details of the destination chain.
     * @param originToken The RebaseToken on the origin chain.
     * @param destinationToken The RebaseToken on the destination chain.
     * @param message The CCIP message.
     * @param amountToBridge The amount of tokens bridged.
     */
    function _executeAndVerifyCcipSend(
        uint256 originFork,
        uint256 destinationFork,
        Register.NetworkDetails memory originNetworkDetails,
        Register.NetworkDetails memory destinationNetworkDetails,
        RebaseToken originToken,
        RebaseToken destinationToken,
        Client.EVM2AnyMessage memory message,
        uint256 amountToBridge
    ) internal {
        uint256 originBalanceBefore = originToken.balanceOf(user);
        uint256 originUserInterest = originToken.getUserInterestRate(user);

        vm.prank(user);
        IRouterClient(originNetworkDetails.routerAddress).ccipSend(
            destinationNetworkDetails.chainSelector,
            message
        );

        uint256 originBalanceAfter = originToken.balanceOf(user);
        assertEq(originBalanceAfter, originBalanceBefore - amountToBridge);

        vm.selectFork(destinationFork);
        vm.warp(block.timestamp + 20 minutes);
        uint256 destinationBalanceBefore = destinationToken.balanceOf(user);

        vm.selectFork(originFork);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(destinationFork);

        uint256 destinationBalanceAfter = destinationToken.balanceOf(user);
        uint256 destinationUserInterest = destinationToken.getUserInterestRate(
            user
        );

        assertEq(
            destinationBalanceAfter,
            destinationBalanceBefore + amountToBridge
        );
        assertEq(originUserInterest, destinationUserInterest);
    }

    /**
     * @notice Tests the bridging of all tokens from one chain to another and back.
     */
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