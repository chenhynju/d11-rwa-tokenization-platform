// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../src/InstitutionalApproval.sol";

contract ApprovalSymbolic {
    InstitutionalApproval approval;
    PermissionedToken token;

    function setUp() public {
        IdentityRegistry identities = new IdentityRegistry();
        ComplianceEngine rules = new ComplianceEngine(identities, 1000);
        token = new PermissionedToken(rules, 10000);
        approval = new InstitutionalApproval(token, address(2));
        token.bindManager(address(approval.manager()));
        identities.attest(address(3), 840, type(uint64).max, bytes32(uint256(1)));
        rules.setCountry(840, true);
    }

    function check_IssuerCannotExecute(bytes32 ref, uint256 units) public {
        if (ref == 0 || units == 0 || units > 1000) return;
        approval.propose(ref, address(3), units);
        (bool success,) = address(approval).call(abi.encodeCall(approval.execute, (ref)));
        assert(!success);
        assert(token.totalSupply() == 0);
    }
}
