// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Controlled {
    address public immutable owner;
    error Unauthorized();

    constructor() {
        owner = msg.sender;
    }
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }
}

contract IdentityRegistry is Controlled {
    struct Identity {
        uint16 country;
        uint64 expires;
        bytes32 evidenceHash;
    }
    mapping(address => Identity) public identities;
    event IdentityUpdated(address indexed wallet, uint16 country, uint64 expires, bytes32 evidenceHash);

    function attest(address wallet, uint16 country, uint64 expires, bytes32 evidenceHash) external onlyOwner {
        require(wallet != address(0) && country != 0 && expires > block.timestamp && evidenceHash != 0, "invalid claim");
        identities[wallet] = Identity(country, expires, evidenceHash);
        emit IdentityUpdated(wallet, country, expires, evidenceHash);
    }

    function revoke(address wallet) external onlyOwner {
        delete identities[wallet];
        emit IdentityUpdated(wallet, 0, 0, 0);
    }

    function verified(address wallet) public view returns (bool) {
        return identities[wallet].expires > block.timestamp;
    }

    function countryOf(address wallet) external view returns (uint16) {
        return identities[wallet].country;
    }
}

contract ComplianceEngine is Controlled {
    IdentityRegistry public immutable identities;
    mapping(uint16 => bool) public allowedCountry;
    uint256 public maxHolding;
    event RuleUpdated(uint16 country, bool allowed, uint256 maxHolding);

    constructor(IdentityRegistry registry, uint256 limit) {
        require(limit > 0);
        identities = registry;
        maxHolding = limit;
    }

    function setCountry(uint16 country, bool allowed) external onlyOwner {
        allowedCountry[country] = allowed;
        emit RuleUpdated(country, allowed, maxHolding);
    }

    function setLimit(uint256 limit) external onlyOwner {
        require(limit > 0);
        maxHolding = limit;
        emit RuleUpdated(0, false, limit);
    }

    function eligible(address wallet) public view returns (bool) {
        return identities.verified(wallet) && allowedCountry[identities.countryOf(wallet)];
    }

    function canReceive(address wallet, uint256 resultingBalance) external view returns (bool) {
        return eligible(wallet) && resultingBalance <= maxHolding;
    }
}

contract AssetRegistry is Controlled {
    struct Asset {
        bytes32 documentsHash;
        uint64 maturity;
        uint256 issuanceCap;
        address token;
    }
    mapping(bytes32 => Asset) public assets;
    event AssetRegistered(
        bytes32 indexed id, address indexed token, bytes32 documentsHash, uint64 maturity, uint256 cap
    );

    function register(bytes32 id, bytes32 documentsHash, uint64 maturity, uint256 cap, address token)
        external
        onlyOwner
    {
        require(
            id != 0 && documentsHash != 0 && maturity > block.timestamp && cap > 0 && token.code.length > 0
                && assets[id].token == address(0),
            "invalid asset"
        );
        assets[id] = Asset(documentsHash, maturity, cap, token);
        emit AssetRegistered(id, token, documentsHash, maturity, cap);
    }
}

