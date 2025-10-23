# 🌾 FarmerCo-op: Decentralized Farmer Cooperatives

A comprehensive smart contract platform empowering farmers to create and manage cooperatives without central authority. Features automated profit distribution, resource sharing, democratic decision-making, and innovative crop insurance pooling through blockchain technology.

## ✨ Core Features

### 🤝 Cooperative Management
- **Cooperative Creation**: Farmers can establish new cooperatives with unique identities
- **Member Management**: Join cooperatives by contributing initial resources 
- **Resource Pooling**: Contribute funds, equipment, and land to shared cooperative resources
- **Democratic Governance**: Create and vote on proposals using share-weighted voting
- **Profit Distribution**: Automated profit sharing based on member contributions and shares
- **Transparent Operations**: All activities recorded immutably on blockchain

### 🛡️ Crop Insurance Pool (NEW!)
- **Collective Insurance**: Members pool funds to create shared crop insurance coverage
- **Flexible Coverage**: Register crops with customizable coverage amounts and durations
- **Democratic Claims**: Community-voted claim approval system with transparent evidence tracking
- **Automatic Payouts**: Smart contract executes approved insurance payouts instantly
- **Premium System**: Fair 5% premium rate based on coverage amount
- **Risk Mitigation**: Protect against natural disasters, drought, floods, and other covered losses

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

### 🛡️ Crop Insurance Pool Functions
- `contribute-to-insurance(coop-id, amount)` - Add funds to cooperative insurance pool
- `register-crop-coverage(coop-id, coverage-amount, crop-type, coverage-months)` - Register crops for insurance coverage
- `file-insurance-claim(coop-id, claim-amount, loss-type, description, evidence-hash)` - File claim for crop losses
- `vote-on-claim(claim-id, vote)` - Vote on insurance claim validity
- `execute-claim-payout(claim-id)` - Execute approved insurance claim payouts

### Read-Only Functions

#### Cooperative Queries
- `get-cooperative(coop-id)` - View cooperative details
- `get-member-info(coop-id, member)` - Check member status and shares
- `get-coop-resources(coop-id)` - View available resources
- `get-proposal(proposal-id)` - Check proposal details and voting results

#### Insurance Queries
- `get-insurance-pool(coop-id)` - View insurance pool status and statistics
- `get-member-coverage(coop-id, member)` - Check member's insurance coverage details
- `get-insurance-claim(claim-id)` - View insurance claim details and voting results
- `get-claim-vote(claim-id, voter)` - Check individual votes on insurance claims
- `calculate-premium(coverage-amount)` - Calculate required premium for coverage amount

## 🚀 Usage Flow

### Basic Cooperative Operations
1. **Create Cooperative**: Founder calls `create-cooperative` with cooperative name
2. **Add Members**: Farmers join using `join-cooperative` with STX contribution
3. **Pool Resources**: Members contribute additional resources via `contribute-resources`
4. **Make Decisions**: Create proposals and vote democratically on cooperative matters
5. **Share Profits**: Distribute and claim profits based on member share percentages

### 🛡️ Crop Insurance Workflow
1. **Fund Insurance Pool**: Members contribute to shared insurance fund using `contribute-to-insurance`
2. **Register Coverage**: Farmers register their crops with desired coverage amounts and duration
3. **Pay Premiums**: Automatic 5% premium calculation and payment upon coverage registration
4. **File Claims**: Submit insurance claims with evidence hash for crop losses
5. **Community Voting**: Members vote democratically on claim validity within 24-hour period
6. **Receive Payouts**: Approved claims automatically execute payouts to affected farmers

## 🔧 Technical Details

### Core Architecture
- Built on Stacks blockchain using Clarity smart contract language
- Two integrated smart contracts: `FarmerCo-op.clar` and `CropInsurancePool.clar`
- Share-based voting system where contributions increase voting power
- 144-block voting periods (approximately 24 hours)
- Automatic profit distribution based on member share ratios
- Resource tracking for funds, equipment value, and land size

### Insurance Pool Specifications
- **Premium Rate**: Fixed 5% of coverage amount
- **Coverage Limits**: Up to 1,000,000 STX per member
- **Coverage Duration**: Flexible monthly periods (720 blocks per month)
- **Claim Requirements**: Minimum 2 community votes for approval
- **Payout Mechanism**: Instant execution for approved claims
- **Evidence Tracking**: SHA-256 hash storage for claim documentation

## Testing

Deploy and test using Clarinet:

```bash
clarinet check
clarinet test
clarinet deploy
```

## 🔒 Contract Security

### Core Security Measures
- Member verification for all critical operations
- Voting period enforcement prevents late votes
- Duplicate vote prevention
- Fund sufficiency checks before transfers
- Access control for sensitive functions

### Insurance-Specific Security
- **Coverage Validation**: Claims cannot exceed registered coverage amounts
- **Time-bound Claims**: Claims must be filed within coverage period
- **Democratic Approval**: Multi-member voting required for claim approval
- **Double-spending Prevention**: Claims can only be paid once
- **Self-voting Protection**: Claimants cannot vote on their own claims
- **Evidence Requirements**: Cryptographic hash verification for claim documentation
- **Fund Solvency**: Pool balance verification before payouts

## 📊 Example Insurance Scenarios

### 🌽 Corn Crop Protection
```
Coverage: 50,000 STX for corn crop
Premium: 2,500 STX (5%)
Duration: 6 months growing season
Covered Events: Drought, flood, hail, pest damage
```

### 🌾 Wheat Collective Coverage
```
5 farmers pool 100,000 STX insurance fund
Each covers 20,000 STX worth of wheat
Total premiums: 5,000 STX
Shared risk mitigation across cooperative
```

---

🌱 **Built for farmers, by the blockchain community** - Empowering agricultural cooperatives with decentralized technology and shared risk management.
