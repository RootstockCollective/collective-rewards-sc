#!/bin/bash
set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ── Usage ────────────────────────────────────────────────────────────────
usage() {
    echo -e "Usage: $0 <explorer>"
    echo -e ""
    echo -e "  explorer   Which block explorer to verify against."
    echo -e "             Allowed values: ${GREEN}blockscout${NC} | ${GREEN}rootstock${NC}"
    echo -e ""
    echo -e "Examples:"
    echo -e "  $0 blockscout"
    echo -e "  $0 rootstock"
    exit 1
}

# ── Parse explorer argument ──────────────────────────────────────────────
EXPLORER="${1}"
if [ -z "$EXPLORER" ]; then
    echo -e "${RED}Error: explorer argument is required${NC}\n"
    usage
fi

if [[ "$EXPLORER" != "blockscout" && "$EXPLORER" != "rootstock" ]]; then
    echo -e "${RED}Error: unknown explorer '$EXPLORER'${NC}\n"
    usage
fi

# Load environment variables
if [ -f .env ]; then
    echo -e "${GREEN}Loading environment variables from .env...${NC}"
    set -a
    source .env
    set +a
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Check DEPLOYMENT_CONTEXT is set
if [ -z "$DEPLOYMENT_CONTEXT" ]; then
    echo -e "${RED}Error: DEPLOYMENT_CONTEXT not set${NC}"
    exit 1
fi

# Check if RPC_URL is set for blockscout
if [ "$EXPLORER" = "blockscout" ] && [ -z "$RPC_URL" ]; then
    echo -e "${RED}Error: RPC_URL not set${NC}"
    exit 1
fi

# Normalize context to mainnet vs testnet for VERIFIER_URL and EXPLORER_URL
if [ "$DEPLOYMENT_CONTEXT" = "mainnet" ]; then
    CHAIN_ENV="mainnet"
else
    CHAIN_ENV="testnet"
fi

# blockscout
VERIFIER_URL_blockscout_mainnet="https://rootstock.blockscout.com/api/"
VERIFIER_URL_blockscout_testnet="https://rootstock-testnet.blockscout.com/api/"
EXPLORER_URL_blockscout_mainnet="https://rootstock.blockscout.com"
EXPLORER_URL_blockscout_testnet="https://rootstock-testnet.blockscout.com"
FORGE_ARGS_blockscout='--verifier blockscout --verifier-url "$VERIFIER_URL" --rpc-url "$RPC_URL"'

# rootstock
VERIFIER_URL_rootstock_mainnet="https://be.explorer.rootstock.io/api/v3/etherscan"
VERIFIER_URL_rootstock_testnet="https://be.explorer.testnet.rootstock.io/api/v3/etherscan"
EXPLORER_URL_rootstock_mainnet="https://explorer.rootstock.io"
EXPLORER_URL_rootstock_testnet="https://explorer.testnet.rootstock.io"
FORGE_ARGS_rootstock='--verifier custom --verifier-url "$VERIFIER_URL" --chain-id "$CHAIN_ID"'

# Lookup by EXPLORER and CHAIN_ENV
key_ctx="${EXPLORER}_${CHAIN_ENV}"
key="VERIFIER_URL_${key_ctx}"; VERIFIER_URL="${!key}"
key="EXPLORER_URL_${key_ctx}"; EXPLORER_URL="${!key}"

# obs: CHAIN_ID comes from .chain_id file

if [ -z "$VERIFIER_URL" ] || [ -z "$EXPLORER_URL" ] || [ -z "$CHAIN_ID" ]; then
    echo -e "${RED}Error: No verifier config for explorer=$EXPLORER; context=$DEPLOYMENT_CONTEXT; chain_id=$CHAIN_ID${NC}"
    exit 1
fi

# Build forge verifier args from config
key="FORGE_ARGS_${EXPLORER}"
eval 'FORGE_VERIFIER_ARGS=('"${!key}"')'

# ── Check deployment file ────────────────────────────────────────────────
contract_addresses="deployments/$DEPLOYMENT_CONTEXT/contract_addresses.json"

# ── Check if deployment file exists ──────────────────────────────────────
if [ ! -f "$contract_addresses" ]; then
    echo -e "${RED}Error: Deployment file not found at $contract_addresses${NC}"
    exit 1
fi

echo -e "${GREEN}Verifying contracts from $contract_addresses (explorer: $EXPLORER)...${NC}"
echo -e "Chain ID: $CHAIN_ID"
echo -e "Deployment context: $DEPLOYMENT_CONTEXT\n"

# ── Find contract source path ────────────────────────────────────────────
find_contract_path() {
    local contract_name=$1
    find src -type f -name "$contract_name.sol" 2>/dev/null | head -n 1
}

# ── Verify each contract ─────────────────────────────────────────────────
jq -r 'to_entries | .[] | "\(.key) \(.value)"' "$contract_addresses" | while read -r key value; do
    contractName=$key

    # Skip proxy contracts (we only verify implementations)
    if [[ "$contractName" == *"Proxy"* ]]; then
        continue
    fi

    contractAddress=$value
    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Verifying: $contractName${NC}"
    echo -e "${GREEN}Address: $contractAddress${NC}"

    # Find contract path (exact key first, then fallback: ContractName_Variant -> ContractName)
    contractPath=$(find_contract_path "$contractName")
    verifyContractName="$contractName"

    # e.g. GaugeRootstockCollectiveImplementation -> GaugeRootstockCollective
    if [ -z "$contractPath" ] && [[ "$contractName" == *"Implementation" ]]; then
        baseName="${contractName%Implementation}"
        contractPath=$(find_contract_path "$baseName")
        if [ -n "$contractPath" ]; then
            verifyContractName="$baseName"
        fi
    fi

    # e.g. SomeContract_Variant -> SomeContract
    if [ -z "$contractPath" ] && [[ "$contractName" == *"_"* ]]; then
        baseName="${contractName%_*}"
        contractPath=$(find_contract_path "$baseName")
        if [ -n "$contractPath" ]; then
            verifyContractName="$baseName"
        fi
    fi

    if [ -z "$contractPath" ]; then
        echo -e "${RED}Error: Could not find source file for $contractName${NC}"
        continue
    fi

    echo -e "Path: $contractPath (verify as: $verifyContractName)"

    # Verify contract
    echo "Running verification..."
    # echo "forge verify-contract ${FORGE_VERIFIER_ARGS[*]} $contractAddress $contractPath:$verifyContractName --watch"
    if forge verify-contract \
        "${FORGE_VERIFIER_ARGS[@]}" \
        "$contractAddress" \
        "$contractPath:$verifyContractName" \
        --watch; then
        echo -e "${GREEN}✓ Verified $contractName at $EXPLORER_URL/address/$contractAddress${NC}"
    else
        echo -e "${RED}✗ Failed to verify $contractName${NC}"
    fi
done

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Verification complete!${NC}"
