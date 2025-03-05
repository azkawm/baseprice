// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MockAUSD} from "../src/mocks/MockAUSD.sol";

contract MockAUSDScript is Script {
    MockAUSD public token;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("https://arb-mainnet.g.alchemy.com/v2/IpWFQVx6ZTeZyG85llRd7h6qRRNMqErS"));
    }

    function run() public {
        uint256 privateKey = vm.envUint("DEPLOYER_WALLET_PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        token = new MockAUSD();
        vm.stopBroadcast();
    }
}
