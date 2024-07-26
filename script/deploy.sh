#!/bin/bash

forge script script/Deploy.s.sol --rpc-url $RPC_URL --legacy --private-key $PRIVATE_KEY --broadcast --chain-id $CHAIN_ID
if [[ ! -n "${OMIT_HARDHAT_ARTIFACTS:-}" || "${OMIT_HARDHAT_ARTIFACTS}" == "false" ]]; then
  echo "> Generating hardhat artifacts"
  forge script script/Deploy.s.sol --sig "createHardhatArtifacts()" --rpc-url $RPC_URL --legacy --private-key $PRIVATE_KEY --broadcast --chain-id $CHAIN_ID
fi
