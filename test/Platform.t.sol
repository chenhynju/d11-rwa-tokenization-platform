// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../src/Platform.sol";
import "../src/CorporateActions.sol";
import "../src/InstitutionalApproval.sol";

interface Vm {
    function prank(address) external;
    function warp(uint256) external;
    function expectRevert() external;
    function expectRevert(bytes4 selector) external;
}

contract PlatformTest {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    IdentityRegistry ids;
    ComplianceEngine rules;
    PermissionedToken token;
    IssuanceManager manager;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        ids = new IdentityRegistry();
        rules = new ComplianceEngine(ids, 1000);
        token = new PermissionedToken(rules, 10000);
        manager = new IssuanceManager(token);
        token.bindManager(address(manager));
        rules.setCountry(840, true);
        ids.attest(alice, 840, uint64(block.timestamp + 100), bytes32(uint256(1)));
        ids.attest(bob, 840, uint64(block.timestamp + 100), bytes32(uint256(2)));
        manager.issue(bytes32(uint256(1)), alice, 500);
    }

    function testTransfer() public {
        vm.prank(alice);
        token.transfer(bob, 200);
        require(token.balanceOf(bob) == 200 && token.balanceOf(alice) == 300 && token.totalSupply() == 500);
    }

    function testUnknownRejected() public {
        vm.expectRevert();
        vm.prank(alice);
        token.transfer(address(99), 1);
    }

    function testRevocation() public {
        ids.revoke(bob);
        vm.expectRevert();
        vm.prank(alice);
        token.transfer(bob, 1);
    }

    function testExpiredSender() public {
        vm.warp(block.timestamp + 101);
        vm.expectRevert();
        vm.prank(alice);
        token.transfer(bob, 1);
    }

    function testCountryRejected() public {
        rules.setCountry(840, false);
        vm.expectRevert();
        vm.prank(alice);
        token.transfer(bob, 1);
    }

    function testHoldingLimit() public {
        rules.setLimit(100);
        vm.expectRevert();
        vm.prank(alice);
        token.transfer(bob, 101);
    }

    function testFreeze() public {
        manager.freeze(alice, true);
        vm.expectRevert();
        vm.prank(alice);
        token.transfer(bob, 1);
    }

    function testFrozenReceiver() public {
        manager.freeze(bob, true);
        vm.expectRevert();
        vm.prank(alice);
        token.transfer(bob, 1);
    }

    function testPause() public {
        manager.pause(true);
        vm.expectRevert();
        vm.prank(alice);
        token.transfer(bob, 1);
    }

    function testAllowance() public {
        vm.prank(alice);
        token.approve(bob, 20);
        vm.prank(bob);
        token.transferFrom(alice, bob, 20);
        require(token.allowance(alice, bob) == 0 && token.balanceOf(bob) == 20);
    }

    function testRejectedTransferKeepsAllowance() public {
        vm.prank(alice);
        token.approve(bob, 20);
        manager.freeze(bob, true);
        vm.expectRevert();
        vm.prank(bob);
        token.transferFrom(alice, bob, 20);
        require(token.allowance(alice, bob) == 20);
    }

    function testUnauthorizedMint() public {
        vm.expectRevert();
        token.mint(bob, 1);
    }

    function testUnauthorizedIssue() public {
        vm.expectRevert();
        vm.prank(bob);
        manager.issue(bytes32(uint256(2)), bob, 1);
    }

    function testDuplicateIssue() public {
        vm.expectRevert();
        manager.issue(bytes32(uint256(1)), bob, 1);
    }

    function testRedeem() public {
        vm.prank(alice);
        manager.redeem(bytes32(uint256(2)), 100);
        require(token.totalSupply() == 400 && token.balanceOf(alice) == 400);
    }

    function testCannotRedeemAnotherHolder() public {
        vm.expectRevert();
        vm.prank(bob);
        manager.redeem(bytes32(uint256(2)), 100);
    }

    function testSelfTransfer() public {
        vm.prank(alice);
        token.transfer(alice, 500);
        require(token.balanceOf(alice) == 500);
    }

    function testFuzzConservation(uint96 raw) public {
        uint256 n = uint256(raw) % 501;
        vm.prank(alice);
        token.transfer(bob, n);
        require(token.balanceOf(alice) + token.balanceOf(bob) == token.totalSupply());
    }

    function testAssetRegistration() public {
        AssetRegistry assets = new AssetRegistry();
        assets.register(bytes32(uint256(1)), bytes32(uint256(2)), uint64(block.timestamp + 100), 10000, address(token));
        vm.expectRevert();
        assets.register(bytes32(uint256(1)), bytes32(uint256(2)), uint64(block.timestamp + 100), 10000, address(token));
    }

    function testDistribution() public {
        CorporateActions actions = new CorporateActions();
        bytes32 id = bytes32(uint256(1));
        actions.create(id, bytes32(uint256(2)), 100);
        actions.allocate(id, alice, 100);
        actions.close(id);
        vm.prank(alice);
        actions.acknowledge(id);
        require(actions.acknowledged(id, alice));
        vm.expectRevert();
        vm.prank(alice);
        actions.acknowledge(id);
    }

    function testCapExhaustion() public {
        rules.setLimit(10000);
        manager.issue(bytes32(uint256(2)), bob, 9500);
        vm.expectRevert();
        manager.issue(bytes32(uint256(3)), bob, 1);
    }

    function testZeroIssue() public {
        vm.expectRevert();
        manager.issue(bytes32(uint256(2)), bob, 0);
    }

    function testUnauthorizedIdentity() public {
        vm.expectRevert();
        vm.prank(bob);
        ids.revoke(alice);
    }

    function testInvalidIdentity() public {
        vm.expectRevert();
        ids.attest(address(0), 840, uint64(block.timestamp + 100), bytes32(uint256(1)));
    }

    function testExpiredClaim() public {
        vm.expectRevert();
        ids.attest(bob, 840, uint64(block.timestamp), bytes32(uint256(1)));
    }

    function testZeroLimit() public {
        vm.expectRevert();
        rules.setLimit(0);
    }

    function testManagerCannotRebind() public {
        vm.expectRevert();
        token.bindManager(address(manager));
    }

    function testInsufficientBalance() public {
        vm.expectRevert();
        vm.prank(alice);
        token.transfer(bob, 501);
    }

    function testZeroRecipient() public {
        vm.expectRevert();
        vm.prank(alice);
        token.transfer(address(0), 1);
    }

    function testInsufficientAllowance() public {
        vm.expectRevert();
        vm.prank(bob);
        token.transferFrom(alice, bob, 1);
    }

    function testInfiniteAllowance() public {
        vm.prank(alice);
        token.approve(bob, type(uint256).max);
        vm.prank(bob);
        token.transferFrom(alice, bob, 1);
        require(token.allowance(alice, bob) == type(uint256).max);
    }

    function testPausedIssue() public {
        manager.pause(true);
        vm.expectRevert();
        manager.issue(bytes32(uint256(2)), bob, 1);
    }

    function testFrozenIssue() public {
        manager.freeze(bob, true);
        vm.expectRevert();
        manager.issue(bytes32(uint256(2)), bob, 1);
    }

    function testUnauthorizedFreezePauseBurn() public {
        vm.expectRevert();
        token.setFrozen(alice, true);
        vm.expectRevert();
        token.setPaused(true);
        vm.expectRevert();
        token.burn(alice, 1);
    }

    function testDistributionBranches() public {
        CorporateActions a = new CorporateActions();
        bytes32 id = bytes32(uint256(1));
        vm.expectRevert();
        a.create(0, 0, 0);
        a.create(id, bytes32(uint256(2)), 100);
        vm.expectRevert();
        a.create(id, bytes32(uint256(2)), 100);
        vm.expectRevert();
        a.close(id);
        vm.expectRevert();
        a.allocate(id, alice, 101);
        a.allocate(id, alice, 60);
        vm.expectRevert();
        a.allocate(id, alice, 1);
        vm.expectRevert();
        vm.prank(alice);
        a.acknowledge(id);
        a.allocate(id, bob, 40);
        a.close(id);
        vm.expectRevert();
        a.close(id);
        vm.expectRevert();
        a.allocate(id, address(99), 1);
        vm.expectRevert();
        vm.prank(address(99));
        a.acknowledge(id);
    }

    function testConstructorBoundaries() public {
        vm.expectRevert();
        new ComplianceEngine(ids, 0);
        vm.expectRevert();
        new PermissionedToken(rules, 0);
    }

    function testUnauthorizedPause() public {
        vm.expectRevert();
        vm.prank(bob);
        manager.pause(true);
    }

    function testRedemptionCannotConsumeIssuanceReference() public {
        vm.prank(alice);
        manager.redeem(bytes32(uint256(7)), 1);
        manager.issue(bytes32(uint256(7)), bob, 10);
        require(token.balanceOf(bob) == 10);
        vm.expectRevert();
        vm.prank(alice);
        manager.redeem(bytes32(uint256(7)), 1);
        vm.prank(bob);
        manager.redeem(bytes32(uint256(7)), 1);
    }

    function testIndependentApproval() public {
        PermissionedToken t = new PermissionedToken(rules, 10000);
        InstitutionalApproval a = new InstitutionalApproval(t, bob);
        t.bindManager(address(a.manager()));
        bytes32 ref = bytes32(uint256(1));
        a.propose(ref, alice, 10);
        vm.expectRevert();
        a.execute(ref);
        vm.prank(bob);
        a.execute(ref);
        require(t.balanceOf(alice) == 10);
        vm.expectRevert();
        vm.prank(bob);
        a.execute(ref);
        IssuanceManager guarded = a.manager();
        vm.expectRevert();
        guarded.issue(bytes32(uint256(2)), alice, 1);
    }

    function testCancelledApproval() public {
        InstitutionalApproval a = new InstitutionalApproval(token, bob);
        a.propose(bytes32(uint256(1)), alice, 10);
        a.cancel(bytes32(uint256(1)));
        vm.expectRevert();
        vm.prank(bob);
        a.execute(bytes32(uint256(1)));
    }

    function testSameApproverRejected() public {
        vm.expectRevert();
        new InstitutionalApproval(token, address(this));
    }

    function testApprovalAdminAndBoundaries() public {
        PermissionedToken t = new PermissionedToken(rules, 10000);
        InstitutionalApproval a = new InstitutionalApproval(t, bob);
        t.bindManager(address(a.manager()));
        a.freeze(alice, true);
        require(t.frozen(alice));
        a.pause(true);
        require(t.paused());
        a.pause(false);
        a.freeze(alice, false);
        vm.expectRevert();
        a.propose(0, alice, 1);
        vm.expectRevert();
        a.cancel(bytes32(uint256(99)));
        vm.expectRevert();
        vm.prank(bob);
        a.execute(bytes32(uint256(99)));
        bytes32 ref = bytes32(uint256(5));
        a.propose(ref, alice, 10);
        vm.expectRevert();
        a.propose(ref, alice, 10);
        a.cancel(ref);
        vm.expectRevert();
        a.cancel(ref);
        vm.expectRevert();
        vm.prank(alice);
        a.freeze(alice, true);
        vm.expectRevert();
        new InstitutionalApproval(t, address(0));
    }

    function testRedemptionReservationsRemainBackedAcrossSettlement() public {
        bytes32 first = keccak256("first");
        bytes32 second = keccak256("second");
        bytes32 payment = keccak256("payment");
        vm.prank(alice);
        manager.requestRedemption(first, 300);
        vm.prank(alice);
        manager.requestRedemption(second, 150);
        vm.expectRevert();
        vm.prank(alice);
        token.transfer(bob, 51);
        vm.prank(alice);
        token.transfer(bob, 50);
        manager.approveRedemption(alice, first);
        vm.expectRevert(IssuanceManager.InvalidRedemption.selector);
        vm.prank(alice);
        manager.cancelRedemption(first);
        manager.confirmRedemption(alice, first, payment, first);
        require(token.reserved(alice) == 150 && token.balanceOf(alice) == 150 && token.totalSupply() == 200);
        manager.approveRedemption(alice, second);
        vm.expectRevert(IssuanceManager.InvalidRedemption.selector);
        manager.confirmRedemption(alice, second, payment, second);
        manager.rejectUnpaidRedemption(alice, second);
        require(token.reserved(alice) == 0 && token.balanceOf(alice) == 150 && token.totalSupply() == 200);
    }

    function testHolderCanCancelBeforePaymentApproval() public {
        bytes32 ref = keccak256("cancel");
        vm.prank(alice);
        manager.requestRedemption(ref, 500);
        vm.prank(alice);
        manager.cancelRedemption(ref);
        require(token.reserved(alice) == 0 && token.balanceOf(alice) == 500);
        vm.expectRevert(IssuanceManager.InvalidRedemption.selector);
        manager.approveRedemption(alice, ref);
    }

    function testRedemptionRequestBoundaries() public {
        bytes32 ref = keccak256("dup");
        vm.prank(alice);
        manager.requestRedemption(ref, 100);
        vm.expectRevert(IssuanceManager.InvalidRedemption.selector);
        vm.prank(alice);
        manager.requestRedemption(ref, 1);
        vm.expectRevert(IssuanceManager.InvalidRedemption.selector);
        vm.prank(alice);
        manager.requestRedemption(bytes32(0), 1);
        vm.expectRevert();
        vm.prank(alice);
        manager.requestRedemption(keccak256("over"), 450);
        vm.prank(alice);
        manager.requestRedemption(keccak256("max"), 400);
        require(token.reserved(alice) == 500);
    }

    function testInstitutionalRedemptionProxies() public {
        PermissionedToken t = new PermissionedToken(rules, 10000);
        InstitutionalApproval a = new InstitutionalApproval(t, bob);
        IssuanceManager m = a.manager();
        t.bindManager(address(m));
        bytes32 issueRef = bytes32(uint256(9));
        a.propose(issueRef, alice, 200);
        vm.prank(bob);
        a.execute(issueRef);
        bytes32 rref = bytes32(uint256(10));
        vm.prank(alice);
        m.requestRedemption(rref, 120);
        vm.expectRevert();
        vm.prank(bob);
        a.approveRedemption(alice, rref);
        a.approveRedemption(alice, rref);
        vm.expectRevert();
        a.confirmRedemption(alice, rref, bytes32(uint256(1)), bytes32(uint256(2)));
        vm.prank(bob);
        a.confirmRedemption(alice, rref, bytes32(uint256(1)), bytes32(uint256(2)));
        require(t.totalSupply() == 80 && t.balanceOf(alice) == 80 && t.reserved(alice) == 0);
        bytes32 second = bytes32(uint256(11));
        vm.prank(alice);
        m.requestRedemption(second, 30);
        a.approveRedemption(alice, second);
        vm.expectRevert();
        a.rejectUnpaidRedemption(alice, second);
        vm.prank(bob);
        a.rejectUnpaidRedemption(alice, second);
        require(t.reserved(alice) == 0 && t.balanceOf(alice) == 80 && t.totalSupply() == 80);
    }
}
