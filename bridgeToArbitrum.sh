#!/bin/bash

# Author: Gabriel Eguiguren P.
# Define constants 
AMOUNT=10000000

ARB_SEPOLIA_ROUTER="0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165"
ARB_SEPOLIA_CHAIN_SELECTOR="3478487238524512106"
ARB_SEPOLIA_LINK_ADDRESS="0xb1D4538B4571d411F07960EF2838Ce337FE1E80E"

SEPOLIA_ROUTER="0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59"
SEPOLIA_CHAIN_SELECTOR="16015286601757825753"
SEPOLIA_LINK_ADDRESS="0x779877A7B0D9E8603169DdbD7836e478b4624789"

source .env
# 1. On Arbitrum Sepolia!
echo "Running the script to deploy the contracts on Arbitrum Sepolia..."
output=$(forge script ./script/Deployer.s.sol:TokenAndPoolDeployer --rpc-url ${ARB_SEPOLIA_RPC_URL} --account sepoliaAccount2 --broadcast --verify --etherscan-api-key $ARBISCAN_API_KEY)
echo "Contracts deployed and permission set on Arbitrum Sepolia"

# Extract the addresses from the output
ARB_SEPOLIA_REBASE_TOKEN_ADDRESS=$(echo "$output" | grep 'token: contract RebaseToken' | awk '{print $4}')
# ARB_SEPOLIA_REBASE_TOKEN_ADDRESS=0x987D67aCE3ABcFf39B195A9c5885649CCa0Db933
ARB_SEPOLIA_POOL_ADDRESS=$(echo "$output" | grep 'pool: contract RebaseTokenPool' | awk '{print $4}')
# ARB_SEPOLIA_POOL_ADDRESS=0x7050A58e8B6845Ba5Da5Db8A934f391B9BFa0316

echo "Arbitrum Sepolia token address: $ARB_SEPOLIA_REBASE_TOKEN_ADDRESS"
echo "Arbitrum Sepolia pool address: $ARB_SEPOLIA_POOL_ADDRESS"

# Set the permissions for the pool contract 
echo "Setting the permissions for the pool contract on Arbitrum Sepolia..."
forge script ./script/Deployer.s.sol:SetPermissions --rpc-url ${ARB_SEPOLIA_RPC_URL} --account sepoliaAccount2 --broadcast --sig "setAdmin(address,address)" ${ARB_SEPOLIA_REBASE_TOKEN_ADDRESS} ${ARB_SEPOLIA_POOL_ADDRESS}
forge script ./script/Deployer.s.sol:SetPermissions --rpc-url ${ARB_SEPOLIA_RPC_URL} --account sepoliaAccount2 --broadcast --sig "grantRole(address,address)" ${ARB_SEPOLIA_REBASE_TOKEN_ADDRESS} ${ARB_SEPOLIA_POOL_ADDRESS}

# 2. On Sepolia!
echo "Running the script to deploy the contracts on Sepolia..."
output=$(forge script ./script/Deployer.s.sol:TokenAndPoolDeployer --rpc-url ${SEPOLIA_RPC_URL} --account sepoliaAccount2 --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY)
echo "Contracts deployed and permission set on Sepolia"

# Extract the addresses from the output
SEPOLIA_REBASE_TOKEN_ADDRESS=$(echo "$output" | grep 'token: contract RebaseToken' | awk '{print $4}')
# SEPOLIA_REBASE_TOKEN_ADDRESS=0x9bFE9eF5E16a52D95Ad0F861fbBae2247Ed34C25
SEPOLIA_POOL_ADDRESS=$(echo "$output" | grep 'pool: contract RebaseTokenPool' | awk '{print $4}')
# SEPOLIA_POOL_ADDRESS=0x82b1b47cceF8149D8337f2a6A39324113C77fF9B

echo "Sepolia token address: $SEPOLIA_REBASE_TOKEN_ADDRESS"
echo "Sepolia pool address: $SEPOLIA_POOL_ADDRESS"

