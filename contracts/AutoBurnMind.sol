// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library AutoBurnMind {
    function calculateDynamicBurn(uint256 baseRate, uint256 timeElapsed, uint256 volume) internal pure returns (uint256) {
        uint256 timeFactor = timeElapsed / 3600;
        uint256 volumeFactor = volume / 1e18;
        return baseRate + timeFactor + (volumeFactor / 10);
    }
}

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AtaxiaToken is ERC20, Ownable {
    using AutoBurnMind for uint256;

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 totalDuration;
        uint256 amountClaimed;
    }

    mapping(address => bool) public hasUserClaimedInitialTokens;
    mapping(address => VestingSchedule) public userVestingSchedules;
    mapping(address => uint256) public userStakes;

    uint256 public burnRatePercent = 1;
    bool public isClaimingEnabled = true;

    event TokensClaimed(address indexed recipient, uint256 amount);
    event TokensStaked(address indexed staker, uint256 amount);
    event TokensUnstaked(address indexed staker, uint256 reward);
    event VestingScheduleCreated(address indexed beneficiary, uint256 totalAmount);
    event ClaimingDisabled();
    event TokensMinted(address indexed recipient, uint256 amount);
    event TokensBurned(uint256 amount);

    constructor() ERC20("ATXIA", "ATX") Ownable(msg.sender) {
        _mint(msg.sender, 10_000_000 * 10 ** decimals());
    }

    function claimInitialTokens(address recipient) external onlyOwner {
        require(isClaimingEnabled, "Initial claim is disabled");
        require(!hasUserClaimedInitialTokens[recipient], "Recipient has already claimed");

        hasUserClaimedInitialTokens[recipient] = true;
        uint256 claimAmount = 1000 * 10 ** decimals();
        _mint(recipient, claimAmount);

        emit TokensClaimed(recipient, claimAmount);
    }

    function disableClaiming() external onlyOwner {
        isClaimingEnabled = false;
        emit ClaimingDisabled();
    }

    function mintAdditionalTokens(address recipient, uint256 amount) external onlyOwner {
        _mint(recipient, amount);
        emit TokensMinted(recipient, amount);
    }

    function stakeTokens(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient token balance to stake");
        _burn(msg.sender, amount);
        userStakes[msg.sender] += amount;

        emit TokensStaked(msg.sender, amount);
    }

    function unstakeTokens() external {
        uint256 stakedAmount = userStakes[msg.sender];
        require(stakedAmount > 0, "No tokens staked");

        userStakes[msg.sender] = 0;
        _mint(msg.sender, stakedAmount);

        emit TokensUnstaked(msg.sender, stakedAmount);
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
        require(block.timestamp >= schedule.startTime + schedule.cliffDuration, "Cliff period not yet reached");

        uint256 timeElapsed = block.timestamp - schedule.startTime;
        uint256 totalVested = (schedule.totalAmount * timeElapsed) / schedule.totalDuration;
        uint256 tokensToClaim = totalVested - schedule.amountClaimed;

        require(tokensToClaim > 0, "No vested tokens available to claim");

        schedule.amountClaimed += tokensToClaim;
        _mint(msg.sender, tokensToClaim);

        emit TokensClaimed(msg.sender, tokensToClaim);
    }

    function _update(address from, address to, uint256 amount) internal override {
        uint256 burnAmount = burnRatePercent.calculateDynamicBurn(block.timestamp, amount);
        uint256 tokensToBurn = (amount * burnAmount) / 100;
        uint256 tokensToSend = amount - tokensToBurn;

        if (from != address(0)) {
            _burn(from, tokensToBurn);
        }

        super._update(from, to, tokensToSend);
        emit TokensBurned(tokensToBurn);
    }
}
