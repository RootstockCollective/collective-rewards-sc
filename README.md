# Rewards Smart Contracts for RootstockCollective [![Github Actions][gha-badge]][gha] [![Foundry][foundry-badge]][foundry] [![License: MIT][license-badge]][license]

[gha]: https://github.com/RootstockCollective/collective-rewards-sc/actions
[gha-badge]: https://github.com/RootstockCollective/collective-rewards-sc/actions/workflows/ci.yml/badge.svg
[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg
[license]: https://opensource.org/licenses/MIT
[license-badge]: https://img.shields.io/badge/License-MIT-blue.svg

A set of Solidity smart contracts, to implement builder incentives and staker rewards mechanisms to be integrated with
the DAO.

## What's Inside

- [Forge](https://github.com/foundry-rs/foundry/blob/master/forge): compile, test, fuzz, format, and deploy smart
  contracts
- [Forge Std](https://github.com/foundry-rs/forge-std): collection of helpful contracts and utilities for testing
- [Prettier](https://github.com/prettier/prettier): code formatter for non-Solidity files
- [Solhint](https://github.com/protofire/solhint): linter for Solidity code
- [Hardhat](https://github.com/NomicFoundation/hardhat): integration testing, interact with RSKj

## Prerequisites

The following tools are required to be installed:

- [bun](https://bun.sh/docs/installation) - For macOS, Linux, and WSL run: `curl -fsSL https://bun.sh/install | bash`
- [foundry](https://book.getfoundry.sh/getting-started/installation) - Simply run:
  `curl -L https://foundry.paradigm.xyz | bash`
- [direnv](https://direnv.net/docs/installation.html) - Although a large variety of OSs comes with `direnv`
  [packaged](https://direnv.net/docs/installation.html#from-system-packages), the easiest way to install it is by
  running: `curl -sfL https://direnv.net/install.sh | bash`
- [jq](https://jqlang.github.io/jq/download/) - Again, this is packaged to a variety of OSs, but if you don't have it
  follow the link to install it for your system

> [!IMPORTANT]
> Please make sure to install foundry using the branch `f625d0fa7c51e65b4bf1e8f7931cd1c6e2e285e9`. By using
> the latest version we experienced the following error on RSKj:
> `... deserialization error: missing field ``effectiveGasPrice`` ...`

That foundry branch works with cargo >=1.76.0 or <= 1.79.0. So first, switch the version

```sh
rustup default 1.79.0
```

```sh
foundryup --branch f625d0fa7c51e65b4bf1e8f7931cd1c6e2e285e9
```

If this is your first time with Foundry, check out the
[installation](https://github.com/foundry-rs/foundry#installation) instructions.

## Getting Started

Clone the repo and install the dependencies

```sh
git clone https://github.com/RootstockCollective/collective-rewards-sc.git
cd collective-rewards-sc
bun install # install Solhint, Prettier, Hardhat and other Node.js deps
```

> [!WARNING]
> `.env.<chain_id>` could be public, don't put your private key or mnemonic there. Use `.env` for that.

```sh
cp .env.private.example .env
```

and change the values to

```sh
# .env
# Required
export PRIVATE_KEY="{your-private-key}"
```

When you change to the project directory (`cd collective-rewards-sc`), the shell will ask you to run

```sh
direnv allow
```

upon which you'll be asked to present the chain id of the network you wish to use. This will be written in a file called
`.chain_id`. Alternatively, you can create this file yourself (content of which is only the chain id number itself)
before calling `direnv allow`. This could be particularly useful when wishing to load configs for and to deploy to
multiple networks.

```sh
echo "31" > .chain_id && direnv allow
```

Or non-persistently (deleted upon reboot) with:

```sh
echo "31" > $(mktemp .chain_id) && direnv allow
```

This will subsequently create environment variables (will unload after exiting the directory; for more info see
[direnv docs](https://direnv.net)) specified for given network inside the `.env.<chain_id>` file. If such file does not
exist you will be asked to create one for your network. This can be done by copying/moving the `.env.example` file and
changing the example vars to match your desired network. For example:

```sh
mv .env.example .env.42
```

and change the values to

```sh
# .env.42
# mynet specific configuration
# Required
export DEPLOYMENT_CONTEXT="regtest"
export RPC_URL="https://dolphinnet.node"
export REWARD_TOKEN_ADDRESS="0x14f6504A7ca4e574868cf8b49e85187d3Da9FA70"
export STAKING_TOKEN_ADDRESS="0x14f6504A7ca4e574868cf8b49e85187d3Da9FA71"
export GOVERNOR_ADDRESS="0x14f6504A7ca4e574868cf8b49e85187d3Da9FA72"
export CHANGE_EXECUTOR_ADDRESS="0x14f6504A7ca4e574868cf8b49e85187d3Da9FA73"
export FOUNDATION_TREASURY_ADDRESS="0x14f6504A7ca4e574868cf8b49e85187d3Da9FA74"

# Optional
export DEPLOYER_ADDRESS="0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"

# Custom
export RPC_KEY="someRandomJWTToken" # if any
```

Then re-run `direnv allow` to load the new env vars.

If for development purposes you'd like to avoid using the deterministic deployer (CREATE2), so that your node doesn't
need to be restarted every time you want to redeploy, you can use `NO_DD=true` environment variable to deploy using
simple CREATE opcode (default if false, meaning it will use CREATE2).

## Features

This project builds upon the frameworks and libraries mentioned above, so please consult their respective documentation
for details about their specific features.

For example, if you're interested in exploring Foundry in more detail, you should look at the
[Foundry Book](https://book.getfoundry.sh/). In particular, you may be interested in reading the
[Writing Tests](https://book.getfoundry.sh/forge/writing-tests.html) tutorial.

Foundry was integrated with Hardhat following the [Integrating with Hardhat](https://book.getfoundry.sh/config/hardhat)
guide.

### Sensible Defaults

This template comes with a set of sensible default configurations for you to use. These defaults can be found in the
following files:

```text
├── .commitlintrc.ts
├── .editorconfig
├── .gitignore
├── .prettierignore
├── .prettierrc.yml
├── .solhint.json
├── foundry.toml
├── hardhat.config.ts
└── remappings.txt
```

### VSCode Integration

The project is IDE agnostic, but for the best user experience, you may want to use it in VSCode alongside Nomic
Foundation's [Solidity extension](https://marketplace.visualstudio.com/items?itemName=NomicFoundation.hardhat-solidity).

For guidance on how to integrate a Foundry project in VSCode, please refer to this
[guide](https://book.getfoundry.sh/config/vscode).

### GitHub Actions

Your contracts will be linted and tested on every push and pull request made to the `main` branch.

## Installing Dependencies

While foundry generally uses submodules to manage dependencies, this project uses Node.js packages because
[submodules don't scale](https://twitter.com/PaulRBerg/status/1736695487057531328).

This is how to install dependencies:

1. Install the dependency using your preferred package manager, e.g. `bun install dependency-name`
   - Use this syntax to install from GitHub: `bun install github:username/repo-name`
2. Add a remapping for the dependency in [remappings.txt](./remappings.txt), e.g.
   `dependency-name=node_modules/dependency-name`

Note that OpenZeppelin Contracts is pre-installed, so you can follow that as an example.

## Writing Tests

### Foundry

To write a new test contract, you can follow the [Foundry tests](https://book.getfoundry.sh/forge/tests) guide.

### Hardhat

To write a new integration test, you can follow the
[Hardhat testing contracts](https://hardhat.org/hardhat-runner/docs/guides/test-contracts) guide.

## Usage

This is a list of the most frequently needed commands.

### Build

Build and compile the contracts:

```sh
bun run compile
```

### Clean

Delete the build artifacts, typechain types and cache directories:

```sh
bun run clean
```

### Deploy

The simples way to deploy is to use the command

```sh
bun run deploy
```

This will also generate hardhat-style artifacts unless `OMIT_HARDHAT_ARTIFACTS` is set to `true`:

```sh
OMIT_HARDHAT_ARTIFACTS=true bun run deploy
```

When deploying the contracts to RSKj locally, one of the unlocked accounts can be used:

```sh
forge script script/Deploy.s.sol --rpc-url "$RPC_URL" --legacy --broadcast --sender $ACCOUNT --unlocked --chain-id "$CHAIN_ID"
```

It's also possible to use any private key (as far as the associated account has balance to execute transactions):

```sh
forge script script/Deploy.s.sol --rpc-url "$RPC_URL" --legacy --broadcast --private-key "$PRIVATE_KEY" --chain-id "$CHAIN_ID"
```

Deploy to Anvil:

```sh
forge script script/Deploy.s.sol --broadcast --fork-url http://localhost:8545
```

For this script to work, you need to have a `MNEMONIC` environment variable set to a valid
[BIP39 mnemonic](https://iancoleman.io/bip39/).

For instructions on how to deploy to a testnet or mainnet, check out the
[Solidity Scripting](https://book.getfoundry.sh/tutorials/solidity-scripting.html) tutorial.

In order to use the Deploy script as is, you will need to configure the addresses of:

1. Reward token - see [glossary](#reward-token) - use environment variable `REWARD_TOKEN_ADDRESS`
2. Staking token - see [glossary](#staking-token) - use environment variable `STAKING_TOKEN_ADDRESS`
3. Governor - see [glossary](#governor) - use environment variable `GOVERNOR_ADDRESS`
4. KYC Approver - see [glossary](#kyc-approver) - use environment variable `KYC_APPROVER_ADDRESS`
5. Foundation treasury - see [glossary](#foundation-treasury) - use environment variable `FOUNDATION_TREASURY_ADDRESS`

For development and testing purposes you may like to deploy some of the mock contracts:

#### mock token

```sh
forge script script/MockToken.s.sol #the rest of the command arguments
```

should you like to number the the token in the name (for multiple tokens) use either an env var:

```sh
MOCK_TOKEN_COUNTER=42 forge script script/MockToken.s.sol #the rest of the command arguments
```

or a function signature that accepts this parameter:

```sh
forge script script/MockToken.s.sol -s "run(uint)" 42 #the rest of the command arguments
```

#### mock change executor

```sh
forge script script/test_mock/ChangeExecutorMock.s.sol #the rest of the command arguments
```

to pass a governor to the deployemnt you can either use env var:

```sh
GOVERNOR_ADDRESS="0xYOUR_GOV" forge script script/test_mock/ChangeExecutorMock.s.sol #the rest of the command arguments
```

or pass it directly, specifying the function signature that accepts it:

```sh
forge script script/test_mock/ChangeExecutorMock.s.sol -s "run(address)" "0xYOUR_GOV" #the rest of the command arguments
```

The script should create a new directory (if it doesn't exist already) `./deployments/$DEPLOYMENT_CONTEXT` and output
all deployed contract addresses into a file called `contract_addresses.json`. Run `direnv allow` or re-open the project
directory to load these automatically into environment variables.

### Format

Format the contracts:

```sh
bun run prettier:check
```

### Lint

Lint the contracts:

```sh
bun run lint
```

### Test

#### Foundry test

Run the foundry tests:

```sh
bun run test
```

#### Hardhat test

Run the hardhat tests:

```sh
bun run test:integration
```

You can test against RSKj locally:

```sh
bun run test:integration --network regtest
```

#### Test coverage

Generate test coverage and output result to the terminal:

```sh
bun run test:coverage
```

Generate coverage report:

1. Install lcov

   ```sh
   apt-get install lcov
   ```

1. Generate report

   ```sh
   bun run test:coverage:report
   ```

1. Open `coverage/index.html`

## Glossary

### Reward token

The reward token for the collective incentives program is `RIF`.

### Staking token

The staking token is `stRIF`, where the token balance represents the backing power a backer has to vote for builders.

### Governor

The Governor represents the DAO’s governance mechanism and is in charge of the community approval and de-whitelisting of
builders.

### KYC Approver

The RoostockCollective Foundation requires builders to got through a KYC process and is in charge of submitting said
approval as well as revoking it if necessary.

### Foundation treasury

The RoostockCollective Foundation is in charge of holding and distributing the rewards from the program.

## Acknowledgment

The project is built using the [PaulRBerg foundry-template](https://github.com/PaulRBerg/foundry-template).

## License

This project is licensed under MIT.
