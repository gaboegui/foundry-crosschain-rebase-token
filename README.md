# Foundry Crosschain Rebase Token

This project implements a cross-chain rebase token ecosystem built on Ethereum-compatible blockchains using Foundry. The system consists of a RebaseToken that automatically adjusts its supply based on a defined interest rate, incentivizing users to deposit into a vault for earning interest. The token supports cross-chain transfers via Chainlink's Cross-Chain Interoperability Protocol (CCIP), allowing seamless movement of tokens between different blockchain networks while preserving user interest rates.

## Overview

The project includes the following key components:

- **RebaseToken**: An ERC20-compatible token with automatic interest accrual. The token's supply adjusts based on a global interest rate that can only decrease over time. Each user has their own interest rate set at the time of deposit, ensuring fair and predictable earnings.

- **Vault**: A smart contract that allows users to deposit ETH and receive RebaseTokens, and redeem RebaseTokens back to ETH. The vault manages the minting and burning of tokens based on deposits and redemptions.

- **RebaseTokenPool**: A CCIP-compatible token pool that handles cross-chain transfers of RebaseTokens. It manages the burning of tokens on the source chain and minting on the destination chain, while preserving the user's interest rate across chains.

- **Deployment Scripts**: Foundry scripts for deploying and configuring the entire ecosystem, including token bridging and pool configuration.

## Smart Contracts

### Core Contracts

#### [`src/RebaseToken.sol`](src/RebaseToken.sol)
- Implements a cross-chain rebase token with automatic interest accrual
- Interest rate can only decrease, set by the contract owner
- Each user has their own interest rate from the time of deposit
- Supports minting and burning with role-based access control
- Overrides standard ERC20 functions to include accumulated interest in balances

#### [`src/Vault.sol`](src/Vault.sol)
- Allows users to deposit ETH and mint RebaseTokens
- Enables redemption of RebaseTokens back to ETH
- Integrates with RebaseToken for minting/burning operations

#### [`src/RebaseTokenPool.sol`](src/RebaseTokenPool.sol)
- Extends CCIP TokenPool for cross-chain RebaseToken transfers
- Preserves user interest rates during cross-chain operations
- Handles burning on source chain and minting on destination chain

#### [`src/interfaces/IRebaseToken.sol`](src/interfaces/IRebaseToken.sol)
- Interface defining external functions for RebaseToken interactions

### Deployment Scripts

#### [`script/Deployer.s.sol`](script/Deployer.s.sol)
- Contains deployment scripts for the entire ecosystem
- Includes TokenAndPoolDeployer, SetPermissions, and VaultDeployer contracts
- Handles CCIP configuration and permission setup

#### [`script/BridgeTokens.s.sol`](script/BridgeTokens.s.sol)
- Script for bridging tokens across chains using CCIP
- Handles token approvals and cross-chain message creation

#### [`script/ConfigurePool.s.sol`](script/ConfigurePool.s.sol)
- Configures token pools for cross-chain connectivity
- Sets up remote chain connections and rate limiting

## Features

- **Automatic Interest Accrual**: Tokens automatically earn interest over time based on individual user rates
- **Cross-Chain Compatibility**: Seamless token transfers between supported blockchains via CCIP
- **Interest Rate Preservation**: User interest rates are maintained during cross-chain transfers
- **Secure Minting/Burning**: Role-based access control for token supply operations
- **Vault Integration**: ETH-backed token system with deposit/redeem functionality

## Prerequisites

