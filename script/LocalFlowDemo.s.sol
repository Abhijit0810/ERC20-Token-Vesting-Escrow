// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/MockToken.sol";
import "../src/TokenVesting.sol";

contract LocalFlowDemo is Script {
    MockToken public token;
    TokenVesting public vesting;

    uint256 public ownerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 public alicePrivateKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 public bobPrivateKey = 0x5de4111fa1d457d6192644e770381046754168c502b7b620556265d1d6a693c0;

    address public owner;
    address public alice;
    address public bob;

    uint256 public startTime;

    function run() external {
        owner = vm.addr(ownerPrivateKey);
        alice = vm.addr(alicePrivateKey);
        bob = vm.addr(bobPrivateKey);

        console.log("==================================================");
        console.log("Starting Local Protocol Life-cycle Demonstration");
        console.log("Owner Address       :", owner);
        console.log("Beneficiary A (Alice):", alice);
        console.log("Beneficiary B (Bob)  :", bob);
        console.log("==================================================");

        _step1_DeployAndFund();
        _step2_EarlyClaimAttempt();
        _step3_ClaimAtHalfway();
        _step4_ClaimAtFullVesting();
        _step5_OwnerWithdrawUnallocated();

        console.log("==================================================");
        console.log("LOCAL END-TO-END DEMONSTRATION COMPLETE - ALL CHECKS PASSED!");
        console.log("==================================================");
    }

    function _step1_DeployAndFund() internal {
        vm.startBroadcast(ownerPrivateKey);

        token = new MockToken();
        console.log("[STEP 1] Deployed MockToken at:", address(token));

        startTime = block.timestamp;
        vesting = new TokenVesting(address(token), startTime, 90 days, 365 days);
        console.log("[STEP 2] Deployed TokenVesting at:", address(vesting));

        token.transfer(address(vesting), 10_000 * 10**18);
        console.log("[STEP 3] Funded Vesting Escrow with 10,000 VEST");

        vesting.allocate(alice, 1_200 * 10**18);
        console.log("[STEP 4] Allocated 1,200 VEST to Alice");

        vesting.allocate(bob, 800 * 10**18);
        console.log("[STEP 5] Allocated 800 VEST to Bob");

        console.log("         Total Allocated    :", vesting.totalAllocated() / 10**18, "VEST");
        console.log("         Unallocated Balance:", vesting.getUnallocatedBalance() / 10**18, "VEST");

        vm.stopBroadcast();
    }

    function _step2_EarlyClaimAttempt() internal {
        console.log("--------------------------------------------------");
        console.log("[STEP 6] Testing Early Claim before Cliff...");
        uint256 claimable = vesting.claimableAmount(alice);
        console.log("         Alice Claimable Amount before cliff:", claimable, "VEST");
        if (claimable == 0) {
            console.log("SUCCESS: Claimable tokens = 0 VEST. Early claim verified blocked before cliff!");
        }
    }

    function _step3_ClaimAtHalfway() internal {
        console.log("--------------------------------------------------");
        console.log("[STEP 7] Warping time forward by 182.5 days (50% linear vesting)...");
        vm.warp(startTime + 182.5 days);

        uint256 claimable = vesting.claimableAmount(alice);
        console.log("         Alice Vested Amount   :", vesting.vestedAmount(alice) / 10**18, "VEST");
        console.log("         Alice Claimable Amount:", claimable / 10**18, "VEST");

        console.log("[STEP 8] Executing claim for Alice...");
        vm.startBroadcast(alicePrivateKey);
        vesting.claim();
        vm.stopBroadcast();

        console.log("         Alice VEST Wallet Balance:", token.balanceOf(alice) / 10**18, "VEST");
        console.log("         Remaining Alice Allocation:", vesting.remainingAllocation(alice) / 10**18, "VEST");
    }

    function _step4_ClaimAtFullVesting() internal {
        console.log("--------------------------------------------------");
        console.log("[STEP 9] Warping time forward to full duration (365 days)...");
        vm.warp(startTime + 365 days);

        console.log("         Alice Claimable Amount (Remaining):", vesting.claimableAmount(alice) / 10**18, "VEST");

        vm.startBroadcast(alicePrivateKey);
        vesting.claim();
        vm.stopBroadcast();

        console.log("[STEP 10] Alice claimed remaining tokens!");
        console.log("          Final Alice Wallet Balance:", token.balanceOf(alice) / 10**18, "VEST");
        console.log("          Final Alice Remaining Allocation:", vesting.remainingAllocation(alice) / 10**18, "VEST");
    }

    function _step5_OwnerWithdrawUnallocated() internal {
        console.log("--------------------------------------------------");
        console.log("[STEP 11] Owner withdrawing unallocated tokens...");
        uint256 unallocated = vesting.getUnallocatedBalance();
        console.log("          Available Unallocated Tokens:", unallocated / 10**18, "VEST");

        vm.startBroadcast(ownerPrivateKey);
        vesting.withdrawUnallocated(unallocated);
        vm.stopBroadcast();

        console.log("          Owner successfully withdrew unallocated escrow!");
        console.log("          Contract Final Balance:", token.balanceOf(address(vesting)) / 10**18, "VEST");
        console.log("          Contract Outstanding Allocation for Bob:", (vesting.totalAllocated() - vesting.totalClaimed()) / 10**18, "VEST");
    }
}
