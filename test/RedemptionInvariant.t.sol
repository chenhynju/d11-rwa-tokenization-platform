// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../src/Platform.sol";

interface RedemptionVm {
    function prank(address) external;
}

/// @notice Drives random multi-party redemption lifecycles against the real contracts.
contract RedemptionHandler {
    RedemptionVm constant vm = RedemptionVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    PermissionedToken public immutable token;
    IssuanceManager public immutable manager;
    address[] public holders;
    bytes32[] public refs;
    mapping(bytes32 => address) public refHolder;
    mapping(bytes32 => uint256) public refUnits;
    uint256 public settled;
    uint256 public voluntaryBurned;
    uint256 public issued;
    uint256 private sequence;

    constructor(address[] memory parties, uint256 each) {
        IdentityRegistry ids = new IdentityRegistry();
        ComplianceEngine rules = new ComplianceEngine(ids, 1000);
        PermissionedToken t = new PermissionedToken(rules, 10000);
        IssuanceManager m = new IssuanceManager(t);
        t.bindManager(address(m));
        rules.setCountry(840, true);
        token = t;
        manager = m;
        holders = parties;
        for (uint256 i; i < parties.length; ++i) {
            ids.attest(parties[i], 840, type(uint64).max, bytes32(uint256(i + 1)));
            bytes32 ref = keccak256(abi.encode("issue", i));
            m.issue(ref, parties[i], each);
            issued += each;
        }
    }

    function _nextRef(address holder) private returns (bytes32 ref) {
        ref = keccak256(abi.encode("req", holder, sequence++));
        refs.push(ref);
        refHolder[ref] = holder;
    }

    function request(uint8 pick, uint16 raw) external {
        address holder = holders[pick % holders.length];
        uint256 units = uint256(raw) % (token.balanceOf(holder) + 1);
        bytes32 ref = _nextRef(holder);
        vm.prank(holder);
        try manager.requestRedemption(ref, units) {
            refUnits[ref] = units;
        } catch {
            refs.pop();
            delete refHolder[ref];
        }
    }

    function cancel(uint8 pickRef) external {
        if (refs.length == 0) return;
        bytes32 ref = refs[pickRef % refs.length];
        vm.prank(refHolder[ref]);
        try manager.cancelRedemption(ref) {} catch {}
    }

    function approve(uint8 pickRef) external {
        if (refs.length == 0) return;
        try manager.approveRedemption(refHolder[refs[pickRef % refs.length]], refs[pickRef % refs.length]) {} catch {}
    }

    function confirm(uint8 pickRef, uint8 receiptSalt) external {
        if (refs.length == 0) return;
        bytes32 ref = refs[pickRef % refs.length];
        bytes32 payment = keccak256(abi.encode("pay", sequence++));
        bytes32 receipt = keccak256(abi.encode("rcpt", sequence++, receiptSalt));
        try manager.confirmRedemption(refHolder[ref], ref, payment, receipt) {
            settled += refUnits[ref];
        } catch {}
    }

    function reject(uint8 pickRef) external {
        if (refs.length == 0) return;
        bytes32 ref = refs[pickRef % refs.length];
        try manager.rejectUnpaidRedemption(refHolder[ref], ref) {} catch {}
    }

    function move(uint8 from, uint8 to, uint16 raw) external {
        address sender = holders[from % holders.length];
        address recipient = holders[to % holders.length];
        uint256 amount = uint256(raw) % (token.balanceOf(sender) + 1);
        vm.prank(sender);
        try token.transfer(recipient, amount) {} catch {}
    }

    function burn(uint8 pick, uint16 raw) external {
        address holder = holders[pick % holders.length];
        uint256 amount = uint256(raw) % (token.balanceOf(holder) + 1);
        bytes32 ref = keccak256(abi.encode("burn", sequence++));
        vm.prank(holder);
        try manager.redeem(ref, amount) {
            voluntaryBurned += amount;
        } catch {}
    }

    function refsCount() external view returns (uint256) {
        return refs.length;
    }
}

/// @notice Multi-party redemption accounting invariants (P1 and P2 of the review).
contract RedemptionInvariant {
    RedemptionHandler handler;
    PermissionedToken token;
    address[] targets;
    address[] parties;

    function setUp() public {
        parties = new address[](3);
        parties[0] = address(0xA11CE);
        parties[1] = address(0xB0B);
        parties[2] = address(0xCAFE);
        handler = new RedemptionHandler(parties, 300);
        token = handler.token();
        targets.push(address(handler));
    }

    function targetContracts() external view returns (address[] memory) {
        return targets;
    }

    /// P1: reservations never exceed balances, per holder and in aggregate.
    function invariantReservationsBacked() public view {
        uint256 sumReserved;
        uint256 sumBalances;
        for (uint256 i; i < parties.length; ++i) {
            uint256 reserved = token.reserved(parties[i]);
            uint256 balance = token.balanceOf(parties[i]);
            require(reserved <= balance);
            sumReserved += reserved;
            sumBalances += balance;
        }
        require(sumReserved <= token.totalSupply());
        require(sumBalances == token.totalSupply());
    }

    /// P2: supply only ever decreases by exactly settled or voluntarily burned units.
    function invariantSupplyAccounting() public view {
        require(token.totalSupply() == handler.issued() - handler.settled() - handler.voluntaryBurned());
    }
}
