// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/UniswapV2.sol";

contract DeployExchange is Script {
    function run() external {
        // 读取私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // 传入你之前部署的 TestToken 地址
        address token = 0x4e6037B6613dbA5aBA761e3B14c7954f114947B7;
        Exchange exchange = new Exchange(token);

        console2.log("Exchange deployed at:", address(exchange));

        vm.stopBroadcast();
    }
}