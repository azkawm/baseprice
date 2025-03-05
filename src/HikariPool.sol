// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import {IUniswapV3Factory} from "./interfaces/IUniswapV3Factory.sol";

// interface IUniswapV3Pool {
//     function createAndInitializePoolIfNecessary(
//         address token0,
//         address token1,
//         uint24 fee,
//         uint160 sqrtPriceX96
//     ) external payable returns (address pool) 
// }

contract HikariPool {
    IUniswapV3Factory public pool;

    constructor() {
        pool = IUniswapV3Factory(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    }

    function createPool(address token0,
        address token1,
        uint160 sqrtPriceX96) public {
        pool.createAndInitializePoolIfNecessary(
            token0,
            token1,
            3000,
            sqrtPriceX96
        );
    }



}