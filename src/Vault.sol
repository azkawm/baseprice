// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {INonfungiblePositionManager} from "./interfaces/INonfungiblePositionManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBasePrice} from "./interfaces/IBasePrice.sol";
import {BasePrice} from "./BasePrice.sol";

contract Vault {
     IBasePrice public basePrice;

    uint256 balance;
    uint256 totalLiquidity;
    uint256 public totalBorrowed;
    uint256 public reserveLiquidity; //80%
    uint256 public leverage;
    uint256 public utilizationRate;
    bool mintAnchor;

    error AnchorNotMinted();

    struct Position {
        uint256 tokenId;
        uint256 liquidity;
        uint256 amount0;
        uint256 usdcAmount;
    }

    constructor(address _basePrice){
        basePrice = IBasePrice(_basePrice);
    }


    function mintFloor(uint256 amount) public {
        basePrice.mintFloor(amount);
        setReserve();
    }

    function adjustFloor(uint256 amount) public {
        basePrice.adjustFloor(amount);
    }

    function deployAnchor(uint256 amount, uint256 anchors) public {
        _utilizationRate();
        uint256 total = leverage * amount;
        uint256 borrowAmount = total - amount;
        totalBorrowed += borrowAmount;
        basePrice.deployAnchor(total,anchors);
    }

    function _utilizationRate() public {
        //check rate
        //calculate leverage
        utilizationRate = 100 * totalBorrowed / reserveLiquidity;
        if (utilizationRate > 75) {
            leverage = 2;
        } else if (utilizationRate > 50) {
            leverage = 3;
        } else {
            leverage = 4;
        }
    }

    function mintDiscovery(uint256 amount) public {
        basePrice.mintDiscovery(amount);
    }

    function setReserve() public{
        reserveLiquidity = basePrice.getReserve();
    }
}