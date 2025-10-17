// SPDX-License-Identifier: MIT
/**
 * @title Deployment and Configuration Scripts
 * @author Gabriel Eguiguren
 * @notice This file contains a suite of scripts for deploying and configuring the RebaseToken ecosystem.
 * It includes scripts for deploying the token and its pool, setting necessary permissions, and deploying the vault.
 */
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
import { CCIPLocalSimulatorFork, Register } from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import { IERC20 } from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import { RegistryModuleOwnerCustom } from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import { TokenAdminRegistry } from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";


import { RebaseToken } from "../src/RebaseToken.sol";
import { IRebaseToken } from "../src/interfaces/IRebaseToken.sol";
import { Vault } from "../src/Vault.sol";
import { RebaseTokenPool } from "../src/RebaseTokenPool.sol";

/**
 * @notice Deploys the RebaseToken and RebaseTokenPool contracts.
 */
contract TokenAndPoolDeployer is Script {
    /**
     * @notice Executes the deployment of the token and pool.
     * @return token The newly deployed RebaseToken.
     * @return pool The newly deployed RebaseTokenPool.
     */
    function run() public returns (RebaseToken token, RebaseTokenPool pool){
        // Chain Link Local and Data for configuration
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
 
        vm.startBroadcast();
        // Token and tokenPool SETUP
        token = new RebaseToken();
        pool = new RebaseTokenPool(IERC20(address(token)), new address[](0),
            networkDetails.rmnProxyAddress, networkDetails.routerAddress);
        vm.stopBroadcast(); 
    }
}

/**
 * @notice Sets the necessary permissions for the RebaseToken ecosystem.
 */
contract SetPermissions is Script {
    
    /**
     * @notice Grants the MINT_AND_BURN_ROLE to the RebaseTokenPool.
     * @param rebaseToken The address of the RebaseToken.
     * @param rebaseTokenPool The address of the RebaseTokenPool.
     */
    function grantRole ( address rebaseToken, address rebaseTokenPool) public {
        vm.startBroadcast();
        IRebaseToken(rebaseToken).grantMintAndBurnRole(address(rebaseTokenPool));
        vm.stopBroadcast();
    }

    /**
     * @notice Sets the admin for the RebaseToken in the TokenAdminRegistry.
     * @param rebaseToken The address of the RebaseToken.
     * @param rebaseTokenPool The address of the RebaseTokenPool.
     */
    function setAdmin(address rebaseToken, address rebaseTokenPool) public {
        // Chain Link Local and Data for configuration
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startBroadcast();
        // CCIP SETUP:
        // claim role
        RegistryModuleOwnerCustom registryModuleOwner = RegistryModuleOwnerCustom(networkDetails.registryModuleOwnerCustomAddress);
        registryModuleOwner.registerAdminViaOwner(address(rebaseToken));
        // accept admin role
        TokenAdminRegistry tokenAdminRegistry = TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress);
        tokenAdminRegistry.acceptAdminRole(address(rebaseToken));
        // linking tokens to pools
        tokenAdminRegistry.setPool(address(rebaseToken), address(rebaseTokenPool));
        vm.stopBroadcast();
    }   
}

/**
 * @notice Deploys the Vault contract.
 */
contract VaultDeployer is Script {
    /**
     * @notice Executes the deployment of the Vault.
     * @param rebaseToken The address of the RebaseToken.
     * @return vault The newly deployed Vault.
     */
    function run (address rebaseToken) public returns (Vault vault){ 
        vm.startBroadcast();
        vault = new Vault(IRebaseToken(rebaseToken));
        IRebaseToken(rebaseToken).grantMintAndBurnRole(address(vault));
        vm.stopBroadcast();
    }
}