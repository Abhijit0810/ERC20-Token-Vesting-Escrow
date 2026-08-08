// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MockToken.sol";
import "../src/TokenVesting.sol";

/**
 * @title VestingHandler
 * @dev Handler contract executing randomized sequences of valid protocol interactions for invariant testing.
 */
contract VestingHandler is Test {
    MockToken public token;
    TokenVesting public vesting;

    address[] public beneficiaries;
    mapping(address => bool) public isBeneficiary;

    uint256 public constant VESTING_START = 1_000_000;
    uint256 public constant CLIFF_DURATION = 90 days;
    uint256 public constant VESTING_DURATION = 365 days;

    uint256 public ghost_sumAllocated;
    uint256 public ghost_sumClaimed;

    constructor(MockToken _token, TokenVesting _vesting) {
        token = _token;
        vesting = _vesting;

        // Pre-populate beneficiary pool
        beneficiaries.push(address(0xA11CE));
        beneficiaries.push(address(0xB0B));
        beneficiaries.push(address(0x0C0C));
        beneficiaries.push(address(0xD0D0));

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            isBeneficiary[beneficiaries[i]] = true;
        }
    }

    function allocate(uint8 beneficiaryIdx, uint256 amount) public {
        address beneficiary = beneficiaries[beneficiaryIdx % beneficiaries.length];

        uint256 unallocated = vesting.getUnallocatedBalance();
        if (unallocated == 0) return;

        amount = bound(amount, 1, unallocated);

        vesting.allocate(beneficiary, amount);
        ghost_sumAllocated += amount;
    }

    function claim(uint8 beneficiaryIdx) public {
        address beneficiary = beneficiaries[beneficiaryIdx % beneficiaries.length];

        if (vesting.paused()) return;

        uint256 claimable = vesting.claimableAmount(beneficiary);
        if (claimable == 0) return;

        vm.prank(beneficiary);
        vesting.claim();

        ghost_sumClaimed += claimable;
    }

    function warpTime(uint32 secondsToWarp) public {
        secondsToWarp = uint32(bound(secondsToWarp, 1 days, 30 days));
        vm.warp(block.timestamp + secondsToWarp);
    }

    function withdrawUnallocated(uint256 amount) public {
        uint256 unallocated = vesting.getUnallocatedBalance();
        if (unallocated == 0) return;

        amount = bound(amount, 1, unallocated);
        vesting.withdrawUnallocated(amount);
    }

    function getBeneficiaries() external view returns (address[] memory) {
        return beneficiaries;
    }
}

/**
 * @title TokenVestingInvariantTest
 * @dev State invariant assertions verified across hundreds of randomized transaction sequences.
 */
contract TokenVestingInvariantTest is Test {
    MockToken public token;
    TokenVesting public vesting;
    VestingHandler public handler;

    uint256 public constant VESTING_START = 1_000_000;
    uint256 public constant CLIFF_DURATION = 90 days;
    uint256 public constant VESTING_DURATION = 365 days;

    function setUp() public {
        vm.warp(VESTING_START);
        token = new MockToken();
        vesting = new TokenVesting(
            address(token),
            VESTING_START,
            CLIFF_DURATION,
            VESTING_DURATION
        );

        // Fund contract with 10,000,000 TEST
        token.mint(address(vesting), 10_000_000 * 10**18);

        handler = new VestingHandler(token, vesting);

        // Direct invariant target to handler
        targetContract(address(handler));
    }

    /// @dev Invariant 1: Total claimed tokens must NEVER exceed total allocated tokens.
    function invariant_TotalClaimedLeTotalAllocated() public view {
        assertLe(
            vesting.totalClaimed(),
            vesting.totalAllocated(),
            "Invariant Violation: Total claimed > Total allocated"
        );
    }

    /// @dev Invariant 2: Escrow Solvency — Contract token balance must ALWAYS be >= outstanding allocations.
    function invariant_EscrowSolvency() public view {
        uint256 outstanding = vesting.totalAllocated() - vesting.totalClaimed();
        uint256 contractBalance = token.balanceOf(address(vesting));
        assertGe(
            contractBalance,
            outstanding,
            "Invariant Violation: Contract is insolvent! Balance < Outstanding allocations"
        );
    }

    /// @dev Invariant 3: Accounting Integrity — Sum of individual allocations must equal totalAllocated state.
    function invariant_AllocationAccountingIntegrity() public view {
        address[] memory bens = handler.getBeneficiaries();
        uint256 sumAlloc = 0;
        uint256 sumClaimed = 0;

        for (uint256 i = 0; i < bens.length; i++) {
            (uint256 alloc, uint256 claimed) = vesting.vestingSchedules(bens[i]);
            sumAlloc += alloc;
            sumClaimed += claimed;
        }

        assertEq(sumAlloc, vesting.totalAllocated(), "Sum of allocations != totalAllocated");
        assertEq(sumClaimed, vesting.totalClaimed(), "Sum of claimed != totalClaimed");
    }
}
