// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../src/Platform.sol";

contract LifecycleFuzz {
    PermissionedToken token;
    IssuanceManager manager;
    uint256 issued;
    uint256 cancelled;
    uint256 sequence;
    constructor() {
        IdentityRegistry identities = new IdentityRegistry();
        ComplianceEngine rules = new ComplianceEngine(identities, 1000);
        token = new PermissionedToken(rules, 1000);
        manager = new IssuanceManager(token);
        token.bindManager(address(manager));
        rules.setCountry(840, true);
        identities.attest(address(this), 840, type(uint64).max, bytes32(uint256(1)));
    }
    function issue(uint16 raw) external {
        uint256 amount = uint256(raw) % 1001;
        manager.issue(bytes32(++sequence), address(this), amount);
        issued += amount;
    }
    function redeem(uint16 raw) external {
        uint256 amount = uint256(raw) % 1001;
        manager.redeem(bytes32(++sequence), amount);
        cancelled += amount;
    }
    function echidna_supply_accounting() external view returns (bool) {
        return issued >= cancelled && issued - cancelled == token.totalSupply()
            && token.totalSupply() == token.balanceOf(address(this)) && token.totalSupply() <= 1000;
    }
}
