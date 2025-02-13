#!/bin/bash

contract_addresses="deployments/$DEPLOYMENT_CONTEXT/contract_addresses.json"

jq -r 'to_entries | .[] | "\(.key) \(.value)"' "$contract_addresses" | while read -r key value; do
  contractName=$key
  if [[ "$contractName" == *"Proxy"* ]]; then
    echo "Skipping $contractName proxy contract..."
    continue
  fi
  echo "Verifying $contractName..."

  contractAddress=$value
  echo "Verifying $contractName at $contractAddress..."
  echo "$contractName.sol"
  contractPath=$(find src -type f -name "$contractName.sol" 2>/dev/null)
  echo "Contract path: $contractPath"

  echo "Verifying $contractName at $contractAddress using path $contractPath..."
  forge verify-contract \
    --rpc-url $RPC_URL \
    --verifier blockscout \
    --verifier-url 'https://rootstock-testnet.blockscout.com/api/' \
    "$contractAddress" \
    "$contractPath:$contractName"
done
