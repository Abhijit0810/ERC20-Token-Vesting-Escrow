// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/MockToken.sol";
import "../src/TokenVesting.sol";

contract ConfigureVesting is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address tokenAddress = vm.envAddress("MOCK_TOKEN_ADDRESS");
        address vestingAddress = vm.envAddress("VESTING_CONTRACT_ADDRESS");
        address beneficiaryA = vm.envAddress("BENEFICIARY_A");
        address beneficiaryB = vm.envAddress("BENEFICIARY_B");

        MockToken token = MockToken(tokenAddress);
        TokenVesting vesting = TokenVesting(vestingAddress);

        uint256 totalFunding = 10_000 * 10**18;
        uint256 allocA = 1_200 * 10**18;
        uint256 allocB = 800 * 10**18;

        vm.startBroadcast(deployerPrivateKey);

        // 1. Transfer 10,000 VEST to Vesting Escrow
        token.transfer(address(vesting), totalFunding);
        console.log("Transferred 10,000 VEST to vesting contract");

        // 2. Allocate Beneficiary A (1,200 VEST)
        vesting.allocate(beneficiaryA, allocA);
        console.log("Allocated 1,200 VEST to Beneficiary A:", beneficiaryA);

        // 3. Allocate Beneficiary B (800 VEST)
        vesting.allocate(beneficiaryB, allocB);
        console.log("Allocated 800 VEST to Beneficiary B:", beneficiaryB);

        vm.stopBroadcast();
    }
}
