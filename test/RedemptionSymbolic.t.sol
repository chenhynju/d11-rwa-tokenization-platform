// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../src/Platform.sol";

interface SymVm {
    function prank(address) external;
}

/// @notice External non-owner used to model unauthorized callers under Halmos.
contract Stranger {
    function tryConfirm(IssuanceManager m, address holder, bytes32 ref, bytes32 payment, bytes32 receipt)
        external
        returns (bool ok)
    {
        (ok,) = address(m).call(abi.encodeCall(IssuanceManager.confirmRedemption, (holder, ref, payment, receipt)));
    }
}

/// @notice Bounded symbolic checks of the redemption state machine (review properties P2 and P3).
/// Constraints: amounts in (0, 400] for ALICE / (0, 100] for BOB; digests are symbolic 256-bit.
/// Not covered symbolically: pause/freeze interaction and identity expiry (unit-tested concretely).
contract RedemptionSymbolic {
    SymVm constant vm = SymVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    PermissionedToken token;
    IssuanceManager manager;
    address constant ALICE = address(3);
    address constant BOB = address(4);

    function setUp() public {
        IdentityRegistry identities = new IdentityRegistry();
        ComplianceEngine rules = new ComplianceEngine(identities, 1000);
        token = new PermissionedToken(rules, 10000);
        manager = new IssuanceManager(token);
        token.bindManager(address(manager));
        rules.setCountry(840, true);
        identities.attest(ALICE, 840, type(uint64).max, bytes32(uint256(1)));
        identities.attest(BOB, 840, type(uint64).max, bytes32(uint256(2)));
        manager.issue(bytes32(uint256(1)), ALICE, 400);
        manager.issue(bytes32(uint256(2)), BOB, 100);
    }

    function _request(address holder, bytes32 ref, uint256 units) internal {
        vm.prank(holder);
        manager.requestRedemption(ref, units);
    }

    /// P2: a successful settlement burns exactly the request's units and clears its reservation.
    function check_SettlementAccounting(bytes32 ref, uint256 units, bytes32 payment, bytes32 receipt) public {
        if (ref == 0 || units == 0 || units > 400 || payment == 0 || receipt == 0) return;
        _request(ALICE, ref, units);
        manager.approveRedemption(ALICE, ref);
        manager.confirmRedemption(ALICE, ref, payment, receipt);
        assert(token.totalSupply() == 500 - units);
        assert(token.balanceOf(ALICE) == 400 - units);
        assert(token.reserved(ALICE) == 0);
        assert(token.balanceOf(BOB) == 100);
        (uint256 u, IssuanceManager.RedemptionStatus s, bytes32 r) = manager.redemptions(ALICE, ref);
        assert(u == units && s == IssuanceManager.RedemptionStatus.Settled && r == receipt);
    }

    /// P2: repeating a settlement (identical or with a fresh receipt) fails and changes nothing.
    function check_SettlementReplay(bytes32 ref, uint256 units, bytes32 payment, bytes32 receipt, bytes32 other)
        public
    {
        if (ref == 0 || units == 0 || units > 400 || payment == 0 || receipt == 0 || other == 0 || other == receipt) {
            return;
        }
        _request(ALICE, ref, units);
        manager.approveRedemption(ALICE, ref);
        manager.confirmRedemption(ALICE, ref, payment, receipt);
        (bool sameAgain,) =
            address(manager).call(abi.encodeCall(IssuanceManager.confirmRedemption, (ALICE, ref, payment, receipt)));
        assert(!sameAgain);
        (bool samePayment,) =
            address(manager).call(abi.encodeCall(IssuanceManager.confirmRedemption, (ALICE, ref, payment, other)));
        assert(!samePayment);
        assert(token.totalSupply() == 500 - units);
        assert(token.balanceOf(ALICE) == 400 - units);
        assert(token.reserved(ALICE) == 0);
    }

    /// P3: a payment identifier consumed by one holder cannot fund another holder's request,
    /// even with a different receipt digest, reference and holder.
    function check_PaymentReplayAcrossHolders(
        bytes32 refA,
        bytes32 refB,
        uint256 units,
        bytes32 payment,
        bytes32 receiptA,
        bytes32 receiptB
    ) public {
        if (
            refA == 0 || refB == 0 || refA == refB || units == 0 || units > 100 || payment == 0 || receiptA == 0
                || receiptB == 0 || receiptA == receiptB
        ) {
            return;
        }
        _request(ALICE, refA, units);
        manager.approveRedemption(ALICE, refA);
        manager.confirmRedemption(ALICE, refA, payment, receiptA);
        _request(BOB, refB, units);
        manager.approveRedemption(BOB, refB);
        (bool ok,) =
            address(manager).call(abi.encodeCall(IssuanceManager.confirmRedemption, (BOB, refB, payment, receiptB)));
        assert(!ok);
        assert(token.balanceOf(BOB) == 100);
        assert(token.reserved(BOB) == units);
        assert(token.totalSupply() == 500 - units);
    }

    /// P2: an unauthorized settlement attempt fails and leaves reservations and balances untouched.
    function check_UnauthorizedConfirm(bytes32 ref, uint256 units, bytes32 payment, bytes32 receipt) public {
        if (ref == 0 || units == 0 || units > 400 || payment == 0 || receipt == 0) return;
        _request(ALICE, ref, units);
        manager.approveRedemption(ALICE, ref);
        bool ok = new Stranger().tryConfirm(manager, ALICE, ref, payment, receipt);
        assert(!ok);
        assert(token.reserved(ALICE) == units);
        assert(token.balanceOf(ALICE) == 400);
        assert(token.totalSupply() == 500);
    }
}
