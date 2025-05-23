// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./AutoBurnMind.sol";

contract ATXIA is ERC20, Ownable {
    using AutoBurnMind for uint256;

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 startBlock;
        uint256 cliffBlocks;
        uint256 durationBlocks;
        uint256 claimed;
    }

    mapping(address => VestingSchedule) private vesting;
    mapping(address => bool) private hasClaimed;

    event TokensClaimed(address indexed user, uint256 amount);
    event TokensStaked(address indexed user, uint256 amount);

    uint256 public constant BURN_RATE = 10; // 10%
    bool public isClaimingOpen = true;

    constructor(address initialOwner) ERC20("ATXIA", "ATX") Ownable(initialOwner) {
        _mint(initialOwner, 10_000_000 * 10 ** decimals());
    }

    function claimInitial(address recipient) external onlyOwner {
        if (!isClaimingOpen) revert("Claiming off");
        if (hasClaimed[recipient]) revert("Already claimed");

        uint256 amount = 1000 * 10 ** decimals();
        _mint(recipient, amount);
        hasClaimed[recipient] = true;

        emit TokensClaimed(recipient, amount);
    }

    function disableClaiming() external onlyOwner {
        isClaimingOpen = false;
    }

    function createVesting(
        address user,
        uint256 amount,
        uint256 cliffBlocks,
        uint256 totalBlocks
    ) external onlyOwner {
        if (totalBlocks == 0 || cliffBlocks > totalBlocks) revert("Invalid schedule");

        vesting[user] = VestingSchedule({
            totalAmount: amount,
            startBlock: block.number,
            cliffBlocks: cliffBlocks,
            durationBlocks: totalBlocks,
            claimed: 0
        });

        emit TokensStaked(user, amount);
    }

    function claimVested() external {
        VestingSchedule storage sched = vesting[msg.sender];
        if (sched.totalAmount == 0) revert("No schedule");

        uint256 blocksPassed = block.number - sched.startBlock;
        if (blocksPassed < sched.cliffBlocks) revert("Cliff not reached");

        uint256 totalUnlocked = (sched.totalAmount * blocksPassed) / sched.durationBlocks;
        uint256 available = totalUnlocked - sched.claimed;
        if (available == 0) revert("No claimable tokens");

        sched.claimed += available;
        _mint(msg.sender, available);

        emit TokensClaimed(msg.sender, available);
    }

    function stake(uint256 amount) external {
        if (balanceOf(msg.sender) < amount) revert("Insufficient balance");
        emit TokensStaked(msg.sender, amount);
    }
}