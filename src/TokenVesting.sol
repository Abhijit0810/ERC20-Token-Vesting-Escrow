// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title TokenVesting
 * @dev An owner-controlled ERC-20 token vesting & claim escrow protocol.
 * Holds allocated tokens for beneficiaries and releases them linearly according to configurable cliff and duration schedules.
 */
contract TokenVesting is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Struct representing a beneficiary's vesting schedule state
    struct VestingSchedule {
        uint256 allocation;
        uint256 claimed;
    }

    /// @notice The ERC-20 token being vested
    IERC20 public immutable token;

    /// @notice Timestamp when vesting schedule begins
    uint256 public vestingStart;

    /// @notice Duration of the cliff period in seconds (from vestingStart)
    uint256 public cliffDuration;

    /// @notice Total duration of the vesting schedule in seconds (from vestingStart)
    uint256 public vestingDuration;

    /// @notice Cumulative total of tokens allocated to all beneficiaries
    uint256 public totalAllocated;

    /// @notice Cumulative total of tokens claimed by all beneficiaries
    uint256 public totalClaimed;

    /// @notice Mapping from beneficiary address to their VestingSchedule record
    mapping(address => VestingSchedule) public vestingSchedules;

    // Custom Errors
    error ZeroAddress();
    error ZeroAllocation();
    error NothingToClaim();
    error InsufficientInventory();
    error InvalidVestingSchedule();
    error AmountExceedsUnallocated();
    error ConfigurationLocked();
    error ArrayLengthMismatch();

    // Events
    event BeneficiaryAllocated(address indexed beneficiary, uint256 amount);
    event TokensClaimed(address indexed beneficiary, uint256 amount);
    event UnallocatedTokensWithdrawn(address indexed owner, uint256 amount);
    event VestingConfigurationUpdated(uint256 start, uint256 cliff, uint256 duration);

    /**
     * @notice Initializes the vesting contract parameters.
     * @param _token Address of the ERC-20 token to be vested.
     * @param _start Timestamp (in seconds) marking the start of vesting.
     * @param _cliff Duration of the cliff period in seconds.
     * @param _duration Total duration of the vesting period in seconds.
     */
    constructor(
        address _token,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration
    ) Ownable(msg.sender) {
        if (_token == address(0)) revert ZeroAddress();
        if (_duration == 0 || _cliff > _duration) revert InvalidVestingSchedule();

        token = IERC20(_token);
        vestingStart = _start;
        cliffDuration = _cliff;
        vestingDuration = _duration;

        emit VestingConfigurationUpdated(_start, _cliff, _duration);
    }

    /**
     * @notice Allocates tokens to a beneficiary.
     * @dev Checks that contract balance is sufficient to back all outstanding allocations plus the new allocation.
     * @param beneficiary Address receiving the token allocation.
     * @param amount Amount of tokens to allocate.
     */
    function allocate(address beneficiary, uint256 amount) external onlyOwner {
        if (beneficiary == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAllocation();

        uint256 outstandingAllocations = totalAllocated - totalClaimed;
        uint256 currentBalance = token.balanceOf(address(this));

        if (currentBalance < outstandingAllocations + amount) {
            revert InsufficientInventory();
        }

        vestingSchedules[beneficiary].allocation += amount;
        totalAllocated += amount;

        emit BeneficiaryAllocated(beneficiary, amount);
    }

    /**
     * @notice Batch allocates tokens to multiple beneficiaries.
     * @param beneficiaries Array of beneficiary addresses.
     * @param amounts Array of token amounts corresponding to each beneficiary.
     */
    function batchAllocate(
        address[] calldata beneficiaries,
        uint256[] calldata amounts
    ) external onlyOwner {
        if (beneficiaries.length != amounts.length) revert ArrayLengthMismatch();

        uint256 totalNewAllocation = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            if (beneficiaries[i] == address(0)) revert ZeroAddress();
            if (amounts[i] == 0) revert ZeroAllocation();
            totalNewAllocation += amounts[i];
        }

        uint256 outstandingAllocations = totalAllocated - totalClaimed;
        uint256 currentBalance = token.balanceOf(address(this));

        if (currentBalance < outstandingAllocations + totalNewAllocation) {
            revert InsufficientInventory();
        }

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            vestingSchedules[beneficiaries[i]].allocation += amounts[i];
            emit BeneficiaryAllocated(beneficiaries[i], amounts[i]);
        }

        totalAllocated += totalNewAllocation;
    }

    /**
     * @notice Allows a beneficiary to claim their currently vested and unclaimed tokens.
     * @dev Follows Checks-Effects-Interactions pattern, uses ReentrancyGuard, and respects Pause state.
     */
    function claim() external nonReentrant whenNotPaused {
        uint256 claimable = claimableAmount(msg.sender);
        if (claimable == 0) revert NothingToClaim();

        vestingSchedules[msg.sender].claimed += claimable;
        totalClaimed += claimable;

        token.safeTransfer(msg.sender, claimable);

        emit TokensClaimed(msg.sender, claimable);
    }

    /**
     * @notice Withdraws unallocated tokens from the contract escrow.
     * @dev Ensures owner cannot withdraw tokens locked for outstanding beneficiary allocations.
     * @param amount Token amount to withdraw.
     */
    function withdrawUnallocated(uint256 amount) external onlyOwner {
        uint256 outstandingAllocations = totalAllocated - totalClaimed;
        uint256 currentBalance = token.balanceOf(address(this));

        uint256 unallocated = currentBalance > outstandingAllocations
            ? currentBalance - outstandingAllocations
            : 0;

        if (amount > unallocated) revert AmountExceedsUnallocated();

        token.safeTransfer(msg.sender, amount);

        emit UnallocatedTokensWithdrawn(msg.sender, amount);
    }

    /**
     * @notice Updates the vesting schedule configuration.
     * @dev Can only be updated before any allocations have been recorded to ensure immutability once active.
     */
    function updateVestingSchedule(
        uint256 _start,
        uint256 _cliff,
        uint256 _duration
    ) external onlyOwner {
        if (totalAllocated > 0) revert ConfigurationLocked();
        if (_duration == 0 || _cliff > _duration) revert InvalidVestingSchedule();

        vestingStart = _start;
        cliffDuration = _cliff;
        vestingDuration = _duration;

        emit VestingConfigurationUpdated(_start, _cliff, _duration);
    }

    /**
     * @notice Pauses contract operations (specifically claiming).
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses contract operations.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // --- View Functions ---

    /**
     * @notice Calculates the total vested token amount for a given beneficiary at the current block timestamp.
     * @param beneficiary Address of the beneficiary.
     * @return vested Total vested token amount.
     */
    function vestedAmount(address beneficiary) public view returns (uint256 vested) {
        uint256 allocation = vestingSchedules[beneficiary].allocation;
        if (allocation == 0) return 0;

        if (block.timestamp < vestingStart + cliffDuration) {
            return 0;
        } else if (block.timestamp >= vestingStart + vestingDuration) {
            return allocation;
        } else {
            return (allocation * (block.timestamp - vestingStart)) / vestingDuration;
        }
    }

    /**
     * @notice Calculates the claimable token amount for a beneficiary.
     * @param beneficiary Address of the beneficiary.
     * @return claimable Vested tokens minus tokens already claimed.
     */
    function claimableAmount(address beneficiary) public view returns (uint256 claimable) {
        uint256 vested = vestedAmount(beneficiary);
        uint256 claimed = vestingSchedules[beneficiary].claimed;
        return vested > claimed ? vested - claimed : 0;
    }

    /**
     * @notice Calculates the remaining unclaimed allocation for a beneficiary.
     * @param beneficiary Address of the beneficiary.
     * @return remaining Allocation minus claimed tokens.
     */
    function remainingAllocation(address beneficiary) public view returns (uint256 remaining) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];
        return schedule.allocation - schedule.claimed;
    }

    /**
     * @notice Returns complete vesting info struct data for a beneficiary.
     * @param beneficiary Address of the beneficiary.
     * @return allocation Total token allocation.
     * @return claimed Amount of tokens claimed so far.
     * @return vested Amount of tokens vested so far.
     * @return claimable Amount of tokens currently available to claim.
     * @return remaining Amount of tokens remaining in schedule.
     */
    function getVestingInfo(address beneficiary)
        external
        view
        returns (
            uint256 allocation,
            uint256 claimed,
            uint256 vested,
            uint256 claimable,
            uint256 remaining
        )
    {
        allocation = vestingSchedules[beneficiary].allocation;
        claimed = vestingSchedules[beneficiary].claimed;
        vested = vestedAmount(beneficiary);
        claimable = claimableAmount(beneficiary);
        remaining = allocation - claimed;
    }

    /**
     * @notice Returns the amount of unallocated tokens sitting in the contract balance.
     * @return unallocated Balance minus outstanding allocations.
     */
    function getUnallocatedBalance() external view returns (uint256 unallocated) {
        uint256 outstandingAllocations = totalAllocated - totalClaimed;
        uint256 currentBalance = token.balanceOf(address(this));
        return currentBalance > outstandingAllocations ? currentBalance - outstandingAllocations : 0;
    }
}
