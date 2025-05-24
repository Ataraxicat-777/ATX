// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

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

contract ATXIA is IERC20 {
    string public constant NAME = "ATXIA";
    string public constant SYMBOL = "ATX";
    uint8 public constant DECIMALS = 18;
    uint256 public constant TOTAL_SUPPLY_CAP = 100_000_000_000_000 * (10 ** 18);

    address private _owner;
    uint256 private _status = 1;
    bool public isPaused = false;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;

    // Custom errors
    error Unauthorized(address account);
    error InvalidAddress(address addr);
    error InsufficientBalance(uint256 balance, uint256 amount);
    error InsufficientAllowance(uint256 allowance, uint256 amount);
    error ReentrantCall();
    error Paused();
    error SupplyCapExceeded(uint256 requested, uint256 cap);

    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert InvalidAddress(address(0));
        _owner = initialOwner;
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert Unauthorized(msg.sender);
        _;
    }

    modifier nonReentrant() {
        if (_status == 2) revert ReentrantCall();
        _status = 2;
        _;
        _status = 1;
    }

    modifier whenNotPaused() {
        if (isPaused) revert Paused();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidAddress(newOwner);
        _owner = newOwner;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 value) external whenNotPaused nonReentrant override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) external whenNotPaused override returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external whenNotPaused nonReentrant override returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance < value) revert InsufficientAllowance(currentAllowance, value);
        _approve(from, msg.sender, currentAllowance - value);
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0) || to == address(0)) revert InvalidAddress(from);
        uint256 fromBalance = _balances[from];
        if (fromBalance < value) revert InsufficientBalance(fromBalance, value);
        assembly {
            mstore(0, from)
            mstore(32, _balances.slot)
            let slot := keccak256(0, 64)
            sstore(slot, sub(sload(slot), value))
            mstore(0, to)
            slot := keccak256(0, 64)
            sstore(slot, add(sload(slot), value))
        }
        emit Transfer(from, to, value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        if (owner == address(0) || spender == address(0)) revert InvalidAddress(owner);
        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _mint(address to, uint256 value) internal {
        if (to == address(0)) revert InvalidAddress(to);
        if (_totalSupply + value > TOTAL_SUPPLY_CAP) revert SupplyCapExceeded(_totalSupply + value, TOTAL_SUPPLY_CAP);
        unchecked {
            _totalSupply += value;
            _balances[to] += value;
        }
        emit Transfer(address(0), to, value);
        emit Mint(to, value);
    }

    function mint(address to, uint256 value) external onlyOwner whenNotPaused {
        _mint(to, value);
    }

    function _burn(address from, uint256 value) internal {
        if (from == address(0)) revert InvalidAddress(from);
        uint256 balance = _balances[from];
        if (balance < value) revert InsufficientBalance(balance, value);
        _balances[from] = balance - value;
        _totalSupply -= value;
        emit Transfer(from, address(0), value);
        emit Burn(from, value);
    }

    function burn(uint256 value) external whenNotPaused nonReentrant {
        _burn(msg.sender, value);
    }

    // IERC20Metadata compliance
    function name() public pure returns (string memory) {
        return NAME;
    }

    function symbol() public pure returns (string memory) {
        return SYMBOL;
    }

    function decimals() public pure returns (uint8) {
        return DECIMALS;
    }
}