- Foundry (latest version)
- Node.js and npm (for CCIP dependencies)
- Access to supported blockchain networks (Ethereum, Arbitrum, Polygon, etc.)

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd foundry-crosschain-rebase-token
```

2. Install dependencies:
```bash
forge install
```

3. Build the project:
```bash
forge build
```

## Usage

### Build

```shell
forge build
```

### Test

```shell
forge test
```

### Format

```shell
forge fmt
```

### Gas Snapshots

```shell
forge snapshot
```

## Testing

The project implements three types of tests to ensure comprehensive coverage and reliability:

### Unit Tests
Located in `test/unit/`, these tests validate individual functions and state changes in isolation. They cover core functionality such as minting, burning, transfers, interest rate management, and balance calculations. Unit tests use deterministic inputs to verify expected behavior under controlled conditions.

### Fuzz Tests
Located in `test/fuzz/`, these tests use property-based testing with random inputs to uncover edge cases and potential vulnerabilities. They test properties like interest rate linearity, deposit/redeem functionality, and transfer mechanics across a wide range of inputs, bounded within realistic constraints.

### Fork Tests
Located in `test/fork/`, these tests simulate cross-chain interactions by forking real blockchain networks (Sepolia and Arbitrum Sepolia). They validate end-to-end cross-chain token bridging functionality, ensuring that interest rates are preserved during transfers between different networks using Chainlink's CCIP protocol.

## Complete Example Script: Bridge from Sepolia Ethereum to Arbitrum Sepolia

You should include your own **.env file** with the following variables:
```shell
KEY_STORE_PASSWORD=s3cur3P4assw0rd
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/XXX...
ARB_SEPOLIA_RPC_URL=https://arb-sepolia.g.alchemy.com/v2/XXX...
ETHERSCAN_API_KEY=XEJKAX8M....
ARBISCAN_API_KEY=XEJKAX8M.... 
```

You can run a complete Deploy, Verify and Bridge transfer execution example running the following commands:

```shell
chmod +x ./bridgeToArbitrum.sh
./bridgeToArbitrum.sh
```
### Deployed and Verified Contracts

**ARBITRUM SEPOLIA**

TOKEN: [0x92dF841e734207e72061A63b641922127F336701](https://sepolia.arbiscan.io/address/0x92dF841e734207e72061A63b641922127F336701)

POOL: [0x76D6B5Ba5eE54348a50Fef888adf22cE0D7c9c51](https://sepolia.arbiscan.io/address/0x76D6B5Ba5eE54348a50Fef888adf22cE0D7c9c51)

**ETHEREUM SEPOLIA**

TOKEN: [0x2ddeFc338823E53693CCce0E3EC9214Cc389A9F0](https://sepolia.etherscan.io/address/0x2ddeFc338823E53693CCce0E3EC9214Cc389A9F0)

POOL: [0x78dF725eDad1b5Cd066ec3c649997cBB6a8A8cE0](https://sepolia.etherscan.io/address/0x78dF725eDad1b5Cd066ec3c649997cBB6a8A8cE0)

VAULT: [0xfE5CDfc482280646AC3e8644027BEfAAA602F1c8](https://sepolia.etherscan.io/address/0xfE5CDfc482280646AC3e8644027BEfAAA602F1c8)

### Deploy

You create the ERC-2335: BLS12-381 Keystore with the PRIVATE KEY of the wallet with this command:
```shell
cast wallet import your_Keystore --interactive
```

Deploy the token and pool:
```shell
forge script script/Deployer.s.sol:TokenAndPoolDeployer --rpc-url <your_rpc_url> --account <your_Keystore> --broadcast
```

Set permissions:
```shell
forge script script/Deployer.s.sol:SetPermissions --rpc-url <your_rpc_url> --account <your_Keystore> --broadcast
```

Deploy vault:
```shell
forge script script/Deployer.s.sol:VaultDeployer --rpc-url <your_rpc_url> --account <your_Keystore> --broadcast --sig "run(address)" <rebase_token_address>
```

### Bridge Tokens

```shell
forge script script/BridgeTokens.s.sol:BridgeTokens --rpc-url <your_rpc_url> --account <your_Keystore> --broadcast --sig "run(address,uint64,address,uint256,address,address)" <receiver> <destination_chain_selector> <token_address> <amount> <link_address> <router_address>
```

### Configure Pool

```shell
forge script script/ConfigurePool.s.sol:ConfigurePool --rpc-url <your_rpc_url> --account <your_Keystore> --broadcast --sig "run(address,address,uint64,address)" <origin_pool> <remote_pool> <remote_chain_selector> <remote_token>
```

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

- [Foundry Book](https://book.getfoundry.sh/)
- [Chainlink CCIP Documentation](https://docs.chain.link/ccip)

## Donations

If you found this project helpful, feel free to follow me or make a donation!

**ETH/Arbitrum/Optimism/Polygon/BSC/etc Address:** `0x2210C9bD79D0619C5d455523b260cc231f1C2F0D`

## Contact

[![Gabriel Eguiguren P. X](https://img.shields.io/badge/Twitter-1DA1F2?style=for-the-badge&logo=twitter&logoColor=white)](https://x.com/GaBoEgui)
[![Gabriel Eguiguren P. Linkedin](https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/gabrieleguiguren/)
