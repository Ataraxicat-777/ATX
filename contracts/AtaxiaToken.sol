// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/* ==== Context.sol (OpenZeppelin) ==== */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

/* ==== Ownable.sol (OpenZeppelin) ==== */
abstract contract Ownable is Context {
    address private _owner;

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/* ==== ERC20.sol (OpenZeppelin - Flattened) ==== */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

interface IERC20Errors {
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidSpender(address spender);
}

abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 value) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) revert ERC20InvalidSender(from);
        if (to == address(0)) revert ERC20InvalidReceiver(to);
        _update(from, to, value);
    }

    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) revert ERC20InsufficientBalance(from, fromBalance, value);
            unchecked {
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                _totalSupply -= value;
            }
        } else {
            unchecked {
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    function _mint(address account, uint256 value) internal virtual {
        if (account == address(0)) revert ERC20InvalidReceiver(account);
        _update(address(0), account, value);
    }

    function _burn(address account, uint256 value) internal virtual {
        if (account == address(0)) revert ERC20InvalidSender(account);
        _update(account, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) internal virtual {
        _approve(owner, spender, value, true);
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) revert ERC20InvalidApprover(owner);
        if (spender == address(0)) revert ERC20InvalidSpender(spender);
        _allowances[owner][spender] = value;
        if (emitEvent) emit Approval(owner, spender, value);
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < value) revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}

/* ==== AutoBurnMind Library ==== */
library AutoBurnMind {
    function calculateDynamicBurn(uint256 baseRate, uint256 timeElapsed, uint256 volume) internal pure returns (uint256) {
        uint256 timeFactor = timeElapsed / 3600;
        uint256 volumeFactor = volume / 1e18;
        return baseRate + timeFactor + (volumeFactor / 10);
    }
}

/* ==== ATXIA Contract ==== */
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

    uint256 public constant BURN_RATE = 10;
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

    function createVesting(address user, uint256 amount, uint256 cliffBlocks, uint256 totalBlocks) external onlyOwner {
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