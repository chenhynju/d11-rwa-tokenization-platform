// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "./Platform.sol";

/// @notice Two distinct addresses approve simulated issuance; no cash settlement is implied.
contract InstitutionalApproval is Controlled {
    struct Request {
        address investor;
        uint256 amount;
        bool executed;
        bool cancelled;
    }
    address public immutable reviewer;
    IssuanceManager public immutable manager;
    mapping(bytes32 => Request) public requests;
    error InvalidRequest();
    event Proposed(bytes32 indexed referenceId, address indexed investor, uint256 amount);
    event Executed(bytes32 indexed referenceId, address indexed reviewer);
    event Cancelled(bytes32 indexed referenceId);

    constructor(PermissionedToken token, address independentReviewer) {
        if (independentReviewer == address(0) || independentReviewer == msg.sender) revert InvalidRequest();
        reviewer = independentReviewer;
        manager = new IssuanceManager(token);
    }

    function propose(bytes32 ref, address investor, uint256 amount) external onlyOwner {
        if (ref == 0 || investor == address(0) || amount == 0 || requests[ref].investor != address(0)) {
            revert InvalidRequest();
        }
        requests[ref] = Request(investor, amount, false, false);
        emit Proposed(ref, investor, amount);
    }

    function cancel(bytes32 ref) external onlyOwner {
        Request storage r = requests[ref];
        if (r.investor == address(0) || r.executed || r.cancelled) revert InvalidRequest();
        r.cancelled = true;
        emit Cancelled(ref);
    }

    function execute(bytes32 ref) external {
        if (msg.sender != reviewer) revert Unauthorized();
        Request storage r = requests[ref];
        if (r.investor == address(0) || r.executed || r.cancelled) revert InvalidRequest();
        r.executed = true;
        manager.issue(ref, r.investor, r.amount);
        emit Executed(ref, msg.sender);
    }

    function approveRedemption(address holder, bytes32 ref) external onlyOwner {
        manager.approveRedemption(holder, ref);
    }

    function rejectUnpaidRedemption(address holder, bytes32 ref) external {
        if (msg.sender != reviewer) revert Unauthorized();
        manager.rejectUnpaidRedemption(holder, ref);
    }

    function confirmRedemption(address holder, bytes32 ref, bytes32 payment, bytes32 receipt) external {
        if (msg.sender != reviewer) revert Unauthorized();
        manager.confirmRedemption(holder, ref, payment, receipt);
    }

    function freeze(address wallet, bool status) external onlyOwner {
        manager.freeze(wallet, status);
    }

    function pause(bool status) external onlyOwner {
        manager.pause(status);
    }
}
