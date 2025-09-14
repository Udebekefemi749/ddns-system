# Decentralized Domain Name System (DDNS)

## Overview

A censorship-resistant internet naming system built on the Stacks blockchain using Clarity smart contracts. This system enables users to register, manage, and resolve domain names in a decentralized manner, eliminating single points of failure and censorship risks inherent in traditional DNS systems.

## Features

### Core Functionality
- **Domain Registration**: Register unique domain names with customizable expiration periods
- **Domain Resolution**: Map domain names to IP addresses, wallet addresses, or arbitrary data
- **Domain Transfer**: Transfer domain ownership between users
- **Domain Renewal**: Extend domain registration periods
- **Censorship Resistance**: No central authority can block or seize domains
- **Immutable Records**: Domain records stored permanently on the blockchain

### Security Features
- **Owner-only Updates**: Only domain owners can modify their records
- **Expiration Protection**: Automatic domain expiration handling
- **Transfer Authorization**: Secure domain transfer mechanisms
- **Anti-squatting**: First-come, first-served registration with reasonable pricing

## Architecture

### Smart Contracts

1. **Domain Registry Contract** (`domain-registry.clar`)
   - Handles domain registration and ownership
   - Manages domain expiration and renewal
   - Implements transfer mechanisms

2. **Domain Resolver Contract** (`domain-resolver.clar`)
   - Manages domain-to-address resolution
   - Handles different record types (A, AAAA, CNAME, TXT)
   - Provides query interfaces for domain resolution

### Data Structures

- **Domain Records**: Store domain name, owner, expiration, and metadata
- **Resolution Maps**: Map domains to various address types and records
- **Transfer Requests**: Manage pending domain transfers
- **Price Configuration**: Dynamic pricing based on domain length and demand

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm
- Stacks wallet for testing

### Installation

```bash
git clone <repository-url>
cd ddns-system
npm install
```

### Development

```bash
# Check contract syntax
clarinet check

# Run tests
npm test

# Deploy to testnet
clarinet deploy --testnet
```

## Usage Examples

### Register a Domain
```clarity
(contract-call? .domain-registry register-domain "example" u365)
```

### Set Domain Resolution
```clarity
(contract-call? .domain-resolver set-address-record "example" "192.168.1.1")
```

### Transfer Domain
```clarity
(contract-call? .domain-registry transfer-domain "example" 'SP1234...ABCD)
```

### Resolve Domain
```clarity
(contract-call? .domain-resolver resolve-domain "example")
```

## Benefits Over Traditional DNS

1. **Censorship Resistance**: No central authority can block or modify domains
2. **Transparency**: All operations are publicly auditable on the blockchain
3. **Global Consensus**: Domain state is maintained by the entire network
4. **Immutability**: Historical domain records cannot be altered
5. **Decentralized Governance**: Community-driven protocol evolution

## Security Considerations

- Domain owners must securely manage their private keys
- Smart contract code is immutable once deployed
- Gas fees apply to all domain operations
- Domain expiration must be monitored to prevent loss

## Technical Specifications

- **Blockchain**: Stacks
- **Smart Contract Language**: Clarity
- **Consensus**: Proof of Transfer (PoX)
- **Domain Length**: 3-63 characters
- **Supported Characters**: Alphanumeric and hyphens
- **Maximum Registration Period**: 10 years

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass with `clarinet check`
5. Submit a pull request

## License

This project is open source and available under the MIT License.

## Support

For questions, issues, or contributions, please open an issue on GitHub or contact the development team.

---

*Built with ❤️ for a decentralized web*
