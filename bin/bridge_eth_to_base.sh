#!/bin/bash

# Define constants 
AMOUNT=100000

BASE_SEPOLIA_REGISTRY_MODULE_OWNER_CUSTOM="0x176ae8C6C11DD2c031B924CE1A0A43188035f3f6"
BASE_SEPOLIA_TOKEN_ADMIN_REGISTRY="0x736D0bBb318c1B27Ff686cd19804094E66250e17"
BASE_SEPOLIA_ROUTER="0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93"
BASE_SEPOLIA_RNM_PROXY_ADDRESS="0x99360767a4705f68CcCb9533195B761648d6d807"
BASE_SEPOLIA_CHAIN_SELECTOR="10344971235874465080"
BASE_SEPOLIA_LINK_ADDRESS="0xE4aB69C077896252FAFBD49EFD26B5D171A32410"

SEPOLIA_REGISTRY_MODULE_OWNER_CUSTOM="0xa3c796d480638d7476792230da1E2ADa86e031b0"
SEPOLIA_TOKEN_ADMIN_REGISTRY="0x95F29FEE11c5C55d26cCcf1DB6772DE953B37B82"
SEPOLIA_ROUTER="0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59"
SEPOLIA_RNM_PROXY_ADDRESS="0xba3f6251de62dED61Ff98590cB2fDf6871FbB991"
SEPOLIA_CHAIN_SELECTOR="16015286601757825753"
SEPOLIA_LINK_ADDRESS="0x779877A7B0D9E8603169DdbD7836e478b4624789"

# 1. On Base Sepolia

echo "Running the script to deploy the contracts on Base Sepolia..."
output=$(forge script ./script/Deployer.s.sol:TokenAndPoolDeployer --rpc-url ${BASE_SEPOLIA_RPC_URL} --account ${ACCOUNT} --broadcast)
echo "Contracts deployed and permission set on Base Sepolia"

# Extract the addresses from the output
BASE_SEPOLIA_REBASE_TOKEN_ADDRESS=$(echo "$output" | grep 'token: contract RebaseToken' | awk '{print $4}')
BASE_SEPOLIA_POOL_ADDRESS=$(echo "$output" | grep 'pool: contract RebaseTokenPool' | awk '{print $4}')

echo "Base Sepolia rebase token address: $BASE_SEPOLIA_REBASE_TOKEN_ADDRESS"
echo "Base Sepolia pool address: $BASE_SEPOLIA_POOL_ADDRESS"


# 2. On Sepolia!

echo "Running the script to deploy the contracts on Sepolia..."
output=$(forge script ./script/Deployer.s.sol:TokenAndPoolDeployer --rpc-url ${SEPOLIA_RPC_URL} --account ${ACCOUNT} --broadcast)
echo "Contracts deployed and permission set on Sepolia"

# Extract the addresses from the output
SEPOLIA_REBASE_TOKEN_ADDRESS=$(echo "$output" | grep 'token: contract RebaseToken' | awk '{print $4}')
SEPOLIA_POOL_ADDRESS=$(echo "$output" | grep 'pool: contract RebaseTokenPool' | awk '{print $4}')

echo "Sepolia rebase token address: $SEPOLIA_REBASE_TOKEN_ADDRESS"
echo "Sepolia pool address: $SEPOLIA_POOL_ADDRESS"

# Deploy the vault 
echo "Deploying the vault on Sepolia..."
VAULT_ADDRESS=$(forge script ./script/Deployer.s.sol:VaultDeployer --rpc-url ${SEPOLIA_RPC_URL} --account ${ACCOUNT} --broadcast --sig "run(address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS} | grep 'vault: contract Vault' | awk '{print $NF}')
echo "Vault address: $VAULT_ADDRESS"

# Configure the pool on Sepolia
echo "Configuring the pool on Sepolia..."
#        address localPool,
#        uint64 remoteChainSelector,
#        address remotePool,
#        address remoteToken,
#        bool outboundRateLimiterIsEnabled,
#        uint128 outboundRateLimiterRate,
#        uint128 outboundRateLimiterCapacity,
#        bool inboundRateLimiterIsEnabled,
#        uint128 inboundRateLimiterRate,
#        uint128 inboundRateLimiterCapacity
forge script ./script/ConfigurePool.s.sol:ConfigurePool --rpc-url ${SEPOLIA_RPC_URL} --account ${ACCOUNT} --broadcast --sig "run(address,uint64,address,address,bool,uint128,uint128,bool,uint128,uint128)" ${SEPOLIA_POOL_ADDRESS} ${BASE_SEPOLIA_CHAIN_SELECTOR} ${BASE_SEPOLIA_POOL_ADDRESS} ${BASE_SEPOLIA_REBASE_TOKEN_ADDRESS} false 0 0 false 0 0

# Deposit funds to the vault
echo "Depositing funds to the vault on Sepolia..."
cast send ${VAULT_ADDRESS} --value ${AMOUNT} --rpc-url ${SEPOLIA_RPC_URL} --account ${ACCOUNT} "deposit()"

# Wait a bit for some interest to accrue
sleep 5

# Configure the pool on Base
echo "Configuring the pool on base Sepolia..."
#        address localPool,
#        uint64 remoteChainSelector,
#        address remotePool,
#        address remoteToken,
#        bool outboundRateLimiterIsEnabled,
#        uint128 outboundRateLimiterRate,
#        uint128 outboundRateLimiterCapacity,
#        bool inboundRateLimiterIsEnabled,
#        uint128 inboundRateLimiterRate,
#        uint128 inboundRateLimiterCapacity
forge script ./script/ConfigurePool.s.sol:ConfigurePool --rpc-url ${BASE_SEPOLIA_RPC_URL} --account ${ACCOUNT} --broadcast --sig "run(address,uint64,address,address,bool,uint128,uint128,bool,uint128,uint128)" ${BASE_SEPOLIA_POOL_ADDRESS} ${SEPOLIA_CHAIN_SELECTOR} ${SEPOLIA_POOL_ADDRESS} ${SEPOLIA_REBASE_TOKEN_ADDRESS} false 0 0 false 0 0

# Bridge the funds using the script to zksync 
echo "Bridging the funds using the script to Base..."
SEPOLIA_BALANCE_BEFORE=$(cast balance $(cast wallet address --account ${ACCOUNT}) --erc20 ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL})
echo "Sepolia balance before bridging: $SEPOLIA_BALANCE_BEFORE"
forge script ./script/BridgeTokens.s.sol:BridgeTokenScript --rpc-url ${SEPOLIA_RPC_URL} --account ${ACCOUNT} --broadcast --sig "run(address,uint64,address,uint256,address,address)" $(cast wallet address --account ${ACCOUNT}) ${BASE_SEPOLIA_CHAIN_SELECTOR} ${SEPOLIA_REBASE_TOKEN_ADDRESS} ${AMOUNT} ${SEPOLIA_LINK_ADDRESS} ${SEPOLIA_ROUTER}
echo "Funds bridged to Base"
SEPOLIA_BALANCE_AFTER=$(cast balance $(cast wallet address --account ${ACCOUNT}) --erc20 ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL})
echo "Sepolia balance after bridging: $SEPOLIA_BALANCE_AFTER"


