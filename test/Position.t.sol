// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Position} from "../src/Position.sol";
import {MockAUSD} from "../src/mocks/MockAUSD.sol";
import {MockKARI} from "../src/mocks/MockKARI.sol";
import {ISwapRouter} from "../src/interfaces/ISwapRouter.sol";


contract PositionTest is Test{
    Position public position;
    MockAUSD public ausd;
    MockKARI public kari;

    ISwapRouter public constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    address router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    address alice = makeAddr("alice");

    // address alice = makeAddr("alice");
    // address bob = makeAddr("bob");
    // address brown = makeAddr("brown");

    function setUp() public {
        vm.createSelectFork("https://arb-mainnet.g.alchemy.com/v2/IpWFQVx6ZTeZyG85llRd7h6qRRNMqErS", 306368675);

        // deploy Contracts
        ausd = new MockAUSD();
        kari = new MockKARI();
        position = new Position(address(kari), address(ausd));

        // set balance
        //deal(usdc, address(vault), 2000e6);
        deal(address(ausd), address(this),10_000e6);
        deal(address(ausd), alice, 1000e6);
        
    }

    function test_initPoolAndPosition() external{
        //mint token Kari
        //position.mint(1000e18);
        kari.mint(address(position), 1000e18);
        IERC20(ausd).approve(address(position), 1003792990);

        //init pool
        position.initPoolAndPosition(79224306130848112672356);
        console.log("anchorId", position.anchorTokenId());
        console.log("floorId", position.floorTokenId());
        console.log("discoveryId", position.discoveryTokenId());

        //position.move();
        console.log("floorId", position.floorTokenId());
        console.log("anchorId", position.anchorTokenId());

        console.log("ausd balance", IERC20(ausd).balanceOf(address(position)));
        console.log("kari balance", IERC20(kari).balanceOf(address(position)));
    }

    function test_move() external{
        //init pool dulu
        kari.mint(address(position), 1000e18);
        kari.mint(address(this), 1000e18);
        IERC20(ausd).approve(address(position), 1003792990);
        position.initPoolAndPosition(79224306130848112672356);

        //expect revert karena harga masih sama
        // vm.expectRevert(Position.InvalidRequirement.selector);
        // position.move();

        position.getCurrentTick();
        console.log("current tick b4", position.currentTick());
        console.log("price differences b4", position.priceDifferences());

        //swap
        uint256 ausdBalance = IERC20(ausd).balanceOf(address(this));
        console.log("ausd balance b4", ausdBalance);
        uint256 amount = 111e6;
        
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(ausd),
                tokenOut: address(kari),
                fee: 3000, // 0.3
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        vm.startPrank(alice);
        IERC20(ausd).approve(router, amount); // approve kepada Uniswap
        swapRouter.exactInputSingle(params);
        vm.stopPrank();
        uint256 kariBalance = IERC20(kari).balanceOf(alice);
        ausdBalance = IERC20(ausd).balanceOf(address(this));
        console.log("ausd balance", ausdBalance);
        console.log("kari balance", kariBalance);

        // //move
        // position.getCurrentTick();
        // console.log("current tick", position.currentTick());
        // console.log("price differences", position.priceDifferences());
        // position.move();
        //-276240
    }

    function test_sweep() external {
         //init pool dulu
        kari.mint(address(position), 1000e18);
        kari.mint(address(this), 1000e18);
        IERC20(ausd).approve(address(position), 1003792990);
        position.initPoolAndPosition(79224306130848112672356);

        position.getCurrentTick();
        console.log("current tick b4", position.currentTick());
        console.log("price differences b4", position.priceDifferences());

        uint256 ausdBalance = IERC20(ausd).balanceOf(address(this));
        console.log("ausd balance b4", ausdBalance);
        uint256 amount = 111e6;
        
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(ausd),
                tokenOut: address(kari),
                fee: 3000, // 0.3
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        vm.startPrank(alice);
        IERC20(ausd).approve(router, amount); // approve kepada Uniswap
        swapRouter.exactInputSingle(params);
        vm.stopPrank();
        uint256 kariBalance = IERC20(kari).balanceOf(alice);
        ausdBalance = IERC20(ausd).balanceOf(address(this));
        console.log("ausd balance", ausdBalance);
        console.log("kari balance", kariBalance);

        position.getCurrentTick();
        console.log("current tick", position.currentTick());

        position.sweep(240);
    }

}