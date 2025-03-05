// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import {INonfungiblePositionManager} from "./interfaces/INonfungiblePositionManager.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {MockAUSD} from "./mocks/MockAUSD.sol";
// import {MockKARI} from "./mocks/MockKARI.sol";

// contract KariPool{

//     address public constant nonfungiblePositionManager = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
//     address public constant factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

//     address public tokenKari;
//     address public tokenAUSD;

//     function createLiquidity() external{
//         IERC20(token).approve(address(nonfungiblePositionManager), amount);
//         address pool = factory.createPool(tokenA, tokenB, feeTier);
//         IUniswapV3Pool(pool).initialize(sqrtPriceX96);
//     }

//     function depositLiquidity() external{
//         IERC20(token).approve(address(nonfungiblePositionManager), amount);
//         INonfungiblePositionManager(nonfungiblePositionManager).mint(INonfungiblePositionManager.MintParams({
//             token0: token0,
//             token1: token1,
//             fee: fee,
//             tickLower: tickLower,
//             tickUpper: tickUpper,
//             amount0Desired: amount0Desired,
//             amount1Desired: amount1Desired,
//             amount0Min: amount0Min,
//             amount1Min: amount1Min,
//             recipient: recipient,
//             deadline: deadline
//         }));
//     }
// }