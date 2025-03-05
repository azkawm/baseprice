// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {BasePrice} from "../src/BasePrice.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Vault} from "../src/Vault.sol" ;

contract VaultTest is Test{
    address public weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;

    BasePrice public basePrice;
    Vault public vault;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address brown = makeAddr("brown");

    function setUp() public {
        vm.createSelectFork("https://arb-mainnet.g.alchemy.com/v2/IpWFQVx6ZTeZyG85llRd7h6qRRNMqErS", 306368675);

        // deploy BasePrice
        basePrice = new BasePrice(-207240, -207180, -191150, -191140);

        //deploy vault
        vault = new Vault(address(basePrice));

        // set balance USDC dan WETH
        deal(usdc, address(vault), 2000e6);
        deal(weth, address(vault), 200e18);
        deal(weth, alice, 1e18);
        deal(weth,bob,100_000e18);
        deal(usdc,brown,1000_000_000e6);
    }

    function test_floor() public{
        vm.startPrank(address(vault));
        IERC20(usdc).approve(address(basePrice), 1000e6);

        // skenario 1: mint pertama
        vault.mintFloor(1000e6);
        // floorTokendId tidak boleh 0
        assertNotEq(basePrice.floorTokenId(), 0);
        console.log("floorTokenId", basePrice.floorTokenId());

        // skenario 2: mint kedua misal dapat 1000e6 dari treasury
        uint256 floorTokenIdBefore = basePrice.floorTokenId();
        IERC20(usdc).approve(address(basePrice), 1000e6);
        basePrice.mintFloor(1000e6);
        console.log("floor reserve", vault.reserveLiquidity());

        // floorTokendId tidak boleh sama dengan sebelumnya
        assertNotEq(basePrice.floorTokenId(), floorTokenIdBefore);
        console.log("floorTokenId", basePrice.floorTokenId());

        vm.stopPrank();

        //skenario 3: price ke hit
        vm.prank(bob);
        IERC20(weth).approve(address(basePrice), 100_000e18);
        vm.prank(address(basePrice));
        IERC20(weth).transferFrom(bob, address(basePrice), 100_000e18);

        vm.prank(bob);
        basePrice.swap(100_000e18, weth, usdc);

        vm.prank(alice);
        IERC20(weth).approve(address(basePrice), 1e18);
        vm.prank(address(basePrice));
        IERC20(weth).transferFrom(alice, address(basePrice), 1e18);

        vm.prank(alice);
        basePrice.swap(1e18, weth, usdc);
        uint256 aliceUsdcBalance = IERC20(usdc).balanceOf(alice);
        basePrice.withdrawPosition();
        uint256 basePriceWethBalance = IERC20(weth).balanceOf(address(basePrice));
        console.log("USDC balance Alice", aliceUsdcBalance);
        console.log("WETH balance Floor Post:", basePriceWethBalance);
    }

    function test_Anchor() public{ //console.log util, console.log total borrowed
        vm.startPrank(address(vault));
        IERC20(usdc).approve(address(basePrice), 2000e6);

        // skenario 1: mint floor dulu
        vault.mintFloor(1000e6);
        vault.deployAnchor(100e6,10);
        // floorTokendId tidak boleh 0
        assertNotEq(basePrice.floorTokenId(), 0);
        console.log("floorTokenId", basePrice.floorTokenId());
        console.log("floor reserve", vault.reserveLiquidity());
        console.log("total borrowed", vault.totalBorrowed());

        console.log("utilization rate b4", vault.utilizationRate());
        vault._utilizationRate();
        console.log("utilization rate after", vault.utilizationRate());
    }
}