// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DeploySepolia} from "./DeploySepolia.s.sol";

/// @notice Deploy the synthetic RWA demo on Base Sepolia only.
/// @dev Uses the same role-separated contracts as the Ethereum Sepolia script.
contract DeployBaseSepolia is DeploySepolia {
    function run() public override {
        require(block.chainid == 84532, "Base Sepolia only");
        _deploy();
    }
}
