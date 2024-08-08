#!/bin/bash

# Loosly based on https://github.com/rsksmart/optimism/blob/develop/packages/contracts-bedrock/scripts/deploy.sh

# Ensure CREATE2 exists
if [[ -z "${NO_DD}" || "${NO_DD}" == "false" ]] && [[ $(cast codesize 0x4e59b44847b379578588920cA78FbF26c0B4956C --rpc-url $RPC_URL) -eq 0 ]]; then
  echo "CREATE2 not deployed, deploying ..."
  cast send --from 0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826 --rpc-url "$RPC_URL" --unlocked --value 50ether 0x3fAB184622Dc19b6109349B94811493BF2a45362 --legacy
  echo "deploying CREATE2 ..."
	cast publish --rpc-url "$RPC_URL" 0xf8a58085174876e800830186a08080b853604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf31ba02222222222222222222222222222222222222222222222222222222222222222a02222222222222222222222222222222222222222222222222222222222222222
fi
echo "CREATE2 deployed"

# Deploy contracts
forge script script/Deploy.s.sol --rpc-url $RPC_URL --legacy --private-key $PRIVATE_KEY --broadcast --chain-id $CHAIN_ID
if [ $? -ne 0 ]; then
  exit $?
fi
# Reload env with contract addresses
direnv allow

# Create hardhat artifacts
if [[ ! -n "${OMIT_HARDHAT_ARTIFACTS:-}" || "${OMIT_HARDHAT_ARTIFACTS}" == "false" ]]; then
  echo "> Generating hardhat artifacts"
  forge script script/Deploy.s.sol --sig "createHardhatArtifacts()" --rpc-url $RPC_URL --legacy --private-key $PRIVATE_KEY --broadcast --chain-id $CHAIN_ID
fi
