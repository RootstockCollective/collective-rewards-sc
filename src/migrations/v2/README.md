# Fork Tests: migration v1 -> v2

V1 BackersManager contract hit the maximum contract size, and a split between `BackerManager` and `BuilderRegistry` was necessary to
allow adding new features. Fork tests are run against a snapshot of the RSK Testnet/Mainnet at a specific block. These
tests ensure that v2 contract deployments behave as expected once deployed on the RSK blockchain and interact correctly
with existing live components.

Flows covered:

- `BackerManager` Upgrade is successful
- `BuilderRegistry` Deploy & migration is successful
- `Gauges` Upgrade is successful

**IMPORTANT**: If the tests require interactions with newly deployed components on the live network after the fork was
created, a new fork must be created to include those components. This is because the fork rpc url points to a specific mainnet block number.

## Running Fork Tests

Environment:

- Mainnet: `.env.30.fork`

To run the tests:

1. Select the previous environment file and apply it:

   ```sh
   direnv allow
   ```

2. Execute the test command:

   ```sh
   bun run test:fork
   ```

## Fork Environment Variables

- **`RPC_URL_FORK`**: The fork RPC URL for the RSK network. Create a virtual TestNet on Tenderly for the desired network
  and copy the generated RPC URL. The fork will point to the latest block at the time it was created.
- **`BACKERS_MANAGER_ADDRESS`**: Address of the currently live backers manager.

## License

This project is licensed under MIT.
