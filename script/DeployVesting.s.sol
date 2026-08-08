// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/TokenVesting.sol";

contract DeployVesting is Script {
    function run() external returns (TokenVesting vesting) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address tokenAddress = vm.envAddress("MOCK_TOKEN_ADDRESS");

        uint256 start = block.timestamp;
        uint256 cliff = 90 days;   // 3 months
        uint256 duration = 365 days; // 12 months

        vm.startBroadcast(deployerPrivateKey);
        vesting = new TokenVesting(tokenAddress, start, cliff, duration);
        vm.stopBroadcast();

        console.log("TokenVesting contract deployed at:", address(vesting));
        console.log("Vesting Start Timestamp:", start);
        console.log("Cliff Duration (seconds):", cliff);
        console.log("Vesting Duration (seconds):", duration);
    }
}
