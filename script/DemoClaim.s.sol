// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/TokenVesting.sol";

contract DemoClaim is Script {
    function run() external {
        uint256 beneficiaryPrivateKey = vm.envUint("BENEFICIARY_PRIVATE_KEY");
        address vestingAddress = vm.envAddress("VESTING_CONTRACT_ADDRESS");

        TokenVesting vesting = TokenVesting(vestingAddress);
        address beneficiary = vm.addr(beneficiaryPrivateKey);

        console.log("Checking claimable tokens for beneficiary:", beneficiary);
        uint256 claimable = vesting.claimableAmount(beneficiary);
        console.log("Claimable VEST tokens:", claimable);

        require(claimable > 0, "No tokens currently claimable!");

        vm.startBroadcast(beneficiaryPrivateKey);
        vesting.claim();
        vm.stopBroadcast();

        console.log("Successfully claimed vested tokens!");
    }
}
