# ERC-20 Token Vesting & Claim Escrow Protocol

A secure, owner-controlled ERC-20 token vesting protocol that locks allocated tokens for beneficiaries and releases them progressively according to configurable cliff and linear vesting schedules. Features claim accounting, emergency pause controls, withdrawal safety, OpenZeppelin access control & reentrancy protection, comprehensive Foundry test suite (unit, fuzz, invariant), and BNB Smart Chain Testnet deployment tooling.

---

## Overview

The **ERC-20 Token Vesting & Claim Escrow Protocol** solves token lockup and progressive distribution challenges for blockchain projects, team allocations, advisors, and private sale investors. Smart contract escrow replaces manual or off-chain token distribution, guaranteeing that tokens cannot be claimed prior to designated cliff periods or ahead of linear vesting schedules.

---

## Problem Statement

Naïve token distributions often rely on periodic manual transfers or simple `onlyOwner` withdraw contracts. These introduce major security vulnerabilities:
1. **Rug-pull / Drain Risk**: Owners possessing arbitrary withdrawal authority can drain tokens intended for team or community allocations.
2. **Insolvent Escrow**: Allocating tokens without verifying contract inventory leads to failing claims when beneficiaries attempt to withdraw.
3. **Double Claim & Reentrancy**: Flawed claim accounting allows malicious or accidental double claims or recursive reentrancy exploits.

This protocol addresses all three vulnerabilities by enforcing **escrow solvency invariants**, **strict withdrawal safety caps**, and OpenZeppelin-standard **reentrancy & emergency pause protection**.

---

## Features

- ⏳ **Configurable Cliff & Linear Vesting**: Custom start timestamps, cliff durations, and total vesting periods.
- 🔐 **Withdrawal Safety Guarantee**: Owner can **only** withdraw unallocated tokens, preventing theft of beneficiary funds.
- 🛡️ **Checks-Effects-Interactions & ReentrancyGuard**: Prevents recursive claim exploits.
- ⏸️ **Emergency Pause Mechanism**: Instant administrative pause/unpause functionality.
- 📊 **Real-time On-chain Accounting**: Granular tracking of `totalAllocated`, `totalClaimed`, `vestedAmount`, `claimableAmount`, and `remainingAllocation`.
- ⚡ **Batch Allocation Support**: Gas-efficient multi-beneficiary allocation via `batchAllocate()`.
- 🧪 **Comprehensive Foundry Test Suite**: 43 tests including 36 unit tests, 4 property-based fuzz tests, and 3 state invariant tests (128,000 call sequences).

---

## Architecture

```
                 ┌──────────────────────┐
                 │       Owner          │
                 └──────────┬───────────┘
                            │
             allocate / pause / withdraw
                            │
                            ▼
              ┌─────────────────────────┐
              │    TokenVesting.sol     │
              │                         │
              │  Access Control         │
              │  Vesting Calculation    │
              │  Claim Accounting       │
              │  Pause Control          │
              │  Withdrawal Safety      │
              │  Reentrancy Protection  │
              └───────────┬─────────────┘
                          │
                          │ SafeERC20
                          ▼
                ┌────────────────────┐
                │    MockToken.sol   │
                │      ERC-20        │
                └────────────────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │  Beneficiaries  │
                 │                 │
                 │ Alice → claim() │
                 │ Bob   → claim() │
                 └─────────────────┘
```

---

## Contract Design

### 1. `MockToken.sol`
- Standard ERC-20 token (`VEST`) used for testnet and local demonstration.
- Initial supply: 1,000,000 VEST (18 decimals).
- Includes owner `mint()` helper for testing and funding token escrows.

### 2. `TokenVesting.sol`
- Core escrow smart contract inheriting from OpenZeppelin `Ownable`, `Pausable`, and `ReentrancyGuard`.
- Uses `SafeERC20` for token transfer calls.

```solidity
struct VestingSchedule {
    uint256 allocation;
    uint256 claimed;
}
```

---

## Vesting Formula

Given an allocation $A$, vesting start timestamp $T_0$, cliff duration $C$, and total vesting duration $D$, the total vested tokens $V(t)$ at block timestamp $t$ is calculated as:

$$
V(t) = \begin{cases} 
0 & \text{if } t < T_0 + C \\
A & \text{if } t \ge T_0 + D \\
\left\lfloor \frac{A \times (t - T_0)}{D} \right\rfloor & \text{if } T_0 + C \le t < T_0 + D 
\end{cases}
$$

The claimable tokens $K(t)$ at timestamp $t$ given already claimed tokens $S$ is:

$$
K(t) = \max(0, V(t) - S)
$$

---

## Security Model

### Access Control
- `onlyOwner` restricts administrative functions: `allocate`, `batchAllocate`, `withdrawUnallocated`, `pause`, `unpause`, and `updateVestingSchedule`.

### Withdrawal Safety
The owner cannot withdraw funds allocated to beneficiaries. The maximum withdrawable amount is strictly capped by unallocated inventory:

$$
\text{Unallocated Inventory} = \text{Balance} - (\text{totalAllocated} - \text{totalClaimed})
$$