contract PermissionedToken is Controlled {
    string public constant name = "Simulated Bond Units";
    string public constant symbol = "SBOND";
    uint8 public constant decimals = 0;
    uint256 public totalSupply;
    uint256 public immutable cap;
    ComplianceEngine public immutable compliance;
    address public manager;
    bool public paused;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public frozen;
    mapping(address => uint256) public reserved;
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed holder, address indexed spender, uint256 amount);
    event Frozen(address indexed wallet, bool status);
    event PauseChanged(bool status);
    event ManagerBound(address indexed manager);
    event Reserved(address indexed holder, uint256 units);
    event Released(address indexed holder, uint256 units);

    constructor(ComplianceEngine engine, uint256 supplyCap) {
        require(supplyCap > 0);
        compliance = engine;
        cap = supplyCap;
    }
    modifier onlyManager() {
        require(msg.sender == manager, "manager only");
        _;
    }

    function bindManager(address target) external onlyOwner {
        require(manager == address(0) && target.code.length > 0);
        manager = target;
        emit ManagerBound(target);
    }

    function setFrozen(address wallet, bool status) external onlyManager {
        frozen[wallet] = status;
        emit Frozen(wallet, status);
    }

    function setPaused(bool status) external onlyManager {
        paused = status;
        emit PauseChanged(status);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function checkTransfer(address from, address to, uint256 amount) public view returns (bool) {
        if (
            paused || frozen[from] || frozen[to] || to == address(0) || balanceOf[from] - reserved[from] < amount
                || !compliance.eligible(from)
        ) return false;
        return compliance.canReceive(to, balanceOf[to] + (from == to ? 0 : amount));
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 permitted = allowance[from][msg.sender];
        require(permitted >= amount, "allowance");
        if (permitted != type(uint256).max) allowance[from][msg.sender] = permitted - amount;
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(checkTransfer(from, to, amount), "restricted transfer");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function mint(address to, uint256 amount) external onlyManager {
        require(
            !paused && !frozen[to] && to != address(0) && amount > 0 && amount <= cap - totalSupply
                && compliance.canReceive(to, balanceOf[to] + amount),
            "restricted issuance"
        );
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    /// @notice Reserve units without changing ownership or circulating supply.
    function reserve(address holder, uint256 units) external onlyManager {
        require(!paused && !frozen[holder] && compliance.eligible(holder), "restricted reservation");
        require(units > 0 && units <= balanceOf[holder] - reserved[holder], "invalid reservation");
        reserved[holder] += units;
        emit Reserved(holder, units);
    }

    function release(address holder, uint256 units) external onlyManager {
        reserved[holder] -= units;
        emit Released(holder, units);
    }

    function burn(address from, uint256 amount) external onlyManager {
        require(amount > 0 && balanceOf[from] - reserved[from] >= amount, "invalid burn");
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }
}

contract IssuanceManager is Controlled {
    PermissionedToken public immutable token;
    mapping(bytes32 => bool) public processed;
    mapping(address => mapping(bytes32 => bool)) public redeemed;
    event Issued(bytes32 indexed referenceId, address indexed investor, uint256 amount);
    event Redeemed(bytes32 indexed referenceId, address indexed investor, uint256 amount);

    enum RedemptionStatus {
        Missing,
        Pending,
        Cancelled,
        Settled,
        Approved
    }

    struct Redemption {
        uint256 units;
        RedemptionStatus status;
        bytes32 receipt;
    }
    mapping(address => mapping(bytes32 => Redemption)) public redemptions;
    mapping(bytes32 => bool) public usedReceipts;
    mapping(bytes32 => bool) public usedPayments;
    event RedemptionApproved(address indexed holder, bytes32 indexed ref);
    error InvalidRedemption();
    event RedemptionRequested(address indexed holder, bytes32 indexed ref, uint256 units);
    event RedemptionCancelled(address indexed holder, bytes32 indexed ref);
    event RedemptionSettled(
        address indexed holder, bytes32 indexed ref, bytes32 indexed receipt, bytes32 payment, uint256 units
    );

    constructor(PermissionedToken target) {
        token = target;
    }

    function issue(bytes32 ref, address investor, uint256 amount) external onlyOwner {
        require(ref != 0 && !processed[ref], "duplicate reference");
        processed[ref] = true;
        token.mint(investor, amount);
        emit Issued(ref, investor, amount);
    }

    /// @notice Cancels the caller's units; does not attest to an offchain payment.
    function redeem(bytes32 ref, uint256 amount) external {
        require(ref != 0 && !redeemed[msg.sender][ref], "duplicate reference");
        redeemed[msg.sender][ref] = true;
        token.burn(msg.sender, amount);
        emit Redeemed(ref, msg.sender, amount);
    }

    /// @notice Request synthetic cash settlement and reserve the holder's units.
    function requestRedemption(bytes32 ref, uint256 units) external {
        Redemption storage request = redemptions[msg.sender][ref];
        if (ref == 0 || request.status != RedemptionStatus.Missing) revert InvalidRedemption();
        request.units = units;
        request.status = RedemptionStatus.Pending;
        token.reserve(msg.sender, units);
        emit RedemptionRequested(msg.sender, ref, units);
    }

    function cancelRedemption(bytes32 ref) external {
        Redemption storage request = redemptions[msg.sender][ref];
        if (request.status != RedemptionStatus.Pending) revert InvalidRedemption();
        request.status = RedemptionStatus.Cancelled;
        token.release(msg.sender, request.units);
        emit RedemptionCancelled(msg.sender, ref);
    }

    function approveRedemption(address holder, bytes32 ref) external onlyOwner {
        Redemption storage request = redemptions[holder][ref];
        if (request.status != RedemptionStatus.Pending) revert InvalidRedemption();
        request.status = RedemptionStatus.Approved;
        emit RedemptionApproved(holder, ref);
    }

    /// @notice Release an approved request after the independent reviewer verifies no payment occurred.
    function rejectUnpaidRedemption(address holder, bytes32 ref) external onlyOwner {
        Redemption storage request = redemptions[holder][ref];
        if (request.status != RedemptionStatus.Approved) revert InvalidRedemption();
        request.status = RedemptionStatus.Cancelled;
        token.release(holder, request.units);
        emit RedemptionCancelled(holder, ref);
    }

    /// @notice Confirm a unique offchain receipt digest and burn the reserved units atomically.
    function confirmRedemption(address holder, bytes32 ref, bytes32 payment, bytes32 receipt) external onlyOwner {
        Redemption storage request = redemptions[holder][ref];
        if (
            request.status != RedemptionStatus.Approved || payment == 0 || usedPayments[payment] || receipt == 0
                || usedReceipts[receipt]
        ) {
            revert InvalidRedemption();
        }
        usedPayments[payment] = true;
        usedReceipts[receipt] = true;
        request.status = RedemptionStatus.Settled;
        request.receipt = receipt;
        token.release(holder, request.units);
        token.burn(holder, request.units);
        emit RedemptionSettled(holder, ref, receipt, payment, request.units);
    }

    function freeze(address wallet, bool status) external onlyOwner {
        token.setFrozen(wallet, status);
    }

    function pause(bool status) external onlyOwner {
        token.setPaused(status);
    }
}
