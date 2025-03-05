// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {INonfungiblePositionManager} from "./interfaces/INonfungiblePositionManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVault} from "./interfaces/IVault.sol";
import {Vault} from "./Vault.sol";

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

contract BasePrice {
    address public router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    
    IVault public vault;
    // 1 kali bump sama dengan 1000 tick
    uint256 public constant BUMP_TICK = 1000;

    // 1 kali sweep sama dengan 1000 tick
    uint256 public constant SWEEP_TICK = 1000;

    INonfungiblePositionManager public constant nonfungiblePositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    // liquidity
    address public weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    uint24 public feeTier = 3000;

    // floor
    int24 public floorLowerTick;
    int24 public floorUpperTick;
    uint256 public floorTokenId;

    // discovery
    int24 public discoveryLowerTick;
    int24 public discoveryUpperTick;
    uint256 public discoveryTokenId;

    //anchor
    struct Anchor{
        uint256 liquidity;
        uint256 tokenId;
        bool isFilled;
    }
    uint256 anchorPrice;

    uint256 public anchorMaxId;
    uint256 public anchorTokenId;
    uint256 public reserveLiquidity;
    uint256 priceFeed; //1000
    uint256 currentPrice; //1200

    mapping(uint256 => Anchor) anchors;

    //event
    event AnchorsDeployed(uint256 tokenId, uint256 liquidityAmount);

    constructor(
        int24 initialFloorLowerTick,
        int24 initialFloorUpperTick,
        int24 initialDiscoveryLowerTick,
        int24 initialDiscoveryUpperTick
       
    ) {
        floorLowerTick = initialFloorLowerTick; // -207240
        floorUpperTick = initialFloorUpperTick; // -207180
        discoveryLowerTick = initialDiscoveryLowerTick; // -191150
        discoveryUpperTick = initialDiscoveryUpperTick; // -191140
        //vault = IVault(_vault);
    }

    function swap(uint256 amountIn, address pairToken1, address pairToken2) public {

       ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: pairToken1,
                tokenOut: pairToken2,
                fee: 3000, // 0.3
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

       IERC20(pairToken1).approve(router, amountIn); // approve kepada Uniswap
        ISwapRouter(router).exactInputSingle(params);
  
  }

    function mintFloor(uint256 amount) public {
        IERC20(usdc).transferFrom(msg.sender, address(this), amount);
        //harga $1000
        // jika belum ada posisi ya gak perlu collect dan withdraw 
        if (floorTokenId != 0) {
            // collect dulu
            nonfungiblePositionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: floorTokenId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );

            // withdraw semua
            (,,,,,,, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(floorTokenId);

            nonfungiblePositionManager.decreaseLiquidity(
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: floorTokenId,
                    liquidity: liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                })
            );

            // burn
            // nonfungiblePositionManager.burn(floorTokenId);

            nonfungiblePositionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: floorTokenId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );
        }

        uint256 usdcBalance = IERC20(usdc).balanceOf(address(this));
        reserveLiquidity = usdcBalance;

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: weth,
            token1: usdc,
            fee: feeTier, //menentukan harga
            tickLower: floorLowerTick, //menentukan harga
            tickUpper: floorUpperTick, //menentukan harga
            amount0Desired: 0,
            amount1Desired: usdcBalance,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        });
        IERC20(usdc).approve(address(nonfungiblePositionManager), usdcBalance);
        (uint256 tokenId,,,) = nonfungiblePositionManager.mint(params);
        
        floorTokenId = tokenId;
    }

    function adjustFloor() public {
        // jika belum ada posisi ya gak perlu collect dan withdraw
        if (floorTokenId != 0) {
            // collect dulu
            nonfungiblePositionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: floorTokenId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );

            // withdraw semua
            (,,,,,,, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(floorTokenId);

            nonfungiblePositionManager.decreaseLiquidity(
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: floorTokenId,
                    liquidity: liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                })
            );

            nonfungiblePositionManager.collect(
        INonfungiblePositionManager.CollectParams({
            tokenId: floorTokenId,
            recipient: address(this),
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        })
    );

            // burn
            // nonfungiblePositionManager.burn(floorTokenId);
        }

        //IERC20(usdc).transfer(msg.sender, amount);
        uint256 usdcBalance = IERC20(usdc).balanceOf(address(this));
        //reserveLiquidity = usdcBalance;

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: weth,
            token1: usdc,
            fee: feeTier, //menentukan harga
            tickLower: floorLowerTick, //menentukan harga
            tickUpper: floorUpperTick, //menentukan harga
            amount0Desired: 0,
            amount1Desired: usdcBalance,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        });
        IERC20(usdc).approve(address(nonfungiblePositionManager), usdcBalance);
        (uint256 tokenId,,,) = nonfungiblePositionManager.mint(params);
        
        floorTokenId = tokenId;
    }

    function deployAnchor(uint256 amount, uint256 _anchors) public{
        //collectFloor dulu
        //jika belum ada posisi ya gak perlu collect dan withdraw
        getPrice();
        if (floorTokenId != 0) {
            // collect dulu
            nonfungiblePositionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: floorTokenId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );
            // withdraw semua
            (,,,,,,, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(floorTokenId);

            nonfungiblePositionManager.decreaseLiquidity(
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: floorTokenId,
                    liquidity: liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                })
            );

            nonfungiblePositionManager.collect(
        INonfungiblePositionManager.CollectParams({
            tokenId: floorTokenId,
            recipient: address(this),
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        })
    );

            // burn
            // nonfungiblePositionManager.burn(floorTokenId);
        }
        //calculate anchor distribution
        //uint256 anchorLiquidity = amount/anchors;
        uint256 anchorLiquidity = amount/_anchors;
        anchorMaxId = _anchors;
        //array
        //@amount / no. of anchor (2000-3000)
        for (uint i = 0; i < _anchors; i++) {
            //mint position
            //presales[newId] = Presale(presale.price, presale.endTime, presaleAllocation, 0, 0, 0);
            INonfungiblePositionManager.MintParams memory anchorParams = INonfungiblePositionManager.MintParams({
            token0: weth,
            token1: usdc,
            fee: feeTier, //menentukan harga
            tickLower: floorLowerTick, //menentukan harga
            tickUpper: floorUpperTick, //menentukan harga
            amount0Desired: 0,
            amount1Desired: anchorLiquidity,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        });
        anchors[1+i] = Anchor(anchorLiquidity,1+i,false);
        IERC20(usdc).approve(address(nonfungiblePositionManager), anchorLiquidity);
        (uint256 _anchorTokenId,,,) = nonfungiblePositionManager.mint(anchorParams);
        emit AnchorsDeployed(_anchorTokenId,anchorLiquidity);
        anchorTokenId = _anchorTokenId;
        }
        
        //distribute anchor
        //@for loop distribute anchor
        //emit event
        //refloor
        //deploy anchor
        //IERC20(usdc).transferFrom(msg.sender, address(this), amount);
        // jika belum ada posisi ya gak perlu collect dan withdraw

        uint256 usdcBalance = IERC20(usdc).balanceOf(address(this));

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: weth,
            token1: usdc,
            fee: feeTier, //menentukan harga
            tickLower: floorLowerTick, //menentukan harga
            tickUpper: floorUpperTick, //menentukan harga
            amount0Desired: 0,
            amount1Desired: usdcBalance,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        });
        IERC20(usdc).approve(address(nonfungiblePositionManager), usdcBalance);
        (uint256 _floorTokenId,,,) = nonfungiblePositionManager.mint(params);
        
        floorTokenId = _floorTokenId;
    }

    function sweep() external{
        uint256 percentage = currentPrice * 100/priceFeed;
        uint256 anchorId = anchorMaxId+1;
        if(percentage >= 2){
         //withdraw anchors id
         for(uint i = 0; i < 3; i++){
             nonfungiblePositionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: anchors[anchorId+i].tokenId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );

            // withdraw semua
            (,,,,,,, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(floorTokenId);

            nonfungiblePositionManager.decreaseLiquidity(
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: anchors[anchorId].tokenId,
                    liquidity: liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                })
            );
         }

         //mintFloor lagi
         refloor();
         //deployAnchor lagi
         deployAnchor(reserveLiquidity,10);
        }
    }

    function mintSweep(uint256 _anchorLiquidity) public {
        uint256 anchorId = anchorMaxId+1;
        for(uint i = 0; i < 3; i++){
            anchors[anchorId+i].liquidity = _anchorLiquidity;
            INonfungiblePositionManager.MintParams memory anchorParams = INonfungiblePositionManager.MintParams({
            token0: weth,
            token1: usdc,
            fee: feeTier, //menentukan harga
            tickLower: floorLowerTick, //menentukan harga
            tickUpper: floorUpperTick, //menentukan harga
            amount0Desired: 0,
            amount1Desired: _anchorLiquidity,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        });
        anchors[anchorId+i] = Anchor(_anchorLiquidity,anchorId,false);
        IERC20(usdc).approve(address(nonfungiblePositionManager), _anchorLiquidity);
        (uint256 _anchorTokenId,,,) = nonfungiblePositionManager.mint(anchorParams);
        emit AnchorsDeployed(_anchorTokenId,_anchorLiquidity);
        priceFeed = 1000;
        }
    }

    function withdrawPosition() external{
        if(floorTokenId !=0) {
             // collect dulu
            nonfungiblePositionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: floorTokenId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );

            // withdraw semua
            (,,,,,,, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(floorTokenId);

            nonfungiblePositionManager.decreaseLiquidity(
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: floorTokenId,
                    liquidity: liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                })
            );

            nonfungiblePositionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: floorTokenId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );
        }
    }

    function mintDiscovery(uint256 amount) public {
        IERC20(weth).transferFrom(msg.sender, address(this), amount);

        // jika belum ada posisi ya gak perlu collect dan withdraw
        if (discoveryTokenId != 0) {
            // collect dulu
            nonfungiblePositionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: discoveryTokenId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );

            // withdraw semua
            (,,,,,,, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(discoveryTokenId);

            nonfungiblePositionManager.decreaseLiquidity(
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: discoveryTokenId,
                    liquidity: liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                })
            );

            // burn
            // nonfungiblePositionManager.burn(floorTokenId);
        }

        uint256 wethBalance = IERC20(weth).balanceOf(address(this));

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: weth,
            token1: usdc,
            fee: feeTier,
            tickLower: floorLowerTick,
            tickUpper: floorUpperTick,
            amount0Desired: wethBalance,
            amount1Desired: 0,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        });
        IERC20(weth).approve(address(nonfungiblePositionManager), wethBalance);
        (uint256 tokenId,,,) = nonfungiblePositionManager.mint(params);

        discoveryTokenId = tokenId;
    }

    function refloor() public {
        // jika belum ada posisi ya gak perlu collect dan withdraw
        if (floorTokenId != 0) {
            // collect dulu
            nonfungiblePositionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: floorTokenId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );

            // withdraw semua
            (,,,,,,, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(floorTokenId);

            nonfungiblePositionManager.decreaseLiquidity(
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: floorTokenId,
                    liquidity: liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                })
            );

            // burn
            // nonfungiblePositionManager.burn(floorTokenId);
        }

        uint256 usdcBalance = IERC20(usdc).balanceOf(address(this));
        reserveLiquidity = usdcBalance;

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: weth,
            token1: usdc,
            fee: feeTier, //menentukan harga
            tickLower: floorLowerTick, //menentukan harga
            tickUpper: floorUpperTick, //menentukan harga
            amount0Desired: 0,
            amount1Desired: usdcBalance,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        });
        IERC20(usdc).approve(address(nonfungiblePositionManager), usdcBalance);
        (uint256 tokenId,,,) = nonfungiblePositionManager.mint(params);
        
        floorTokenId = tokenId;
    }

    function getReserve() external view returns(uint256){
        return reserveLiquidity;
    }

    function getPrice() public view returns(uint256){}
}