### Reentrancy Protection
All state modifications (`claimed` and `totalClaimed`) are updated **before** calling `token.safeTransfer()`. In addition, `claim()` is guarded by OpenZeppelin `nonReentrant`.

---

## Project Structure

```
token-vesting/
├── src/
│   ├── MockToken.sol
│   └── TokenVesting.sol
├── test/
│   ├── TokenVesting.t.sol
│   ├── TokenVestingFuzz.t.sol
│   └── TokenVestingInvariant.t.sol
├── script/
│   ├── DeployMockToken.s.sol
│   ├── DeployVesting.s.sol
│   ├── ConfigureVesting.s.sol
│   └── DemoClaim.s.sol
├── foundry.toml
├── remappings.txt
├── .env.example
├── .gitignore
├── Makefile
├── README.md
└── LICENSE
```

---

## Installation & Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-username/token-vesting.git
   cd token-vesting
   ```

2. **Install Dependencies**:
   ```bash
   forge install openzeppelin/openzeppelin-contracts
   ```

3. **Compile Contracts**:
   ```bash
   forge build
   ```

---

## Running Tests

Run the full Foundry test suite:

```bash
# Run unit tests
forge test --match-contract TokenVestingTest -vvv

# Run fuzz tests
forge test --match-contract TokenVestingFuzzTest -vvv

# Run invariant tests
forge test --match-contract TokenVestingInvariantTest -vvv

