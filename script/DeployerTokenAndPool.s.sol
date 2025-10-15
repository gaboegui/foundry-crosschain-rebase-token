// SPDX-License-Identifier: MIT
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

contract TokenAndPoolDeployer is Script {
    function run() public returns (RebaseToken rebaseToken, RebaseTokenPool rebaseTokenPool){
        // Chain Link Local and Data for configuration
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
 
        vm.startBroadcast();
        // Token and tokenPool SETUP
        rebaseToken = new RebaseToken();
        rebaseTokenPool = new RebaseTokenPool(IERC20(address(rebaseToken)), new address[](0),
            networkDetails.rmnProxyAddress, networkDetails.routerAddress);
        vm.stopBroadcast(); 
    }
}

contract SetPermissions is Script {
    
    function grantRole ( address rebaseToken, address rebaseTokenPool) public {
        vm.startBroadcast();
        IRebaseToken(rebaseToken).grantMintAndBurnRole(address(rebaseTokenPool));
        vm.startBroadcast();
    }

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

contract VaultDeployer is Script {
    function run (address rebaseToken) public returns (Vault vault){ 
        vm.startBroadcast();
        vault = new Vault(IRebaseToken(rebaseToken));
        IRebaseToken(rebaseToken).grantMintAndBurnRole(address(vault));
        vm.stopBroadcast();
    }
}


