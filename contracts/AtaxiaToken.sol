// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./AutoBurnMind.sol";

contract ATXIA is ERC20, Ownable {
    using AutoBurnMind for uint256;

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 totalDuration;
        uint256 amountClaimed;
    }

    mapping(address => bool) public hasUserClaimedInitialTokens;
    mapping(address => VestingSchedule) private userVestingSchedules;
    mapping(address => uint256) public userStakes;

    uint256 public burnRate = 10;
    bool private isClaimingEnabled = true;

    event TokensClaimed(address indexed recipient, uint256 amount);
    event TokensStaked(address indexed staker, uint256 amount);
    event VestingScheduleCreated(address indexed beneficiary, uint256 totalAmount);

    constructor() ERC20("ATXIA", "ATX") Ownable(msg.sender) {
        _mint(msg.sender, 10_000_000 * 10 ** decimals());
    }

    function claimInitialTokens(address recipient) external onlyOwner {
        require(isClaimingEnabled, "Claiming disabled");
        require(!hasUserClaimedInitialTokens[recipient], "Already claimed");

        hasUserClaimedInitialTokens[recipient] = true;
        uint256 initialAmount = 1000 * 10 ** decimals();
        _mint(recipient, initialAmount);

        emit TokensClaimed(recipient, initialAmount);
    }

    function disableClaiming() external onlyOwner {
        isClaimingEnabled = false;
    }

    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 cliffDuration,
        uint256 totalDuration
    ) external onlyOwner {
        userVestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            startTime: block.timestamp,
            cliffDuration: cliffDuration,
            totalDuration: totalDuration,
            amountClaimed: 0
        });

        emit VestingScheduleCreated(beneficiary, amount);
    }

    function claimVestedTokens() external {
        VestingSchedule storage schedule = userVestingSchedules[msg.sender];
        require(block.timestamp >= schedule.startTime + schedule.cliffDuration, "Cliff not reached");

        uint256 timeElapsed = block.timestamp - schedule.startTime;
        uint256 totalVested = (schedule.totalAmount * timeElapsed) / schedule.totalDuration;
        uint256 claimable = totalVested - schedule.amountClaimed;

        require(claimable > 0, "Nothing to claim");

        schedule.amountClaimed += claimable;
        _mint(msg.sender, claimable);

        emit TokensClaimed(msg.sender, claimable);
    }

    function stake(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        _burn(msg.sender, amount);
        userStakes[msg.sender] += amount;

        emit TokensStaked(msg.sender, amount);
    }

    function _update(address from, address to, uint256 amount) internal override {
        uint256 burnAmount = burnRate.calculateDynamicBurn(block.timestamp, amount);
        uint256 tokensToBurn = (amount * burnAmount) / 100;
        uint256 tokensToSend = amount - tokensToBurn;

        if (from != address(0)) {
            _burn(from, tokensToBurn);
        }

        super._update(from, to, tokensToSend);
    }
}