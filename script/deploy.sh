#!/bin/bash

# Loosly based on https://github.com/rsksmart/optimism/blob/develop/packages/contracts-bedrock/scripts/deploy.sh

# Ensure CREATE2 exists
if [[ -z "${NO_DD}" || "${NO_DD}" == "false" ]] && [[ $(cast codesize 0x4e59b44847b379578588920cA78FbF26c0B4956C --rpc-url $RPC_URL || exit $?) -eq 0 ]]; then
  echo "CREATE2 not deployed, deploying ..."
  cast send --from 0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826 --rpc-url "$RPC_URL" --unlocked --value 50ether 0x3fAB184622Dc19b6109349B94811493BF2a45362 --legacy || exit $?
  echo "deploying CREATE2 ..."
	cast publish --rpc-url "$RPC_URL" 0xf8a58085174876e800830186a08080b853604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf31ba02222222222222222222222222222222222222222222222222222222222222222a02222222222222222222222222222222222222222222222222222222222222222 || exit $?
fi
echo "CREATE2 deployed"

# Define common arguments for forge commands
FORGE_ARGS="--rpc-url $RPC_URL --legacy --private-key $PRIVATE_KEY --chain-id $CHAIN_ID --with-gas-price $GAS_PRICE --extra-output-files abi"

# Add --broadcast only if NO_BROADCAST is not set to "true"
if [[ "${NO_BROADCAST:-false}" != "true" ]]; then
  FORGE_ARGS+=" --broadcast"
fi

# Deploy contracts
forge script script/Deploy.s.sol $FORGE_ARGS  || exit $?
# Reload env with contract addresses
direnv allow

# Copy ABI outputs to deployment directory
if [[ ! -n "${OMIT_ABI_COPY:-}" || "${OMIT_ABI_COPY}" == "false" ]]; then
  echo "> Copying ABIs to deployment directory"
  forge script script/Deploy.s.sol --sig "copyAbis()" $FORGE_ARGS || exit $?
fi
