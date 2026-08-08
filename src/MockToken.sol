// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockToken
 * @dev Simple ERC-20 token used for testing and testnet demonstration of the TokenVesting protocol.
 */
contract MockToken is ERC20, Ownable {
    uint8 private constant DECIMALS = 18;
    uint256 private constant INITIAL_SUPPLY = 1_000_000 * 10**DECIMALS;

    /**
     * @dev Initializes the mock token with name "Vesting Test Token", symbol "VEST",
     * and mints 1,000,000 VEST to the deployer.
     */
    constructor() ERC20("Vesting Test Token", "VEST") Ownable(msg.sender) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /**
     * @notice Allows the contract owner to mint additional tokens for demo/testing purposes.
     * @param to Target address to receive minted tokens.
     * @param amount Amount of tokens (in wei unit) to mint.
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