# Set the permissions for the pool contract
echo "Setting the permissions for the pool contract on Sepolia..."
forge script ./script/Deployer.s.sol:SetPermissions --rpc-url ${SEPOLIA_RPC_URL} --account sepoliaAccount2 --broadcast --sig "setAdmin(address,address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS} ${SEPOLIA_POOL_ADDRESS}
forge script ./script/Deployer.s.sol:SetPermissions --rpc-url ${SEPOLIA_RPC_URL} --account sepoliaAccount2 --broadcast --sig "grantRole(address,address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS} ${SEPOLIA_POOL_ADDRESS}

# Deploy the vault 
echo "Deploying the vault on Sepolia..."
VAULT_ADDRESS=$(forge script ./script/Deployer.s.sol:VaultDeployer --rpc-url ${SEPOLIA_RPC_URL} --account sepoliaAccount2 --broadcast --sig "run(address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS} --verify --etherscan-api-key $ETHERSCAN_API_KEY | grep 'vault: contract Vault' | awk '{print $NF}')
# VAULT_ADDRESS=0x74E756E1b6440817c978477822709A5C3A065408
echo "Vault address: $VAULT_ADDRESS"

# 3. Configure the pool on Sepolia
echo "Configuring the pool on Sepolia..."
#        address originPool, 
#        address remotePool, 
#        uint64 remoteChainSelector, 
#        address remoteToken
forge script ./script/ConfigurePool.s.sol:ConfigurePool --rpc-url ${SEPOLIA_RPC_URL} --account sepoliaAccount2 --broadcast --sig "run(address,address,uint64,address)" ${SEPOLIA_POOL_ADDRESS} ${ARB_SEPOLIA_POOL_ADDRESS} ${ARB_SEPOLIA_CHAIN_SELECTOR} ${ARB_SEPOLIA_REBASE_TOKEN_ADDRESS}

# 3.1 Deposit funds to the vault
echo "Depositing funds to the vault on Sepolia..."
cast send ${VAULT_ADDRESS} --value ${AMOUNT} --rpc-url ${SEPOLIA_RPC_URL} --account sepoliaAccount2 "deposit()"

# Wait a beat for some interest to accrue

# 4. Configure the pool on Arbitrum Sepolia
echo "Configuring the pool on Arbitrum Sepolia..."
#        address originPool, 
#        address remotePool,
#        uint64 remoteChainSelector,
#        address remoteToken
forge script ./script/ConfigurePool.s.sol:ConfigurePool --rpc-url ${ARB_SEPOLIA_RPC_URL} --account sepoliaAccount2 --broadcast --sig "run(address,address,uint64,address)" ${ARB_SEPOLIA_POOL_ADDRESS} ${SEPOLIA_POOL_ADDRESS} ${SEPOLIA_CHAIN_SELECTOR} ${SEPOLIA_REBASE_TOKEN_ADDRESS}

# 5. Bridge the funds using the script to Arbitrum Sepolia
echo "Bridging the funds using the script to Arbitrum Sepolia..."
SEPOLIA_BALANCE_BEFORE=$(cast balance $(cast wallet address --account sepoliaAccount2) --erc20 ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL})
echo "Sepolia balance before bridging: $SEPOLIA_BALANCE_BEFORE"
# cast wallet address --account sepoliaAccount2 -> is sending the founds to the wallet address
forge script ./script/BridgeTokens.s.sol:BridgeTokens --rpc-url ${SEPOLIA_RPC_URL} --account sepoliaAccount2 --broadcast --sig "run(address,uint64,address,uint256,address,address)" $(cast wallet address --account sepoliaAccount2) ${ARB_SEPOLIA_CHAIN_SELECTOR} ${SEPOLIA_REBASE_TOKEN_ADDRESS} ${AMOUNT} ${SEPOLIA_LINK_ADDRESS} ${SEPOLIA_ROUTER}
echo "Funds bridged to Arbitrum Sepolia"
SEPOLIA_BALANCE_AFTER=$(cast balance $(cast wallet address --account sepoliaAccount2) --erc20 ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL})
echo "Sepolia balance after bridging: $SEPOLIA_BALANCE_AFTER"


