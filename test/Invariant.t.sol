// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../src/Platform.sol";

interface InvariantVm {
    function prank(address) external;
}

contract TransferHandler {
    InvariantVm constant vm = InvariantVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    PermissionedToken public token;
    address public constant ALICE = address(0xA11CE);
    address public constant BOB = address(0xB0B);

    constructor(PermissionedToken t) {
        token = t;
    }

    function move(uint256 raw, bool reverse) external {
        address from = reverse ? BOB : ALICE;
        address to = reverse ? ALICE : BOB;
        uint256 amount = raw % (token.balanceOf(from) + 1);
        vm.prank(from);
        token.transfer(to, amount);
    }
}

contract ConservationInvariant {
    PermissionedToken token;
    TransferHandler handler;
    address[] targets;

    function setUp() public {
        IdentityRegistry ids = new IdentityRegistry();
        ComplianceEngine rules = new ComplianceEngine(ids, 1000);
        token = new PermissionedToken(rules, 10000);
        IssuanceManager manager = new IssuanceManager(token);
        token.bindManager(address(manager));
        rules.setCountry(840, true);
        ids.attest(address(0xA11CE), 840, type(uint64).max, bytes32(uint256(1)));
        ids.attest(address(0xB0B), 840, type(uint64).max, bytes32(uint256(2)));
        manager.issue(bytes32(uint256(1)), address(0xA11CE), 500);
        handler = new TransferHandler(token);
        targets.push(address(handler));
    }

    function targetContracts() external view returns (address[] memory) {
        return targets;
    }

    function invariantSupplyConservation() public view {
        require(token.totalSupply() == 500);
        require(token.balanceOf(address(0xA11CE)) + token.balanceOf(address(0xB0B)) == 500);
        require(token.balanceOf(address(0)) == 0);
    }
}
