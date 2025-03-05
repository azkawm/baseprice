// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {INonfungiblePositionManager} from "./interfaces/INonfungiblePositionManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockKARI} from "./mocks/MockKARI.sol";
import {IUniswapV3Pool} from "./interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "./interfaces/IUniswapV3Factory.sol";
import {console} from "forge-std/Test.sol";

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

// interface IUniswapV3Pool {
//     function createAndInitializePoolIfNecessary(
//         address token0,
//         address token1,
//         uint24 fee,
//         uint160 sqrtPriceX96
//     ) external payable returns (address pool);
// }

interface IMockKari{
    function mint(address to, uint256 amount) external;
}

contract Position {
    ISwapRouter public constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564); 
    IUniswapV3Factory public constant uniswapFactory = IUniswapV3Factory(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    INonfungiblePositionManager public constant nonfungiblePositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    IMockKari public kari;

    uint256 public floorTokenId;
    uint256 public anchorTokenId;
    uint256 public discoveryTokenId;

    int24 public anchorLower;
    int24 public anchorUpper;
    int24 public anchorTickLength = 10;

    int24 public floorLower;
    int24 public floorUpper;

    int24 public discoveryLower;
    int24 public discoveryUpper;
    int24 public discoveryTickLength = 30;

    int24 public currentTick;
    int24 public priceDifferences;

    address public token0;
    address public token1;
    address public poolAddress;

    error InvalidRequirement();

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
        kari = IMockKari(_token1);
    }

    function mint(uint256 amount) external {
        kari.mint(address(this), amount);
    }
       
    function initPoolAndPosition( uint160 sqrtPriceX96) external {
        uint256 amountToken0 = 1003792990;
        IERC20(token1).transferFrom(msg.sender,address(this), amountToken0);
        poolAddress=uniswapFactory.createAndInitializePoolIfNecessary(
            token0,
            token1,
            3000,
            sqrtPriceX96//sqrtPriceX96
        );

        INonfungiblePositionManager.MintParams memory anchorParams = INonfungiblePositionManager.MintParams({
            token0: token0, 
            //KARI
            token1: token1, //AUSD
            fee: 3000, //menentukan harga
            tickLower: -276420, //menentukan harga 
            tickUpper: -276300, //menentukan harga
            amount0Desired: 999999948301786405,
            amount1Desired: 3792990,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        });
        IERC20(token0).approve(address(nonfungiblePositionManager), 999999948301786405);
         IERC20(token1).approve(address(nonfungiblePositionManager), 3792990);
        (uint256 atokenId,,,) = nonfungiblePositionManager.mint(anchorParams);

        anchorTokenId = atokenId;

        INonfungiblePositionManager.MintParams memory floorParams = INonfungiblePositionManager.MintParams({
            token0: token0, //KARI
            token1: token1, //AUSD
            fee: 3000, //menentukan harga
            tickLower: -283260, //menentukan harga 
            tickUpper: -283200, //menentukan harga
            amount0Desired: 0,
            amount1Desired: 1000000000,
            amount0Min: 0,
            amount1Min: 1000000000,
            recipient: address(this),
            deadline: block.timestamp
        });
        IERC20(token1).approve(address(nonfungiblePositionManager), 1000000000);
        (uint256 ftokenId,,,) = nonfungiblePositionManager.mint(floorParams);

        floorTokenId = ftokenId;

        INonfungiblePositionManager.MintParams memory discoveryParams = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: 3000, //menentukan harga
            tickLower: -276240, //menentukan harga
            tickUpper: -274440, //menentukan harga
            amount0Desired: 99999999999999959655,
            amount1Desired: 0,
            amount0Min: 90630502357404639705,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        });
        IERC20(token0).approve(address(nonfungiblePositionManager), 99999999999999959655);
        (uint256 dtokenId,,,) = nonfungiblePositionManager.mint(discoveryParams);

        discoveryTokenId = dtokenId;
  }

  function getCurrentTick() external returns(int24){
    (,int24 _currentTick,,,,,) = IUniswapV3Pool(poolAddress).slot0();
        //(,,,,,int24 lower,int24 upper, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(discoveryTokenId);
        currentTick = _currentTick;
        //priceDifferences = lower;
        return currentTick;

  }

  function sweep(int24 trigerredPrice) external {
    (,int24 _currentTick,,,,,) = IUniswapV3Pool(poolAddress).slot0();
        (,,,,,int24 lower,,,,,,) = nonfungiblePositionManager.positions(discoveryTokenId);
        currentTick = _currentTick;
        int24 trigerredTickSweep = trigerredPrice;
        //(currentTick/60-tickLength)*60
        int24 anchorUpperPrice = ((currentTick/60)-anchorTickLength)*60;
        int24 anchorLowerPrice = ((currentTick/60)+anchorTickLength)*60;
        int24 discoveryLowerPrice = anchorUpperPrice + 60;
        int24 discoveryUpperPrice = 60*discoveryTickLength + discoveryLowerPrice;
        console.log("anchorUpperPrice is", anchorUpperPrice);
        console.log("anchorLowerPrice is", anchorLowerPrice);
        console.log("discoveryLowerPrice is", discoveryLowerPrice);
        console.log("discoveryUpperPrice is", discoveryUpperPrice);
        if(currentTick > lower + trigerredTickSweep) { //-276240 + 240
            // collect discovery dulu
            nonfungiblePositionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: discoveryTokenId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );

            // withdraw semua
            (,,,,,,, uint128 dliquidity,,,,) = nonfungiblePositionManager.positions(discoveryTokenId);

            nonfungiblePositionManager.decreaseLiquidity(
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: discoveryTokenId,
                    liquidity: dliquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                })
            );

            // burn
            // nonfungiblePositionManager.burn(floorTokenId);

            //collect anchor dulu
            nonfungiblePositionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: anchorTokenId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );

            nonfungiblePositionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: anchorTokenId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );

            // withdraw semua
            (,,,,,,, uint128 anchorLiquidity,,,,) = nonfungiblePositionManager.positions(anchorTokenId);

            nonfungiblePositionManager.decreaseLiquidity(
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: anchorTokenId,
                    liquidity: anchorLiquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                })
            );

            // burn
            // nonfungiblePositionManager.burn(floorTokenId);

            nonfungiblePositionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: anchorTokenId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );
        }

        uint256 ausdBalance = IERC20(token1).balanceOf(address(this));
        uint256 ausdAmount = 10*ausdBalance/100;
        //mintFloor belum withdraw Previous TokenId
        INonfungiblePositionManager.MintParams memory floorParams = INonfungiblePositionManager.MintParams({
            token0: token0, //KARI
            token1: token1, //AUSD
            fee: 3000, //menentukan harga
            tickLower: -283260, //menentukan harga 
            tickUpper: -283200, //menentukan harga
            amount0Desired: 0,
            amount1Desired: ausdAmount,
            amount0Min: 0,
            amount1Min: ausdAmount,
            recipient: address(this),
            deadline: block.timestamp
        });
        IERC20(token1).approve(address(nonfungiblePositionManager), ausdAmount);
        (uint256 ftokenId,,,) = nonfungiblePositionManager.mint(floorParams);

        floorTokenId = ftokenId;
        //mint kari

        uint256 kariBalance = IERC20(token0).balanceOf(address(this));
        console.log("kari balance", kariBalance);
        console.log("current tick", currentTick);
        //redeployDiscovery
        //   tickLower: -276420, //menentukan harga 
        //   tickUpper: -276300, //menentukan harga
        INonfungiblePositionManager.MintParams memory discoveryParams = INonfungiblePositionManager.MintParams({
            token0: token0, //KARI
            token1: token1, //AUSD
            fee: 3000, //menentukan harga
            tickLower: -276180+3600, //menentukan harga 
            tickUpper: -274380+3600, //menentukan harga
            amount0Desired: kariBalance,
            amount1Desired: 0,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        });
        console.log("tickLower",-276180);
        console.log("tickUpper",-274380);
        IERC20(token0).approve(address(nonfungiblePositionManager), kariBalance);
        (uint256 dtokenId,,,) = nonfungiblePositionManager.mint(discoveryParams);

        discoveryTokenId = dtokenId;

        
        //menentukan amount?
        // uint256 kariBalance = IERC20(token0).balanceOf(address(this));
        // INonfungiblePositionManager.MintParams memory anchorParams = INonfungiblePositionManager.MintParams({
        //     token0: token0, //KARI
        //     token1: token1, //AUSD
        //     fee: 3000, //menentukan harga
        //     tickLower: anchorLowerPrice, //menentukan harga 
        //     tickUpper: anchorUpperPrice, //menentukan harga
        //     amount0Desired: 0,
        //     amount1Desired: ausdBalance-ausdAmount,
        //     amount0Min: 0,
        //     amount1Min: ausdBalance-ausdAmount,
        //     recipient: address(this),
        //     deadline: block.timestamp
        // });
        // IERC20(token1).approve(address(nonfungiblePositionManager), 1000000000);
        // (uint256 atokenId,,,) = nonfungiblePositionManager.mint(anchorParams);

        // anchorTokenId = atokenId;
  }

