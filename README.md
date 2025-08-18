# FarmerCo-op: Decentralized Farmer Cooperatives

A smart contract platform for farmers to create and manage cooperatives without central authority. Automates profit distribution, resource sharing, and democratic decision-making through blockchain technology.

## Features

- **Cooperative Creation**: Farmers can establish new cooperatives with unique identities
- **Member Management**: Join cooperatives by contributing initial resources 
- **Resource Pooling**: Contribute funds, equipment, and land to shared cooperative resources
- **Democratic Governance**: Create and vote on proposals using share-weighted voting
- **Profit Distribution**: Automated profit sharing based on member contributions and shares
- **Transparent Operations**: All activities recorded immutably on blockchain

## Core Functions

### Cooperative Management
- `create-cooperative(name)` - Establish a new farmer cooperative
- `join-cooperative(coop-id, initial-contribution)` - Become a member with STX contribution
- `contribute-resources(coop-id, amount, resource-type)` - Add funds, equipment, or land

### Governance
- `create-proposal(coop-id, title, description, amount, proposal-type)` - Submit proposals for voting
- `vote-on-proposal(proposal-id, vote)` - Vote yes/no with voting power based on shares
- `execute-proposal(proposal-id)` - Execute approved proposals after voting period

### Profit Distribution
- `distribute-profits(coop-id, total-profit)` - Founder deposits cooperative profits
- `claim-profit-share(coop-id)` - Members claim their proportional profit share

### Read-Only Functions
- `get-cooperative(coop-id)` - View cooperative details
- `get-member-info(coop-id, member)` - Check member status and shares
- `get-coop-resources(coop-id)` - View available resources
- `get-proposal(proposal-id)` - Check proposal details and voting results

## Usage Flow

1. **Create Cooperative**: Founder calls `create-cooperative` with cooperative name
2. **Add Members**: Farmers join using `join-cooperative` with STX contribution
3. **Pool Resources**: Members contribute additional resources via `contribute-resources`
4. **Make Decisions**: Create proposals and vote democratically on cooperative matters
5. **Share Profits**: Distribute and claim profits based on member share percentages

## Technical Details

- Built on Stacks blockchain using Clarity smart contract language
- Share-based voting system where contributions increase voting power
- 144-block voting periods (approximately 24 hours)
- Automatic profit distribution based on member share ratios
- Resource tracking for funds, equipment value, and land size

## Testing

Deploy and test using Clarinet:

```bash
clarinet check
clarinet test
clarinet deploy
```

## Contract Security

- Member verification for all critical operations
- Voting period enforcement prevents late votes
- Duplicate vote prevention
- Fund sufficiency checks before transfers
- Access control for sensitive functions
