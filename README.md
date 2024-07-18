# Builder Incentives Smart Contracts [![Github Actions][gha-badge]][gha] [![Foundry][foundry-badge]][foundry] [![License: MIT][license-badge]][license]

[gha]: https://github.com/rsksmart/builder-incentives-sc/actions
[gha-badge]: https://github.com/rsksmart/builder-incentives-sc/actions/workflows/ci.yml/badge.svg
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

## Pre-requirements

The following tools are required to be installed:

- [bun](https://bun.sh/docs/installation)
- [foundry](https://book.getfoundry.sh/getting-started/installation)

> [!IMPORTANT]  
> Please make sure to install foundry using the branch `f625d0fa7c51e65b4bf1e8f7931cd1c6e2e285e9`. By using the latest
> version we experienced the following error on RSKj:
> `... deserialization error: missing field ``effectiveGasPrice`` ...`

```sh
foundryup --branch f625d0fa7c51e65b4bf1e8f7931cd1c6e2e285e9
```

## Getting Started

Clone the repo and install the dependencies

```sh
git clone https://github.com/rsksmart/builder-incentives-sc.git
bun install # install Solhint, Prettier, Hardhat and other Node.js deps
```

If this is your first time with Foundry, check out the
[installation](https://github.com/foundry-rs/foundry#installation) instructions.

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

When deploying the contracts to RSKj locally, one of the unlocked accounts can be used:

```sh
forge script script/Deploy.s.sol --rpc-url http://localhost:4444 --legacy --broadcast --sender 0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826 --unlocked
```

It's also possible to use any private key (as far as the associated account has balance to execute transactions):

```sh
forge script script/Deploy.s.sol --rpc-url http://localhost:4444 --legacy --broadcast --private-key "0xYOUR_PRIVATE_KEY"
```

Deploy to Anvil:

```sh
forge script script/Deploy.s.sol --broadcast --fork-url http://localhost:8545
```

For this script to work, you need to have a `MNEMONIC` environment variable set to a valid
[BIP39 mnemonic](https://iancoleman.io/bip39/).

For instructions on how to deploy to a testnet or mainnet, check out the
[Solidity Scripting](https://book.getfoundry.sh/tutorials/solidity-scripting.html) tutorial.

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

## Acknowledgment

The project is built using the [PaulRBerg foundry-template](https://github.com/PaulRBerg/foundry-template).

## License

This project is licensed under MIT.