//   function move() external{
//         (,int24 _currentTick,,,,,) = IUniswapV3Pool(poolAddress).slot0();
//         (,,,,,int24 lower,int24 upper, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(discoveryTokenId);
//         currentTick = _currentTick;
//         priceDifferences = currentTick - (lower + 60);
//         if(currentTick <= lower + 60){ revert InvalidRequirement();}
//          if (floorTokenId != 0) {
//             // collect dulu
//             nonfungiblePositionManager.collect(
//                 INonfungiblePositionManager.CollectParams({
//                     tokenId: floorTokenId,
//                     recipient: address(this),
//                     amount0Max: type(uint128).max,
//                     amount1Max: type(uint128).max
//                 })
//             );

//             // withdraw semua
//             (,,,,,int24 lower,int24 upper, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(floorTokenId);
//             floorLower = lower;
//             floorUpper = upper;
//             nonfungiblePositionManager.decreaseLiquidity(
//                 INonfungiblePositionManager.DecreaseLiquidityParams({
//                     tokenId: floorTokenId,
//                     liquidity: liquidity,
//                     amount0Min: 0,
//                     amount1Min: 0,
//                     deadline: block.timestamp
//                 })
//             );

//             nonfungiblePositionManager.collect(
//                 INonfungiblePositionManager.CollectParams({
//                     tokenId: floorTokenId,
//                     recipient: address(this),
//                     amount0Max: type(uint128).max,
//                     amount1Max: type(uint128).max
//                 })
//             );
//          }
//         uint256 ausdBalance = IERC20(token1).balanceOf(address(this));
//          INonfungiblePositionManager.MintParams memory floorParams = INonfungiblePositionManager.MintParams({
//             token0: token0, //KARI
//             token1: token1, //AUSD
//             fee: 3000, //menentukan harga
//             tickLower: floorLower + 60, //menentukan harga 
//             tickUpper: floorUpper + 60, //menentukan harga
//             amount0Desired: 0,
//             amount1Desired: ausdBalance,
//             amount0Min: 0,
//             amount1Min: 0,
//             recipient: address(this),
//             deadline: block.timestamp
//         });
//         IERC20(token1).approve(address(nonfungiblePositionManager), 1000000000);
//         (uint256 ftokenId,,,) = nonfungiblePositionManager.mint(floorParams);

