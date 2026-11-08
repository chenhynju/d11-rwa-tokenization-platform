// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "./Platform.sol";

/// @notice Simulated offchain payment ledger. No currency is held or paid.
contract CorporateActions is Controlled {
    struct Distribution {
        bytes32 reconciliationHash;
        uint256 budget;
        uint256 allocated;
        bool closed;
    }
    mapping(bytes32 => Distribution) public distributions;
    mapping(bytes32 => mapping(address => uint256)) public entitlement;
    mapping(bytes32 => mapping(address => bool)) public acknowledged;
    event DistributionCreated(bytes32 indexed id, bytes32 reconciliationHash, uint256 budget);
    event Allocated(bytes32 indexed id, address indexed investor, uint256 amount);
    event Acknowledged(bytes32 indexed id, address indexed investor, uint256 amount);
    event Closed(bytes32 indexed id);

    function create(bytes32 id, bytes32 reconciliationHash, uint256 budget) external onlyOwner {
        require(id != 0 && reconciliationHash != 0 && budget > 0 && distributions[id].budget == 0);
        distributions[id] = Distribution(reconciliationHash, budget, 0, false);
        emit DistributionCreated(id, reconciliationHash, budget);
    }

    function allocate(bytes32 id, address investor, uint256 amount) external onlyOwner {
        Distribution storage d = distributions[id];
        require(
            d.budget > 0 && !d.closed && investor != address(0) && amount > 0 && entitlement[id][investor] == 0
                && amount <= d.budget - d.allocated
        );
        d.allocated += amount;
        entitlement[id][investor] = amount;
        emit Allocated(id, investor, amount);
    }

    function close(bytes32 id) external onlyOwner {
        Distribution storage d = distributions[id];
        require(d.budget > 0 && !d.closed && d.allocated == d.budget);
        d.closed = true;
        emit Closed(id);
    }

    function acknowledge(bytes32 id) external {
        require(distributions[id].closed && entitlement[id][msg.sender] > 0 && !acknowledged[id][msg.sender]);
        acknowledged[id][msg.sender] = true;
        emit Acknowledged(id, msg.sender, entitlement[id][msg.sender]);
    }
}
