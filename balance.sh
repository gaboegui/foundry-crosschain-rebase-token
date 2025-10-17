#!/bin/bash
source .env
# We can provide the password of the sepoliaAccount2 to avoid enTering every time that is need
PASSWORD=$(head -n 1 .env)  

# Sepolia!
SEPOLIA_REBASE_TOKEN_ADDRESS=0x2ddeFc338823E53693CCce0E3EC9214Cc389A9F0

echo "Sepolia token address: $SEPOLIA_REBASE_TOKEN_ADDRESS"

echo "Geting Balance from Sepolia..."
BALANCE=$(cast balance $(cast wallet address --account sepoliaAccount2 --password $PASSWORD) --erc20 ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL})
echo "Sepolia balance: $BALANCE"