//         floorTokenId = ftokenId;

//          if (discoveryTokenId != 0) {
//             // collect dulu
//             nonfungiblePositionManager.collect(
//                 INonfungiblePositionManager.CollectParams({
//                     tokenId: discoveryTokenId,
//                     recipient: address(this),
//                     amount0Max: type(uint128).max,
//                     amount1Max: type(uint128).max
//                 })
//             );

//             // withdraw semua
//             (,,,,,int24 lower,int24 upper, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(discoveryTokenId);
//             discoveryLower = lower;
//             discoveryUpper = upper;
//             nonfungiblePositionManager.decreaseLiquidity(
//                 INonfungiblePositionManager.DecreaseLiquidityParams({
//                     tokenId: discoveryTokenId,
//                     liquidity: liquidity,
//                     amount0Min: 0,
//                     amount1Min: 0,
//                     deadline: block.timestamp
//                 })
//             );

//             nonfungiblePositionManager.collect(
//                 INonfungiblePositionManager.CollectParams({
//                     tokenId: discoveryTokenId,
//                     recipient: address(this),
//                     amount0Max: type(uint128).max,
//                     amount1Max: type(uint128).max
//                 })
//             );
//          }

//          //ausdBalance = IERC20(token1).balanceOf(address(this));
//          uint256 kariBalance = IERC20(token0).balanceOf(address(this));
//          console.log("kari balance", kariBalance);

