// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MockToken.sol";
import "../src/TokenVesting.sol";

contract TokenVestingFuzzTest is Test {
    MockToken public token;
    TokenVesting public vesting;

    address public alice = address(0xA11CE);

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

        // Fund vesting contract with 10,000,000 TEST
        token.mint(address(vesting), 10_000_000 * 10**18);
    }

    /// @dev Property 1: Vested amount must NEVER exceed allocation regardless of timestamp.
    function testFuzz_VestedAmountNeverExceedsAllocation(uint256 allocation, uint32 warpOffset) public {
        allocation = bound(allocation, 1, 10_000_000 * 10**18);
        uint256 targetTime = VESTING_START + uint256(warpOffset);

        vesting.allocate(alice, allocation);
        vm.warp(targetTime);

        uint256 vested = vesting.vestedAmount(alice);
        assertLe(vested, allocation, "Vested amount exceeded allocation!");

        if (targetTime < VESTING_START + CLIFF_DURATION) {
            assertEq(vested, 0, "Vested amount must be zero before cliff!");
        } else if (targetTime >= VESTING_START + VESTING_DURATION) {
            assertEq(vested, allocation, "Vested amount must equal allocation after vesting duration!");
        }
    }

    /// @dev Property 2: Total claimed tokens can NEVER exceed total vested tokens.
    function testFuzz_ClaimedNeverExceedsVested(uint256 allocation, uint32 warpOffset) public {
        allocation = bound(allocation, 1, 10_000_000 * 10**18);
        uint256 targetTime = VESTING_START + uint256(warpOffset);

        vesting.allocate(alice, allocation);
        vm.warp(targetTime);

        uint256 claimable = vesting.claimableAmount(alice);
        if (claimable > 0) {
            vm.prank(alice);
            vesting.claim();
        }

        (, uint256 claimed) = vesting.vestingSchedules(alice);
        uint256 vested = vesting.vestedAmount(alice);

        assertLe(claimed, vested, "Claimed tokens exceeded vested tokens!");
        assertLe(claimed, allocation, "Claimed tokens exceeded allocation!");
    }

    /// @dev Property 3: Remaining allocation must ALWAYS equal allocation - claimed.
    function testFuzz_RemainingAllocationAlwaysMatches(uint256 allocation, uint32 warpOffset) public {
        allocation = bound(allocation, 1, 10_000_000 * 10**18);
        uint256 targetTime = VESTING_START + uint256(warpOffset);

        vesting.allocate(alice, allocation);
        vm.warp(targetTime);

        if (vesting.claimableAmount(alice) > 0) {
            vm.prank(alice);
            vesting.claim();
        }

        (, uint256 claimed) = vesting.vestingSchedules(alice);
        uint256 remaining = vesting.remainingAllocation(alice);

        assertEq(remaining, allocation - claimed, "Remaining allocation mismatch!");
    }

    /// @dev Property 4: Owner can never withdraw protected beneficiary tokens.
    function testFuzz_WithdrawUnallocatedSafety(
        uint256 extraFunding,
        uint256 allocation,
        uint256 withdrawAttempt
    ) public {
        extraFunding = bound(extraFunding, 0, 1_000_000 * 10**18);
        allocation = bound(allocation, 1, 5_000_000 * 10**18);

        if (extraFunding > 0) {
            token.transfer(address(vesting), extraFunding);
        }

        vesting.allocate(alice, allocation);

        uint256 unallocated = vesting.getUnallocatedBalance();

        withdrawAttempt = bound(withdrawAttempt, 0, unallocated + 1_000_000 * 10**18);

        if (withdrawAttempt <= unallocated) {
            uint256 balanceBefore = token.balanceOf(address(this));
            vesting.withdrawUnallocated(withdrawAttempt);
            assertEq(token.balanceOf(address(this)) - balanceBefore, withdrawAttempt);
        } else {
            vm.expectRevert(TokenVesting.AmountExceedsUnallocated.selector);
            vesting.withdrawUnallocated(withdrawAttempt);
        }
    }
}
