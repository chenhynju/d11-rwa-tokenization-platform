// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../src/Platform.sol";
import "../src/CorporateActions.sol";

import "../src/InstitutionalApproval.sol";

interface ScriptVm {
    function envAddress(string calldata key) external returns (address);
    function startBroadcast() external;
    function stopBroadcast() external;
}

contract DeploySepolia {
    ScriptVm constant vm = ScriptVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() public virtual {
        require(block.chainid == 11155111, "Ethereum Sepolia only");
        _deploy();
    }

    function _deploy() internal {
        address reviewer = vm.envAddress("INDEPENDENT_REVIEWER");
        vm.startBroadcast();
        IdentityRegistry ids = new IdentityRegistry();
        ComplianceEngine rules = new ComplianceEngine(ids, 1000);
        PermissionedToken token = new PermissionedToken(rules, 10000);
        InstitutionalApproval approval = new InstitutionalApproval(token, reviewer);
        IssuanceManager manager = approval.manager();
        token.bindManager(address(manager));
        rules.setCountry(840, true);
        AssetRegistry assets = new AssetRegistry();
        assets.register(
            keccak256("SIM-BOND-001"),
            keccak256("simulation-only-no-legal-rights"),
            uint64(block.timestamp + 365 days),
            10000,
            address(token)
        );
        new CorporateActions();
        vm.stopBroadcast();
    }
}