//          INonfungiblePositionManager.MintParams memory discoveryParams = INonfungiblePositionManager.MintParams({
//             token0: token0, //KARI
//             token1: token1, //AUSD
//             fee: 3000, //menentukan harga
//             tickLower: discoveryLower + 3600, //menentukan harga 
//             tickUpper: discoveryUpper + 3600, //menentukan harga
//             amount0Desired: kariBalance,
//             amount1Desired: 0,
//             amount0Min: 0,
//             amount1Min: 0,
//             recipient: address(this),
//             deadline: block.timestamp
//         });

//         console.log("Upper", discoveryUpper + 3600);
//         console.log("Lower", discoveryLower + 3600);
//         console.log("current Tick", currentTick);
//          IERC20(token0).approve(address(nonfungiblePositionManager), kariBalance);
//         (uint256 dtokenId,,,) = nonfungiblePositionManager.mint(discoveryParams);
//         console.log("xxx");
//         discoveryTokenId = dtokenId;

//         //  if (anchorTokenId != 0) {
//         //     // collect dulu
//         //     nonfungiblePositionManager.collect(
//         //         INonfungiblePositionManager.CollectParams({
//         //             tokenId: anchorTokenId,
//         //             recipient: address(this),
//         //             amount0Max: type(uint128).max,
//         //             amount1Max: type(uint128).max
//         //         })
//         //     );

//         //     // withdraw semua
//         //     (,,,,,int24 lower,int24 upper, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(anchorTokenId);
//         //     anchorLower = lower;
//         //     anchorUpper = upper;
//         //     nonfungiblePositionManager.decreaseLiquidity(
//         //         INonfungiblePositionManager.DecreaseLiquidityParams({
//         //             tokenId: anchorTokenId,
//         //             liquidity: liquidity,
//         //             amount0Min: 0,
//         //             amount1Min: 0,
//         //             deadline: block.timestamp
//         //         })
//         //     );

//         //     nonfungiblePositionManager.collect(
//         //         INonfungiblePositionManager.CollectParams({
//         //             tokenId: anchorTokenId,
//         //             recipient: address(this),
//         //             amount0Max: type(uint128).max,
//         //             amount1Max: type(uint128).max
//         //         })
//         //     );
//         //  }
//         // ausdBalance = IERC20(token1).balanceOf(address(this));
//         // kariBalance = IERC20(token0).balanceOf(address(this));

//         //  INonfungiblePositionManager.MintParams memory anchorParams = INonfungiblePositionManager.MintParams({
//         //     token0: token0, //KARI
//         //     token1: token1, //AUSD
//         //     fee: 3000, //menentukan harga
//         //     tickLower: anchorLower + 60, //menentukan harga 
//         //     tickUpper: anchorUpper + 60, //menentukan harga
//         //     amount0Desired: kariBalance,
//         //     amount1Desired: ausdBalance,
//         //     amount0Min: 0,
//         //     amount1Min: 0,
//         //     recipient: address(this),
//         //     deadline: block.timestamp
//         // });
//         //  IERC20(token0).approve(address(nonfungiblePositionManager), type(uint128).max);
//         //  IERC20(token1).approve(address(nonfungiblePositionManager), type(uint128).max);
//         // (uint256 atokenId,,,) = nonfungiblePositionManager.mint(anchorParams);
//         //  IERC20(token0).approve(address(nonfungiblePositionManager), 0);
//         //  IERC20(token1).approve(address(nonfungiblePositionManager), 0);
//         // anchorTokenId = atokenId;
// }

  
}