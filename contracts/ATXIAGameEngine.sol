// SPDX-License-Identifier: APLv3 OR LATER
pragma solidity ^0.8.26;

// Flattened version of ATXIAGameEngine for auditing purposes.
// This file combines all inherited contracts and dependencies into a single file for transparency.

// === IERC20 Interface ===
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// === Address Library ===
library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value");
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly { let returndata_size := mload(returndata) revert(add(32, returndata), returndata_size) }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// === SafeERC20 Library ===
library SafeERC20 {
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// === Ownable2Step Abstract Contract ===
abstract contract Ownable2Step {
    address private _owner;
    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable2Step: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable2Step: zero address");
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(_owner, newOwner);
    }

    function acceptOwnership() public {
        require(msg.sender == _pendingOwner, "Ownable2Step: caller is not the new owner");
        emit OwnershipTransferred(_owner, _pendingOwner);
        _owner = _pendingOwner;
        _pendingOwner = address(0);
    }

    function owner() public view returns (address) {
        return _owner;
    }
}

// === ReentrancyGuard Abstract Contract ===
abstract contract ReentrancyGuard {
    uint256 private _status = 1;
    modifier nonReentrant() {
        require(_status != 2, "ReentrancyGuard: reentrant call");
        _status = 2;
        _;
        _status = 1;
    }
}

// === ATXIA Game Engine Contract ===
contract ATXIAGameEngine is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct PlayerData {
        uint64 lastTap;
        uint64 tapCooldown;
        uint64 lastBoostedTapTime;
        uint64 lastPassiveClaimTime;
        uint64 totalTaps;
        uint64 totalPassiveEarned;
        uint128 tapYield;
        uint128 totalBoostedYield;
    }

    mapping(address => PlayerData) public players;

    IERC20 public immutable atxToken;

    uint256 public constant BASE_REWARD = 1e18;   // 1 ATX
    uint256 public constant BASE_COOLDOWN = 60;   // 60 seconds
    uint256 public constant MAX_YIELD = 10e18;    // 10 ATX
    uint256 public constant MIN_COOLDOWN = 10;    // 10 seconds

    event IdleTapped(address indexed user, uint256 reward);
    event BoostedTap(address indexed user, uint256 baseYield, uint256 multiplier, uint256 boostedYield);
    event PassiveClaimed(address indexed user, uint256 reward, uint256 multiplier);
    event TapYieldUpgraded(address indexed user, uint256 levels, uint256 newYield);
    event CooldownUpgraded(address indexed user, uint256 levels, uint256 newCooldown);

    error CooldownActive();
    error ContractsNotAllowed();
    error AlreadyClaimed();
    error InsufficientTokens();

    constructor(address _atxToken) Ownable2Step() {
        require(_atxToken != address(0), "Invalid token");
        atxToken = IERC20(_atxToken);
    }

    modifier onlyHuman() {
        if (tx.origin != msg.sender) {
            revert ContractsNotAllowed();
        }
        _;
    }

    function tap() external nonReentrant onlyHuman {
        address user = msg.sender;
        PlayerData storage p = players[user];

        if (!_cooldownElapsed(p.lastTap, p.tapCooldown)) revert CooldownActive();

        uint256 finalYield = _computeTapYield(user, p);
        p.lastTap = uint64(block.timestamp);
        p.totalTaps++;

        atxToken.safeTransfer(user, finalYield);
        emit IdleTapped(user, finalYield);
    }

    function claimPassive() external nonReentrant onlyHuman {
        address user = msg.sender;
        PlayerData storage p = players[user];

        if (block.timestamp <= p.lastPassiveClaimTime) revert AlreadyClaimed();

        (uint256 reward, uint256 multiplier) = _computePassiveReward(p);
        p.lastPassiveClaimTime = uint64(block.timestamp);
        p.totalPassiveEarned += uint64(reward);

        atxToken.safeTransfer(user, reward);
        emit PassiveClaimed(user, reward, multiplier);
    }

    function upgradeTapYield(uint256 levels) external nonReentrant onlyHuman {
        PlayerData storage p = players[msg.sender];
        uint256 cost = levels * 1e18; // 1 ATX per level
        atxToken.safeTransferFrom(msg.sender, address(this), cost);

        uint256 newYield = p.tapYield + levels * 1e17; // +0.1 ATX per level
        if (newYield > MAX_YIELD) {
            newYield = MAX_YIELD;
        }
        p.tapYield = uint128(newYield);
        emit TapYieldUpgraded(msg.sender, levels, newYield);
    }

    function upgradeTapCooldown(uint256 levels) external nonReentrant onlyHuman {
        PlayerData storage p = players[msg.sender];
        uint256 cost = levels * 1e18; // 1 ATX per level
        atxToken.safeTransferFrom(msg.sender, address(this), cost);

        uint256 currentCooldown = p.tapCooldown > 0 ? p.tapCooldown : BASE_COOLDOWN;
        uint256 reduction = levels * 1; // 1 second per level
        uint256 newCooldown = currentCooldown > reduction ? currentCooldown - reduction : MIN_COOLDOWN;
        p.tapCooldown = uint64(newCooldown);
        emit CooldownUpgraded(msg.sender, levels, newCooldown);
    }

    function _cooldownElapsed(uint256 lastTapTime, uint256 cooldown) internal view returns (bool) {
        uint256 effectiveCooldown = cooldown > 0 ? cooldown : BASE_COOLDOWN;
        return block.timestamp >= lastTapTime + effectiveCooldown;
    }

    function _computeTapYield(address user, PlayerData storage p) internal returns (uint256) {
        uint256 base = p.tapYield > 0 ? p.tapYield : BASE_REWARD;
        if (p.totalTaps >= 500) {
            base = (base * 95) / 100; // 5% reduction after 500 taps
        }
        uint256 multiplier = _getTapMultiplier();
        uint256 reward = base * multiplier;

        if (multiplier > 1) {
            p.lastBoostedTapTime = uint64(block.timestamp);
            p.totalBoostedYield += uint128(reward - base);
            emit BoostedTap(user, base, multiplier, reward);
        }

        return reward;
    }

    function _getTapMultiplier() internal view returns (uint256) {
        uint256 day = block.timestamp / 86400;
        uint256 dayOfWeek = (day + 4) % 7; // 0: Thu, 1: Fri, 2: Sat, 3: Sun
        if (dayOfWeek == 2 || dayOfWeek == 3) { // Weekend: Sat or Sun
            return 3;
        } else {
            uint256 currentHour = (block.timestamp % 86400) / 3600;
            uint256 boostStartHour = day % 24;
            uint256 boostEndHour = (boostStartHour + 2) % 24;
            bool isBoostHour;
            if (boostStartHour < boostEndHour) {
                isBoostHour = currentHour >= boostStartHour && currentHour < boostEndHour;
            } else { // Wrap-around (e.g., 23:00 to 01:00)
                isBoostHour = currentHour >= boostStartHour || currentHour < boostEndHour;
            }
            return isBoostHour ? 2 : 1;
        }
    }

    function _computePassiveReward(PlayerData storage p) internal view returns (uint256, uint256) {
        uint256 elapsed = block.timestamp - p.lastPassiveClaimTime;
        if (elapsed > 24 * 3600) {
            elapsed = 24 * 3600; // Cap at 24 hours
        }
        uint256 multiplier = (p.lastBoostedTapTime == p.lastTap) ? 3 : 1;
        uint256 reward = (elapsed * BASE_REWARD * multiplier) / 3600;
        return (reward, multiplier);
    }
}