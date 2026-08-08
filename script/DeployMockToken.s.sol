// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/MockToken.sol";

contract DeployMockToken is Script {
    function run() external returns (MockToken mockToken) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        mockToken = new MockToken();
        vm.stopBroadcast();

        console.log("MockToken deployed at:", address(mockToken));
    }
}
