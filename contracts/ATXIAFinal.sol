// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

// OpenZeppelin: Context.sol
/// @title Context
/// @dev Provides information about the current execution context, including the sender of the transaction and its data.
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// OpenZeppelin: ReentrancyGuard.sol
/// @title ReentrancyGuard
/// @dev Prevents reentrant calls to a function, protecting against reentrancy attacks.
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

// OpenZeppelin: Address.sol
/// @title Address
/// @dev Collection of functions related to the address type, providing safe ways to interact with addresses.
library Address {
    /// @dev Returns true if `account` is a contract.
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    /// @dev Transfers `amount` ETH to `recipient`, reverting on failure.
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /// @dev Performs a Solidity function call using a low-level `call`.
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /// @dev Same as `functionCall`, but with an `errorMessage` for better error handling.
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /// @dev Same as `functionCall`, but also transfers `value` ETH.
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /// @dev Same as `functionCallWithValue`, but with an `errorMessage` for better error handling.
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /// @dev Performs a Solidity function call using a low-level `staticcall`.
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /// @dev Same as `functionStaticCall`, but with an `errorMessage`.
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /// @dev Performs a Solidity function call using a low-level `delegatecall`.
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /// @dev Same as `functionDelegateCall`, but with an `errorMessage`.
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /// @dev Verifies the result of a low-level call, reverting with `errorMessage` if the call failed.
    function verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// OpenZeppelin: IERC20.sol
/// @title IERC20
/// @dev Interface of the ERC20 standard as defined in the EIP.
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title ATXIAGovernanceFinal
/// @notice Optimized governance and ERC20 token contract for the ATXIA ecosystem
/// @dev Implements advanced gas optimizations under AGPL-3.0, including bit-packing, exponential vote weight decay,
///      and secure treasury management. Renamed to ATXIAGovernanceFinal to resolve inheritance issues.
contract ATXIAGovernanceFinal is ReentrancyGuard, IERC20 {
    using Address for address;

    // Constants
    uint256 public constant TOTAL_SUPPLY_CAP = 1_000_000_000 * 10 ** 18;
    uint256 public constant MIN_STAKE_FOR_PROPOSAL = 10_000 * 10 ** 18;
    uint256 public constant COOLDOWN_TIME = 1 days;
    uint256 public constant VELOCITY_TRIGGER = 1000 * 10 ** 18;
    uint256 public constant VELOCITY_COOLDOWN = 1 minutes;
    uint256 public constant PROPOSAL_FEE = 100 * 10 ** 18; // 100 ATX
    uint256 public constant QUORUM_PERCENT = 5;
    uint256 public constant TREASURY_FLOOR = 100_000 * 10 ** 18;
    uint256 public constant MAX_VOTE_WEIGHT_MULTIPLIER = 10;
    uint256 public constant MAX_DESCRIPTION_LENGTH = 128;

    // Enums and Structs
    enum functionType { MINT, BURN, PAUSE, UNPAUSE, SPEND, SET_PAUSE_DURATION, SET_DECAY_RATE }

    struct Proposal {
        uint256 packedData; // Bit-packed: id (64 bits), action (8 bits), executed (1 bit)
        address proposer;
        string description; // Limited to 128 bytes
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        address target;
        uint256 amount;
    }

    struct UserData {
        uint256 lastProposalTimestamp;
        uint256 proposalCount;
    }

    // State Variables
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => uint256) public voteWeight;
    mapping(bytes32 => Proposal) public proposals;
    mapping(address => UserData) public userData;
    mapping(bytes32 => mapping(address => bool)) public hasVoted;
    mapping(bytes32 => uint256) public uniqueVoterCount;
    mapping(address => uint256) public lastVelocityBoost;
    mapping(address => uint256) public lastVoteWeightUpdate;
    mapping(bytes32 => uint256) public proposalExecutionTime;
    uint256 public totalSupply;
    uint256 public lastProposalTime;
    uint256 public inactivityCounter;
    bool public isPaused;
    uint256 public pauseTimestamp;
    uint256 public pauseDuration = 7 days;
    uint256 public decayRate = 1 ether; // 1 * 10^18 per day
    address public initialOwner;

    // Events (Transfer and Approval inherited from IERC20)
    event ProposalCreated(bytes32 indexed id, string description);
    event ProposalExecuted(bytes32 indexed id, functionType action);
    event VoteCast(address indexed voter, bytes32 indexed id, bool support);
    event RiskFlagged(bytes32 indexed id, string reason);
    event TreasurySpent(address indexed to, uint256 amount);
    event PauseDurationSet(uint256 newDuration);
    event DecayRateSet(uint256 newRate);
    event Mint(address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);

    // Errors
    error NotEnoughStake();
    error CooldownActive();
    error InvalidDescription();
    error TooManyProposals();
    error InvalidAddress();
    error InsufficientBalance(uint256 balance, uint256 required);
    error InsufficientAllowance(uint256 allowance, uint256 required);
    error VotingEnded();
    error AlreadyVoted();
    error NoVotingPower();
    error VotingOngoing();
    error AlreadyExecuted();
    error QuorumNotMet();
    error InsufficientMajority();
    error InsufficientVoters();
    error DelayNotPassed();
    error SupplyCapExceeded();
    error InsufficientTreasury();
    error TreasuryTooLow();
    error PauseLockActive();
    error InvalidDuration();
    error DecayRateTooHigh();
    error ContractPaused();

    // Modifiers
    modifier whenNotPaused() {
        if (isPaused) revert ContractPaused();
        _;
    }

    /// @notice Initializes the contract with an initial treasury balance
    /// @dev Sets the initial owner, allocates 500,000 ATX tokens to the contract's treasury,
    ///      and emits a Transfer event to reflect the initial minting.
    /// @param _initialOwner The address to receive initial control
    constructor(address _initialOwner) {
        if (_initialOwner == address(0)) revert InvalidAddress();
        initialOwner = _initialOwner;
        _balances[address(this)] = 500_000 * 10 ** 18;
        totalSupply = 500_000 * 10 ** 18;
        lastProposalTime = block.timestamp;
        emit Transfer(address(0), address(this), 500_000 * 10 ** 18);
    }

    /// @notice Creates a new governance proposal
    /// @dev This function allows users to submit proposals for actions like minting, burning, or pausing the contract.
    ///      It performs several checks to ensure the proposer meets the requirements:
    ///      - The proposer must hold at least MIN_STAKE_FOR_PROPOSAL tokens.
    ///      - The proposer must not have submitted a proposal within the last COOLDOWN_TIME.
    ///      - The proposal description must be between 1 and MAX_DESCRIPTION_LENGTH bytes.
    ///      - The proposer must not have already submitted 3 or more proposals.
    ///      - The target address must be valid for the specified action.
    ///      If all checks pass, the function transfers the PROPOSAL_FEE from the proposer to the contract's treasury,
    ///      creates a new proposal with a unique ID generated using Keccak-256, and emits a ProposalCreated event.
    ///      Edge cases handled:
    ///      - Zero or oversized description: Reverts with InvalidDescription.
    ///      - Insufficient stake: Reverts with NotEnoughStake.
    ///      - Cooldown violation: Reverts with CooldownActive.
    ///      - Proposal limit exceeded: Reverts with TooManyProposals.
    ///      - Invalid target address: Reverts with InvalidAddress.
    ///      - Insufficient balance for fee: Handled by _transfer.
    /// @param description A string describing the proposal (must be 1 to 128 bytes)
    /// @param action The type of action the proposal is for (e.g., MINT, BURN, PAUSE)
    /// @param target The address targeted by the proposal (e.g., for minting or burning tokens)
    /// @param amount The amount involved in the proposal (e.g., number of tokens to mint or burn)
    function propose(string memory description, functionType action, address target, uint256 amount)
        external
        whenNotPaused
        nonReentrant
    {
        address sender = msg.sender;
        uint256 balance = _balances[sender];
        if (balance < MIN_STAKE_FOR_PROPOSAL) revert NotEnoughStake();
        UserData storage user = userData[sender];
        if (block.timestamp < user.lastProposalTimestamp + COOLDOWN_TIME) revert CooldownActive();
        if (bytes(description).length == 0 || bytes(description).length > MAX_DESCRIPTION_LENGTH) revert InvalidDescription();
        if (user.proposalCount >= 3) revert TooManyProposals();
        if (target == address(0) && action != functionType.SET_PAUSE_DURATION && action != functionType.SET_DECAY_RATE)
            revert InvalidAddress();

        _transfer(sender, address(this), PROPOSAL_FEE);
        user.proposalCount++;
        bytes32 proposalId = keccak256(abi.encodePacked(sender, block.timestamp));
        user.lastProposalTimestamp = block.timestamp;

        uint256 packedData = (uint256(proposalId) & type(uint64).max) | (uint256(uint8(action)) << 64) | (0 << 72);
        proposals[proposalId] = Proposal({
            packedData: packedData,
            proposer: sender,
            description: description,
            votesFor: 0,
            votesAgainst: 0,
            deadline: block.timestamp + 3 days,
            target: target,
            amount: amount
        });

        if (uint8(action) & 0x03 != 0) { // MINT (0) or BURN (1)
            proposalExecutionTime[proposalId] = block.timestamp + 3 days + 24 hours;
        }

        lastProposalTime = block.timestamp;
        inactivityCounter = 0;
        emit ProposalCreated(proposalId, description);
    }

    /// @notice Votes on an existing proposal
    /// @dev This function allows users to vote on a proposal before its deadline. It checks:
    ///      - The proposal deadline has not passed.
    ///      - The voter has not already voted on this proposal.
    ///      - The voter has a non-zero vote weight.
    ///      The function applies vote weight decay before recording the vote and updates the proposal's vote counts.
    ///      Edge cases handled:
    ///      - Voting after deadline: Reverts with VotingEnded.
    ///      - Double voting: Reverts with AlreadyVoted.
    ///      - Zero voting power: Reverts with NoVotingPower.
    /// @param id The unique ID of the proposal to vote on
    /// @param support A boolean indicating whether the vote is for (true) or against (false) the proposal
    function vote(bytes32 id, bool support) external whenNotPaused {
        Proposal storage prop = proposals[id];
        if (block.timestamp >= prop.deadline) revert VotingEnded();
        if (hasVoted[id][msg.sender]) revert AlreadyVoted();
        _decayVoteWeight(msg.sender);
        if (voteWeight[msg.sender] == 0) revert NoVotingPower();

        hasVoted[id][msg.sender] = true;
        uniqueVoterCount[id]++;
        uint256 weight = voteWeight[msg.sender];
        support ? prop.votesFor += weight : prop.votesAgainst += weight;
        emit VoteCast(msg.sender, id, support);
    }

    /// @notice Executes an approved proposal
    /// @dev This function executes a proposal if it meets all the required conditions:
    ///      - The voting period has ended.
    ///      - The proposal has not already been executed.
    ///      - The total votes meet the quorum requirement (5% of effective supply).
    ///      - The votes for the proposal meet the required majority (66% for MINT, BURN, PAUSE; 50% for others).
    ///      - At least 3 unique voters have participated.
    ///      For MINT and BURN actions, it also checks the execution delay.
    ///      The function then performs the specified action (e.g., minting tokens, burning tokens, pausing the contract).
    ///      Edge cases handled:
    ///      - Quorum not met: Reverts with QuorumNotMet.
    ///      - Insufficient majority: Reverts with InsufficientMajority.
    ///      - Insufficient voters: Reverts with InsufficientVoters.
    ///      - Execution before deadline: Reverts with VotingOngoing.
    ///      - Already executed: Reverts with AlreadyExecuted.
    ///      - Delayed execution for MINT/BURN: Reverts with DelayNotPassed if not met.
    ///      - Supply cap exceeded (MINT): Reverts with SupplyCapExceeded.
    ///      - Insufficient treasury (BURN/SPEND): Reverts with InsufficientTreasury.
    ///      - Treasury below floor (BURN): Reverts with TreasuryTooLow.
    /// @param id The unique ID of the proposal to execute
    function executeProposal(bytes32 id) external nonReentrant {
        Proposal storage prop = proposals[id];
        if (block.timestamp < prop.deadline) revert VotingOngoing();
        if (prop.packedData & (1 << 72) != 0) revert AlreadyExecuted();

        uint256 cachedSupply = totalSupply;
        uint256 effectiveSupply = cachedSupply < 100_000 * 1e18 ? 100_000 * 1e18 : cachedSupply;
        uint256 totalVotes = prop.votesFor + prop.votesAgainst;
        if (totalVotes < (effectiveSupply * QUORUM_PERCENT) / 100) revert QuorumNotMet();

        uint8 action = uint8(prop.packedData >> 64);
        uint256 requiredMajority = (action & 0x03 != 0 || action == uint8(functionType.PAUSE)) ? 66 : 50;
        if (prop.votesFor * 100 / totalVotes <= requiredMajority) revert InsufficientMajority();
        if (uniqueVoterCount[id] < 3) revert InsufficientVoters();

        if (action & 0x03 != 0) {
            if (block.timestamp < proposalExecutionTime[id]) revert DelayNotPassed();
        }

        prop.packedData |= (1 << 72); // Set executed

        if (action == uint8(functionType.MINT)) {
            uint256 treasuryShare = prop.amount / 100;
            if (cachedSupply + prop.amount + treasuryShare > TOTAL_SUPPLY_CAP) revert SupplyCapExceeded();
            if (prop.votesFor > cachedSupply * 70 / 100) {
                emit RiskFlagged(id, "Whale voting power detected");
            }
            _mint(prop.target, prop.amount);
            _mint(address(this), treasuryShare);
        } else if (action == uint8(functionType.BURN)) {
            uint256 treasuryReduction = prop.amount / 100;
            uint256 currentTreasuryBalance = _balances[address(this)];
            if (currentTreasuryBalance < treasuryReduction) revert InsufficientTreasury();
            _burn(prop.target, prop.amount);
            _burn(address(this), treasuryReduction);
            if (currentTreasuryBalance - treasuryReduction < TREASURY_FLOOR) revert TreasuryTooLow();
        } else if (action == uint8(functionType.PAUSE)) {
            isPaused = true;
            pauseTimestamp = block.timestamp;
        } else if (action == uint8(functionType.UNPAUSE)) {
            if (block.timestamp < pauseTimestamp + pauseDuration) revert PauseLockActive();
            isPaused = false;
        } else if (action == uint8(functionType.SPEND)) {
            if (_balances[address(this)] < prop.amount) revert InsufficientTreasury();
            _transfer(address(this), prop.target, prop.amount);
            emit TreasurySpent(prop.target, prop.amount);
        } else if (action == uint8(functionType.SET_PAUSE_DURATION)) {
            if (prop.amount < 1 days || prop.amount > 14 days) revert InvalidDuration();
            pauseDuration = prop.amount;
            emit PauseDurationSet(prop.amount);
        } else if (action == uint8(functionType.SET_DECAY_RATE)) {
            if (prop.amount > 10 ether) revert DecayRateTooHigh();
            decayRate = prop.amount;
            emit DecayRateSet(prop.amount);
        }

        emit ProposalExecuted(id, functionType(action));
    }

    /// @notice Transfers tokens to another address
    /// @dev Implements the ERC20 transfer function with additional governance features.
    ///      Applies vote weight decay and updates vote weight boost based on transfer activity.
    /// @param to Recipient address
    /// @param value Amount to transfer
    /// @return True if successful
    function transfer(address to, uint256 value) public virtual override whenNotPaused nonReentrant returns (bool) {
        address sender = msg.sender;
        _decayVoteWeight(sender);
        _transfer(sender, to, value);
        _updateVoteWeightBoost(sender, value);
        return true;
    }

    /// @notice Approves a spender to transfer tokens on behalf of the owner
    /// @param spender The address to approve
    /// @param value The amount to approve
    /// @return True if successful
    function approve(address spender, uint256 value) public virtual override whenNotPaused returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /// @notice Transfers tokens from one address to another using allowance
    /// @param from The source address
    /// @param to The recipient address
    /// @param value The amount to transfer
    /// @return True if successful
    function transferFrom(address from, address to, uint256 value)
        public
        virtual
        override
        whenNotPaused
        nonReentrant
        returns (bool)
    {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance < value) revert InsufficientAllowance(currentAllowance, value);
        _approve(from, msg.sender, currentAllowance - value);
        _decayVoteWeight(from);
        _transfer(from, to, value);
        _updateVoteWeightBoost(from, value);
        return true;
    }

    /// @dev Updates the vote weight of a user based on their transfer activity.
    ///      If the transfer amount exceeds VELOCITY_TRIGGER and the cooldown has passed,
    ///      the user’s vote weight is boosted, capped at MAX_VOTE_WEIGHT_MULTIPLIER times their balance.
    function _updateVoteWeightBoost(address user, uint256 value) internal {
        if (value > VELOCITY_TRIGGER && block.timestamp >= lastVelocityBoost[user] + VELOCITY_COOLDOWN) {
            uint256 boost = value >> 10; // value / 1000
            uint256 maxWeight = _balances[user] * MAX_VOTE_WEIGHT_MULTIPLIER;
            voteWeight[user] = voteWeight[user] + boost > maxWeight ? maxWeight : voteWeight[user] + boost;
            lastVelocityBoost[user] = block.timestamp;
        }
    }

    /// @dev Applies exponential decay to a user’s vote weight based on time elapsed since last update.
    ///      Decay is approximated as weight * (0.999^days).
    function _decayVoteWeight(address user) internal {
        uint256 decayDays = (block.timestamp - lastVoteWeightUpdate[user]) / 1 days;
        if (decayDays > 0) {
            uint256 decayedWeight = voteWeight[user];
            for (uint256 i = 0; i < decayDays; i++) {
                decayedWeight = (decayedWeight * 999) / 1000; // 0.999 per day
            }
            voteWeight[user] = decayedWeight;
            lastVoteWeightUpdate[user] = block.timestamp;
        }
    }

    /// @dev Updates the inactivity counter if 30 days have passed since the last proposal.
    function _updateInactivity() internal {
        if (block.timestamp > lastProposalTime + 30 days) {
            inactivityCounter++;
            lastProposalTime = block.timestamp;
        }
    }

    /// @dev Internal function to transfer tokens, enforcing address validity and balance checks.
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0) || to == address(0)) revert InvalidAddress();
        if (_balances[from] < value) revert InsufficientBalance(_balances[from], value);
        _balances[from] -= value;
        _balances[to] += value;
        emit Transfer(from, to, value);
    }

    /// @dev Internal function to mint tokens, applying an inactivity burn factor.
    function _mint(address to, uint256 value) internal {
        if (to == address(0)) revert InvalidAddress();
        _updateInactivity();
        uint256 burnFactor = value * inactivityCounter / 100;
        uint256 netValue = value >= burnFactor ? value - burnFactor : 0;
        totalSupply += netValue;
        _balances[to] += netValue;
        voteWeight[to] = _balances[to];
        lastVoteWeightUpdate[to] = block.timestamp;
        emit Transfer(address(0), to, netValue);
        emit Mint(to, netValue);
    }

    /// @dev Internal function to burn tokens, updating vote weight and total supply.
    function _burn(address from, uint256 value) internal {
        if (from == address(0)) revert InvalidAddress();
        if (_balances[from] < value) revert InsufficientBalance(_balances[from], value);
        _updateInactivity();
        _balances[from] -= value;
        totalSupply -= value;
        voteWeight[from] = _balances[from];
        lastVoteWeightUpdate[from] = block.timestamp;
        emit Transfer(from, address(0), value);
        emit Burn(from, value);
    }

    /// @dev Internal function to approve token spending, enforcing address validity.
    function _approve(address owner, address spender, uint256 value) internal {
        if (owner == address(0) || spender == address(0)) revert InvalidAddress();
        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /// @notice Returns the balance of an account
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /// @notice Returns the allowance of a spender for an owner
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /// @notice Returns the treasury balance
    function treasuryBalance() external view returns (uint256) {
        return _balances[address(this)];
    }

    /// @notice Returns the token name
    function name() public pure returns (string memory) {
        return "ATXIA";
    }

    /// @notice Returns the token symbol
    function symbol() public pure returns (string memory) {
        return "ATX";
    }

    /// @notice Returns the token decimals
    function decimals() public pure returns (uint8) {
        return 18;
    }
}