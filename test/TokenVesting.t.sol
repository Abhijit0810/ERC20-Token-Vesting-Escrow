// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MockToken.sol";
import "../src/TokenVesting.sol";

contract TokenVestingTest is Test {
    MockToken public token;
    TokenVesting public vesting;

    address public owner = address(this);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public charlie = address(0x0C0C);

    uint256 public constant INITIAL_TOKEN_SUPPLY = 1_000_000 * 10**18;
    uint256 public constant VESTING_START = 1000;
    uint256 public constant CLIFF_DURATION = 90 days;    // 3 months
    uint256 public constant VESTING_DURATION = 365 days; // 12 months

    // Events to verify
    event BeneficiaryAllocated(address indexed beneficiary, uint256 amount);
    event TokensClaimed(address indexed beneficiary, uint256 amount);
    event UnallocatedTokensWithdrawn(address indexed owner, uint256 amount);
    event VestingConfigurationUpdated(uint256 start, uint256 cliff, uint256 duration);
    event Paused(address account);
    event Unpaused(address account);

    function setUp() public {
        vm.warp(VESTING_START);
        token = new MockToken();
        vesting = new TokenVesting(
            address(token),
            VESTING_START,
            CLIFF_DURATION,
            VESTING_DURATION
        );

        // Fund vesting contract with 10,000 TEST tokens for escrow testing
        token.transfer(address(vesting), 10_000 * 10**18);
    }

    // --- 1. Initialization Tests ---

    function testConstructorSetsCorrectParameters() public view {
        assertEq(address(vesting.token()), address(token));
        assertEq(vesting.vestingStart(), VESTING_START);
        assertEq(vesting.cliffDuration(), CLIFF_DURATION);
        assertEq(vesting.vestingDuration(), VESTING_DURATION);
        assertEq(vesting.totalAllocated(), 0);
        assertEq(vesting.totalClaimed(), 0);
    }

    function testConstructorRevertsOnZeroAddressToken() public {
        vm.expectRevert(TokenVesting.ZeroAddress.selector);
        new TokenVesting(address(0), VESTING_START, CLIFF_DURATION, VESTING_DURATION);
    }

    function testConstructorRevertsOnZeroDuration() public {
        vm.expectRevert(TokenVesting.InvalidVestingSchedule.selector);
        new TokenVesting(address(token), VESTING_START, CLIFF_DURATION, 0);
    }

    function testConstructorRevertsOnCliffGreaterThanDuration() public {
        vm.expectRevert(TokenVesting.InvalidVestingSchedule.selector);
        new TokenVesting(address(token), VESTING_START, 400 days, 365 days);
    }

    // --- 2. Allocation Tests ---

    function testOwnerCanAllocate() public {
        uint256 amount = 1_200 * 10**18;
        vesting.allocate(alice, amount);

        (uint256 alloc, uint256 claimed) = vesting.vestingSchedules(alice);
        assertEq(alloc, amount);
        assertEq(claimed, 0);
        assertEq(vesting.totalAllocated(), amount);
    }

    function testNonOwnerCannotAllocate() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        vesting.allocate(bob, 500 * 10**18);
    }

    function testZeroAddressCannotBeAllocated() public {
        vm.expectRevert(TokenVesting.ZeroAddress.selector);
        vesting.allocate(address(0), 1_000 * 10**18);
    }

    function testZeroAllocationCannotBeCreated() public {
        vm.expectRevert(TokenVesting.ZeroAllocation.selector);
        vesting.allocate(alice, 0);
    }

    function testInsufficientInventoryCannotAllocate() public {
        // Balance is 10,000 TEST. Trying to allocate 10,001 TEST must revert.
        uint256 excessAmount = 10_001 * 10**18;
        vm.expectRevert(TokenVesting.InsufficientInventory.selector);
        vesting.allocate(alice, excessAmount);
    }

    function testMultipleAllocationsToSameBeneficiary() public {
        vesting.allocate(alice, 500 * 10**18);
        vesting.allocate(alice, 700 * 10**18);

        (uint256 alloc, ) = vesting.vestingSchedules(alice);
        assertEq(alloc, 1_200 * 10**18);
        assertEq(vesting.totalAllocated(), 1_200 * 10**18);
    }

    function testBatchAllocate() public {
        address[] memory beneficiaries = new address[](3);
        beneficiaries[0] = alice;
        beneficiaries[1] = bob;
        beneficiaries[2] = charlie;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1_200 * 10**18;
        amounts[1] = 800 * 10**18;
        amounts[2] = 500 * 10**18;

        vesting.batchAllocate(beneficiaries, amounts);

        assertEq(vesting.totalAllocated(), 2_500 * 10**18);
        (uint256 allocAlice, ) = vesting.vestingSchedules(alice);
        (uint256 allocBob, ) = vesting.vestingSchedules(bob);
        (uint256 allocCharlie, ) = vesting.vestingSchedules(charlie);
        assertEq(allocAlice, 1_200 * 10**18);
        assertEq(allocBob, 800 * 10**18);
        assertEq(allocCharlie, 500 * 10**18);
    }

    function testBatchAllocateRevertsOnLengthMismatch() public {
        address[] memory beneficiaries = new address[](2);
        beneficiaries[0] = alice;
        beneficiaries[1] = bob;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1_200 * 10**18;

        vm.expectRevert(TokenVesting.ArrayLengthMismatch.selector);
        vesting.batchAllocate(beneficiaries, amounts);
    }

    // --- 3. Cliff & Vesting Math Tests ---

    function testCannotClaimBeforeCliff() public {
        uint256 amount = 1_200 * 10**18;
        vesting.allocate(alice, amount);

        // Advance 2 months (60 days), still before cliff (90 days)
        vm.warp(VESTING_START + 60 days);

        assertEq(vesting.vestedAmount(alice), 0);
        assertEq(vesting.claimableAmount(alice), 0);

        vm.prank(alice);
        vm.expectRevert(TokenVesting.NothingToClaim.selector);
        vesting.claim();
    }

    function testClaimAtExactCliff() public {
        uint256 amount = 1_200 * 10**18;
        vesting.allocate(alice, amount);

        // Warp exactly to cliff (90 days)
        vm.warp(VESTING_START + CLIFF_DURATION);

        uint256 expectedVested = (amount * CLIFF_DURATION) / VESTING_DURATION;
        assertEq(vesting.vestedAmount(alice), expectedVested);
        assertEq(vesting.claimableAmount(alice), expectedVested);

        uint256 balanceBefore = token.balanceOf(alice);
        vm.prank(alice);
        vesting.claim();
        assertEq(token.balanceOf(alice) - balanceBefore, expectedVested);
    }

    function testPartialVestingAtHalfway() public {
        uint256 amount = 1_200 * 10**18;
        vesting.allocate(alice, amount);

        // Warp to 6 months (182.5 days ~ 182.5/365 = half)
        uint256 halfTime = VESTING_START + (VESTING_DURATION / 2);
        vm.warp(halfTime);

        uint256 expectedVested = amount / 2;
        assertEq(vesting.vestedAmount(alice), expectedVested);
        assertEq(vesting.claimableAmount(alice), expectedVested);
    }

    function testFullVestingAtEnd() public {
        uint256 amount = 1_200 * 10**18;
        vesting.allocate(alice, amount);

        // Warp past duration (e.g. 1 year + 10 days)
        vm.warp(VESTING_START + VESTING_DURATION + 10 days);

        assertEq(vesting.vestedAmount(alice), amount);
        assertEq(vesting.claimableAmount(alice), amount);
    }

    function testVestedAmountDoesNotExceedAllocation() public {
        uint256 amount = 1_200 * 10**18;
        vesting.allocate(alice, amount);

        // Warp 10 years into the future
        vm.warp(VESTING_START + 3650 days);

        assertEq(vesting.vestedAmount(alice), amount);
    }

    // --- 4. Claiming & Escrow Accounting Tests ---

    function testBeneficiaryCanClaimVestedTokens() public {
        uint256 amount = 1_200 * 10**18;
        vesting.allocate(alice, amount);

        vm.warp(VESTING_START + (VESTING_DURATION / 2)); // 50% vested

        uint256 claimable = vesting.claimableAmount(alice);
        assertEq(claimable, 600 * 10**18);

        vm.prank(alice);
        vesting.claim();

        (uint256 alloc, uint256 claimed) = vesting.vestingSchedules(alice);
        assertEq(alloc, amount);
        assertEq(claimed, 600 * 10**18);
        assertEq(token.balanceOf(alice), 600 * 10**18);
        assertEq(vesting.totalClaimed(), 600 * 10**18);
    }

    function testMultipleClaimsOverTime() public {
        uint256 amount = 1_200 * 10**18;
        vesting.allocate(alice, amount);

        // 1st Claim at 6 months (50%)
        vm.warp(VESTING_START + 182.5 days);
        vm.prank(alice);
        vesting.claim();
        uint256 claimed1 = token.balanceOf(alice);

        // 2nd Claim at 9 months (75%)
        vm.warp(VESTING_START + 273.75 days);
        vm.prank(alice);
        vesting.claim();
        uint256 claimed2 = token.balanceOf(alice);
        assertTrue(claimed2 > claimed1);

        // 3rd Claim at 12 months (100%)
        vm.warp(VESTING_START + VESTING_DURATION);
        vm.prank(alice);
        vesting.claim();

        assertEq(token.balanceOf(alice), amount);
        assertEq(vesting.claimableAmount(alice), 0);
        assertEq(vesting.remainingAllocation(alice), 0);
    }

    function testDoubleClaimReturnsNothingToClaim() public {
        uint256 amount = 1_200 * 10**18;
        vesting.allocate(alice, amount);

        vm.warp(VESTING_START + (VESTING_DURATION / 2));
        vm.prank(alice);
        vesting.claim();

        // Immediate 2nd claim without time passage must revert
        vm.prank(alice);
        vm.expectRevert(TokenVesting.NothingToClaim.selector);
        vesting.claim();
    }

    function testCannotClaimMoreThanAllocation() public {
        uint256 amount = 1_200 * 10**18;
        vesting.allocate(alice, amount);

        vm.warp(VESTING_START + VESTING_DURATION + 100 days);
        vm.prank(alice);
        vesting.claim();

        assertEq(token.balanceOf(alice), amount);

        vm.prank(alice);
        vm.expectRevert(TokenVesting.NothingToClaim.selector);
        vesting.claim();
    }

    function testGetVestingInfo() public {
        uint256 amount = 1_200 * 10**18;
        vesting.allocate(alice, amount);

        vm.warp(VESTING_START + (VESTING_DURATION / 2));

        (
            uint256 alloc,
            uint256 claimed,
            uint256 vested,
            uint256 claimable,
            uint256 remaining
        ) = vesting.getVestingInfo(alice);

        assertEq(alloc, 1_200 * 10**18);
        assertEq(claimed, 0);
        assertEq(vested, 600 * 10**18);
        assertEq(claimable, 600 * 10**18);
        assertEq(remaining, 1_200 * 10**18);
    }

    // --- 5. Withdrawal & Escrow Safety Tests ---

    function testOwnerCanWithdrawUnallocatedTokens() public {
        // Contract has 10,000 TEST. Alice allocated 4,000 TEST.
        // Protected = 4,000. Unallocated = 6,000.
        vesting.allocate(alice, 4_000 * 10**18);

        assertEq(vesting.getUnallocatedBalance(), 6_000 * 10**18);

        uint256 ownerBalanceBefore = token.balanceOf(owner);
        vesting.withdrawUnallocated(4_000 * 10**18);

        assertEq(token.balanceOf(owner) - ownerBalanceBefore, 4_000 * 10**18);
        assertEq(vesting.getUnallocatedBalance(), 2_000 * 10**18);
    }

    function testOwnerCannotWithdrawAllocatedTokens() public {
        // Balance = 10,000. Alice = 6,000. Bob = 4,000. Total Allocated = 10,000. Unallocated = 0.
        vesting.allocate(alice, 6_000 * 10**18);
        vesting.allocate(bob, 4_000 * 10**18);

        assertEq(vesting.getUnallocatedBalance(), 0);

        vm.expectRevert(TokenVesting.AmountExceedsUnallocated.selector);
        vesting.withdrawUnallocated(1 * 10**18);
    }

    function testNonOwnerCannotWithdrawUnallocatedTokens() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        vesting.withdrawUnallocated(1_000 * 10**18);
    }

    // --- 6. Pausable Security Tests ---

    function testOwnerCanPauseAndUnpause() public {
        vesting.pause();
        assertTrue(vesting.paused());

        vesting.unpause();
        assertFalse(vesting.paused());
    }

    function testNonOwnerCannotPauseOrUnpause() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        vesting.pause();

        vesting.pause();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        vesting.unpause();
    }

    function testPausedContractRejectsClaim() public {
        vesting.allocate(alice, 1_200 * 10**18);
        vm.warp(VESTING_START + CLIFF_DURATION + 10 days);

        vesting.pause();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        vesting.claim();
    }

    function testUnpausedContractAllowsClaim() public {
        vesting.allocate(alice, 1_200 * 10**18);
        vm.warp(VESTING_START + CLIFF_DURATION + 10 days);

        vesting.pause();
        vesting.unpause();

        vm.prank(alice);
        vesting.claim();
        assertTrue(token.balanceOf(alice) > 0);
    }

    // --- 7. Schedule Update Security Tests ---

    function testOwnerCanUpdateScheduleBeforeAllocations() public {
        vesting.updateVestingSchedule(2000, 30 days, 180 days);
        assertEq(vesting.vestingStart(), 2000);
        assertEq(vesting.cliffDuration(), 30 days);
        assertEq(vesting.vestingDuration(), 180 days);
    }

    function testCannotUpdateScheduleAfterAllocationsExist() public {
        vesting.allocate(alice, 100 * 10**18);
        vm.expectRevert(TokenVesting.ConfigurationLocked.selector);
        vesting.updateVestingSchedule(2000, 30 days, 180 days);
    }

    function testNonOwnerCannotUpdateSchedule() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        vesting.updateVestingSchedule(2000, 30 days, 180 days);
    }

    // --- 8. Event Tests ---

    function testAllocationEmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit BeneficiaryAllocated(alice, 1_200 * 10**18);

        vesting.allocate(alice, 1_200 * 10**18);
    }

    function testClaimEmitsEvent() public {
        vesting.allocate(alice, 1_200 * 10**18);
        vm.warp(VESTING_START + VESTING_DURATION);

        vm.expectEmit(true, false, false, true);
        emit TokensClaimed(alice, 1_200 * 10**18);

        vm.prank(alice);
        vesting.claim();
    }

    function testWithdrawalEmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit UnallocatedTokensWithdrawn(owner, 1_000 * 10**18);

        vesting.withdrawUnallocated(1_000 * 10**18);
    }

    function testPauseEmitsEvent() public {
        vm.expectEmit(true, false, false, false);
        emit Paused(owner);

        vesting.pause();
    }
}
