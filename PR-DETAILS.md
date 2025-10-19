# Farmer Reputation and Reliability Scoring System

## Overview

This pull request introduces a new independent smart contract feature that enables farmers to build and maintain reputation profiles within their cooperatives. The system tracks farmer performance metrics through task completion records and peer-to-peer ratings, creating a transparent and decentralized trust framework for cooperative members.

The feature complements existing cooperative management, profit distribution, crop insurance, and equipment sharing systems by providing a reputation layer that helps members identify reliable farmers for critical tasks and collaborations.

## Technical Implementation

### New Smart Contract: `farmer-reputation.clar`

The feature is implemented as a standalone, independent Clarity v3 smart contract with no cross-contract dependencies or external trait calls.

### Data Structures

**`farmer-reputation` Map:**
- Stores reputation profiles per farmer (principal)
- Fields:
  - `reliability-score` (uint): Current reliability score, starts at 50 (medium), increases/decreases based on task performance
  - `tasks-completed` (uint): Count of successfully completed tasks
  - `tasks-failed` (uint): Count of failed or incomplete tasks
  - `last-updated` (uint): Block height of last reputation update
  - `participation-count` (uint): Total number of task participations

**`farmer-ratings` Map:**
- Stores peer ratings between farmers
- Key: `{ rater: principal, rated: principal }` (composite key)
- Fields:
  - `rating` (uint): 1-10 scale rating
  - `comment` (string-ascii 200): Optional feedback comment
  - `timestamp` (uint): Block height when rating was submitted

### Public Functions

1. **`initialize-farmer-reputation(farmer: principal) -> bool`**
   - Initializes a new farmer reputation profile with default values
   - Sets reliability-score to u50 (medium), all counters to u0
   - Returns ok(true) on success

2. **`record-task-completion(farmer: principal) -> bool`**
   - Records a successfully completed task
   - Increases reliability-score by u5 points
   - Increments tasks-completed and participation-count
   - Auto-initializes profile if not yet created
   - Returns ok(true) on success

3. **`record-task-failure(farmer: principal) -> bool`**
   - Records a failed or incomplete task
   - Decreases reliability-score by u3 points (floor at u0)
   - Increments tasks-failed and participation-count
   - Auto-initializes profile if not yet created
   - Returns ok(true) on success

4. **`submit-farmer-rating(rated-farmer: principal, rating: uint, comment: string-ascii 200) -> bool`**
   - Allows tx-sender to rate another farmer on a 1-10 scale
   - Validates rating is between u1 and u10 (ERR_INVALID_SCORE if not)
   - Prevents self-rating (ERR_UNAUTHORIZED if rater == rated-farmer)
   - Supports rating updates; resubmitting replaces previous rating
   - Returns ok(true) on success

### Read-Only Functions

1. **`get-farmer-reputation(farmer: principal) -> (optional reputation-profile)`**
   - Retrieves a farmer's current reputation profile
   - Returns None if farmer has no profile yet

2. **`get-farmer-rating(rater: principal, rated: principal) -> (optional rating-record)`**
   - Retrieves a specific rating between two farmers
   - Returns None if no rating exists between the pair

3. **`get-average-reliability-score(farmer: principal) -> uint`**
   - Calculates average reliability score = reliability-score / participation-count
   - Returns u0 if farmer has no participation history

4. **`get-farmer-success-rate(farmer: principal) -> uint`**
   - Calculates success rate percentage = (tasks-completed / total-tasks) * 100
   - Returns u0 if farmer has no tasks

### Error Handling

Comprehensive error constants defined in Clarity v3 format:
- `ERR_UNAUTHORIZED (u100)`: For self-rating or unauthorized actions
- `ERR_NOT_FOUND (u101)`: For missing data lookups
- `ERR_INVALID_SCORE (u102)`: For out-of-range rating values (not 1-10)
- `ERR_ALREADY_RATED (u103)`: Reserved for future use cases

All input parameters are validated:
- Rating must be between 1 and 10 (inclusive)
- Rater and rated principal must not be equal
- Auto-initialization handles non-existent profiles gracefully

### Contract Configuration

Added to `Clarinet.toml`:
```toml
[contracts.farmer-reputation]
path = 'contracts/farmer-reputation.clar'
clarity_version = 3
epoch = 'latest'
```

## Testing & Validation

### Contract Validation
- ✅ Contract passes `clarinet check` syntax validation
- ✅ Clarity v3 compliant with all proper data types and functions
- ✅ No cross-contract dependencies or trait calls

### Test Coverage
Comprehensive test suite (`tests/farmer-reputation.test.ts`) with 15 test cases covering:
- Farmer reputation profile initialization
- Task completion and failure tracking
- Reliability score updates
- Peer-to-peer rating submission
- Rating validation (1-10 range, self-rating prevention)
- Average reliability score calculation
- Success rate computation
- Participation count tracking
- Rating updates and multiple farmers
- Edge cases (no tasks, various scenarios)

### Dependency Installation
- ✅ `npm install` successful
- ✅ All Clarinet SDK and Vitest dependencies available

### CI/CD Pipeline
- ✅ GitHub Actions workflow configured (`./github/workflows/ci.yml`)
- ✅ Automatic syntax checking on push
- ✅ Docker-based Clarinet environment for consistent validation

## Integration

### Independence
This feature is **completely independent** and maintains zero cross-contract coupling:
- No calls to `coop-unified.clar` or other contracts
- No trait definitions or implementations
- Self-contained data storage via dedicated maps
- Can be deployed and used standalone

### Compatibility
- Operates seamlessly alongside existing Farmer Co-op features
- Does not modify or depend on cooperative membership, proposals, insurance, or equipment sharing
- Complements existing systems by providing reputation layer
- No changes to existing contract code or interfaces

### Use Cases
- Farmers can build reputation for future cooperative roles
- Members identify reliable farmers for project leadership or task assignments
- Transparent performance history visible to cooperative governance
- Foundation for reputation-weighted voting or incentive systems

## File Changes

### New Files
- `contracts/farmer-reputation.clar` - Main contract implementation (167 lines)
- `tests/farmer-reputation.test.ts` - Comprehensive test suite (221 lines)
- `.github/workflows/ci.yml` - GitHub Actions CI pipeline (13 lines)

### Modified Files
- `Clarinet.toml` - Added farmer-reputation contract configuration

### Line Ending Normalization
All files use LF (Unix) line endings for cross-platform compatibility.

## Deployment Notes

1. Deploy `farmer-reputation` contract to testnet/mainnet
2. Users call `initialize-farmer-reputation(farmer)` to create their profile
3. Cooperative founders call `record-task-completion/failure` to update performance
4. Any member can call `submit-farmer-rating` to rate peers
5. Read-only functions available for querying reputation data

## Future Enhancement Opportunities

- Integration with governance for reputation-weighted voting
- Incentive mechanisms based on reliability scores
- Time-decay of old reputation records for fairness
- Reputation thresholds for accessing certain cooperative features
- Automated reputation updates via oracle data