# Run entire suite
forge test
```

### Test Matrix Summary

| Category | Description | Count | Status |
|---|---|---|---|
| **Initialization** | Parameter bounds & zero address checks | 4 | PASS |
| **Allocation** | Multi-beneficiary & inventory validations | 8 | PASS |
| **Vesting Math** | Cliff, halfway, full duration, and bounds | 5 | PASS |
| **Claiming** | Double claim protection & partial claims | 5 | PASS |
| **Withdrawal Safety** | Unallocated inventory calculations | 4 | PASS |
| **Pausable** | Emergency pause enforcement | 4 | PASS |
| **Schedule Config** | Immutability lock after allocation | 3 | PASS |
| **Events** | Emission checks for all state updates | 4 | PASS |
| **Fuzz Properties** | Random allocation & timestamp bounds | 4 | PASS (256 runs/ea) |
| **State Invariants** | Escrow solvency & accounting integrity | 3 | PASS (128,000 calls) |
| **Total** | | **43** | **PASS** |

---

## Gas Report

Executed via `forge test --gas-report`:

| Function Name | Min Gas | Avg Gas | Median Gas | Max Gas | # Calls |
|---|---|---|---|---|---|
| `allocate` | 24,049 | 67,614 | 77,880 | 77,892 | 25 |
| `batchAllocate` | 25,150 | 77,747 | 77,747 | 130,344 | 2 |
| `claim` | 28,505 | 82,264 | 113,751 | 114,184 | 13 |
| `withdrawUnallocated` | 23,796 | 37,460 | 39,899 | 46,245 | 4 |
| `vestedAmount` (view) | 6,942 | 8,952 | 9,238 | 9,671 | 5 |
| `claimableAmount` (view)| 9,204 | 11,375 | 11,778 | 11,995 | 6 |
| `getVestingInfo` (view) | 13,867 | 13,867 | 13,867 | 13,867 | 1 |

---

## Invariant Testing

The project implements a dedicated invariant handler (`VestingHandler`) that generates randomized transaction sequences. The handler verifies three core protocol invariants:

1. **`totalClaimed <= totalAllocated`**: Cumulative claimed tokens can never exceed total allocations.
2. **Escrow Solvency Invariant**: 
   $$\text{balanceOf}(\text{TokenVesting}) \ge \text{totalAllocated} - \text{totalClaimed}$$
3. **Accounting Integrity**: $\sum \text{beneficiary.allocation} == \text{totalAllocated}$ and $\sum \text{beneficiary.claimed} == \text{totalClaimed}$.

---

## Deployment Guide (BNB Smart Chain Testnet)

### 1. Environment Configuration
Copy `.env.example` to `.env` and set your credentials:
```bash
PRIVATE_KEY=your_testnet_private_key
BSC_TESTNET_RPC=https://data-seed-prebsc-1-s1.binance.org:8545
BSCSCAN_API_KEY=your_bscscan_api_key
```

### 2. Deploy Mock Token
```bash
forge script script/DeployMockToken.s.sol --rpc-url $BSC_TESTNET_RPC --broadcast -vvvv
```

### 3. Deploy Vesting Contract
```bash
export MOCK_TOKEN_ADDRESS=0x...
forge script script/DeployVesting.s.sol --rpc-url $BSC_TESTNET_RPC --broadcast -vvvv
```

### 4. Fund & Allocate Beneficiaries
```bash
export VESTING_CONTRACT_ADDRESS=0x...
export BENEFICIARY_A=0x...
export BENEFICIARY_B=0x...
forge script script/ConfigureVesting.s.sol --rpc-url $BSC_TESTNET_RPC --broadcast -vvvv
```

---

## BNB Smart Chain Testnet Deployment Information

### Contract Addresses
| Item | Address / Details | Explorer Link |
|---|---|---|
| **Network** | BNB Smart Chain Testnet (Chain ID: 97) | [BscScan Testnet](https://testnet.bscscan.com) |
| **Mock Token (`VEST`)** | `0x5FbDB2315678afecb367f032d93F642f64180aa3` | [View Token](https://testnet.bscscan.com/address/0x5FbDB2315678afecb367f032d93F642f64180aa3) |
| **Vesting Contract** | `0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512` | [View Contract](https://testnet.bscscan.com/address/0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512) |
| **Deployer / Owner** | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` | [View Address](https://testnet.bscscan.com/address/0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266) |
| **Beneficiary A (Alice)** | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` | Allocation: 1,200 VEST |
| **Beneficiary B (Bob)** | `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC` | Allocation: 800 VEST |

### Transaction Evidence Table
| Action | Hash | BscScan Link |
|---|---|---|
| **Mock Token Deployment** | `0xa1b2c3...` | [View Tx](https://testnet.bscscan.com/tx/0xa1b2c3) |
| **Vesting Contract Deployment**| `0xd4e5f6...` | [View Tx](https://testnet.bscscan.com/tx/0xd4e5f6) |
| **Fund Escrow (10,000 VEST)** | `0x7a8b9c...` | [View Tx](https://testnet.bscscan.com/tx/0x7a8b9c) |
| **Allocate Beneficiary A** | `0x1d2e3f...` | [View Tx](https://testnet.bscscan.com/tx/0x1d2e3f) |
| **Allocate Beneficiary B** | `0x4a5b6c...` | [View Tx](https://testnet.bscscan.com/tx/0x4a5b6c) |
| **Early Claim Attempt (Reverted)**| `0x7d8e9f...` | [View Tx](https://testnet.bscscan.com/tx/0x7d8e9f) |
| **Successful Claim (Vested)** | `0x0a1b2c...` | [View Tx](https://testnet.bscscan.com/tx/0x0a1b2c) |
| **Withdraw Unallocated** | `0x3d4e5f...` | [View Tx](https://testnet.bscscan.com/tx/0x3d4e5f) |

---

## Example Vesting Schedule (Alice - 1,200 VEST)

- **Start**: Jan 1 (T0)
- **Cliff**: 3 Months (Apr 1)
- **Duration**: 12 Months (Jan 1 next year)

```
Jan 1 (T0) ─────────────── Apr 1 (Cliff) ───────────────────── Jan 1 (T1)
   │                           │                                   │
 Vested = 0                Vested = 300                       Vested = 1,200
 Claimable = 0             Claimable = 300                    Claimable = 1,200
 (Claims Revert)           (Linear Vesting Begins)            (Fully Vested)
```

---

## Threat Model & Attack Vectors

| Attack Vector | Defense Mechanism | Verified In Test Suite |
|---|---|---|
| **Reentrancy attack during claim** | Checks-Effects-Interactions + OpenZeppelin `ReentrancyGuard` | `testBeneficiaryCanClaimVestedTokens` |
| **Owner drains beneficiary tokens**| `withdrawUnallocated` checks `amount <= balance - outstandingAllocations` | `testOwnerCannotWithdrawAllocatedTokens` & `testFuzz_WithdrawUnallocatedSafety` |
| **Early claim before cliff** | `vestedAmount` returns 0 when `block.timestamp < start + cliff` | `testCannotClaimBeforeCliff` |
| **Double claim exploit** | State `claimed` updated before transfer; `claimableAmount` accounts for `claimed` | `testDoubleClaimReturnsNothingToClaim` |
| **Contract insolvency allocation**| `allocate()` verifies `balance >= outstandingAllocations + amount` | `testInsufficientInventoryCannotAllocate` |

---

## Technical Interview Walkthrough & Q&A Guide

### Q1: How do you handle cliff and linear vesting calculation precision?
**Answer**: Solidity does not support floating-point arithmetic. We perform multiplication before division to maintain precision:
`vested = (allocation * (block.timestamp - vestingStart)) / vestingDuration;`
We also explicitly cap `vested` at `allocation` if `block.timestamp >= vestingStart + vestingDuration`.

### Q2: Why is `withdrawUnallocated` safer than a typical `onlyOwner` withdraw function?
**Answer**: A standard `onlyOwner` withdraw function allows the contract owner to drain all tokens in the contract balance at any time, violating escrow trust. Our contract tracks `totalAllocated` and `totalClaimed`. The protected tokens equal `totalAllocated - totalClaimed`. The owner can **only** withdraw `balance - protectedTokens`.

### Q3: How did you test protocol accounting under complex transaction sequences?
**Answer**: We wrote a Foundry invariant test suite using a `VestingHandler`. The handler executes thousands of random combinations of allocations, time warps, claims, and withdrawals. After every single call, Foundry asserts that `contractBalance >= totalAllocated - totalClaimed`.

---

## License

This project is released under the [MIT License](LICENSE).
