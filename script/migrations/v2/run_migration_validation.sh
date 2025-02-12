#!/bin/bash

# Ensure the script exits on errors
set -e

# Check if required environment variables are set
if [ -z "$RPC_URL" ] || [ -z "$BLOCK_NUMBER_MIGRATION" ]; then
  echo "Error: RPC_URL or BLOCK_NUMBER_MIGRATION is not set."
  exit 1
fi

DATA_PATH="script/migrations/v2/data"
SCRIPTS_PATH="script/migrations/v2/snapshot"
# scripts
GAUGES_SNAPSHOT_SCRIPT="GaugesSnapshot.s.sol"
BUILDER_REGISTRY_SNAPSHOT_SCRIPT="BuilderRegistrySnapshot.s.sol"
BACKERS_MANAGER_SNAPSHOT_SCRIPT="BackersManagerSnapshot.s.sol"
BACKERS_ALLOCATIONS_SNAPSHOT_SCRIPT="BackersAllocationsSnapshot.s.sol"
BACKERS_REWARDS_SNAPSHOT_SCRIPT="BackersRewardsSnapshot.s.sol"

# Snapshot output json files
GAUGES_SNAPSHOT_JSON="gauges"
BUILDER_REGISTRY_SNAPSHOT_JSON="buildersRegistry"
BACKERS_MANAGER_SNAPSHOT_JSON="backersManager"
BACKERS_ALLOCATIONS_SNAPSHOT_JSON="backersAllocations"
BACKERS_REWARDS_SNAPSHOT_JSON="backersRewards"

BLOCK_NUMBER_BEFORE_MIGRATION=$((BLOCK_NUMBER_MIGRATION - 1))

function take_snapshot() {
  echo "Taking snapshot $1 before migration (v1)..."
  forge script "$SCRIPTS_PATH/$1" --fork-url "$RPC_URL" --fork-block-number "$BLOCK_NUMBER_BEFORE_MIGRATION"
  echo "Taking snapshot $1 after migration (v2)..."
  forge script "$SCRIPTS_PATH/$1" --fork-url "$RPC_URL" --fork-block-number "$BLOCK_NUMBER_MIGRATION"
}

function compare_json_files() {
  if ! diff "$DATA_PATH/$1"V1.json "$DATA_PATH/$1"V2.json; then
    echo "❌ Differences in $1 V1 and V2 JSON files found!"
  else
    echo "✅ $1 V1 and V2 JSON files match!"
  fi
}

# take snapshot of the contracts state before and after the migration
echo "Storing contracts snapshot..."
take_snapshot "$GAUGES_SNAPSHOT_SCRIPT"
take_snapshot "$BUILDER_REGISTRY_SNAPSHOT_SCRIPT"
take_snapshot "$BACKERS_MANAGER_SNAPSHOT_SCRIPT"
take_snapshot "$BACKERS_ALLOCATIONS_SNAPSHOT_SCRIPT"
take_snapshot "$BACKERS_REWARDS_SNAPSHOT_SCRIPT"

# Compare the V1 and V2 JSON files
echo "🔍 Comparing V1 and V2 JSON files..."
compare_json_files "$GAUGES_SNAPSHOT_JSON"
compare_json_files "$BUILDER_REGISTRY_SNAPSHOT_JSON"
compare_json_files "$BACKERS_MANAGER_SNAPSHOT_JSON"
compare_json_files "$BACKERS_ALLOCATIONS_SNAPSHOT_JSON"
compare_json_files "$BACKERS_REWARDS_SNAPSHOT_JSON"
