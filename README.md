# Puppet Contracts

Smart contracts powering Puppet on Arbitrum.

## Description

This package contains the core smart contracts that enable decentralized copy trading on GMX. The contracts handle allocation management, position mirroring, fee distribution, and secure fund management while maintaining gas efficiency through optimized design patterns.

## Key Features

- **Mirror Contract**: Automated position copying with proportional sizing
- **Account System**: Secure fund management with allocation accounts
- **Rule Engine**: Configurable copy trading parameters and risk limits
- **Fee Marketplace**: Transparent fee distribution system
- **Sequencer Router**: Dedicated router for automated execution
- **Gas Optimized**: Proxy patterns and batch processing for efficiency

## Development

This repository requires [Bun.js](https://bun.sh/) to reference Foundry libraries.

```bash
bun install
forge build
forge test
```

## License

This package is licensed under the **Business Source License 1.1** (BSL-1.1).

See [LICENSE.md](./LICENSE.md) for the full license text.

---

For more information about Puppet, visit the [main repository](https://github.com/PuppetCopy/monorepo).