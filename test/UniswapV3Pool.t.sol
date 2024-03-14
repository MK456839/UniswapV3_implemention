// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./ERC20Mintable.sol";
import "../src/UniswapV3Pool.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

contract UniswapV3PoolTest is Test {
    ERC20Mintable token0;
    ERC20Mintable token1;
    UnisawpV3Pool pool;

    bool shouldTransferInCallback;

    struct TestCaseParams {
        uint256 wethBalance;
        uint256 usdcBalance;
        int24 currentTick;
        int24 lowerTick;
        int24 upperTick;
        uint128 liquidity;
        uint160 sqrtPriceX96;
        bool shouldTransferInCallback;
        bool mintLiquidity;
    }

    function setUp() public {
        token0 = new ERC20Mintable("ETH", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);
    }

    function testMintSuccess() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance : 1 ether,
            usdcBalance : 5000 ether,
            currentTick : 85176,
            lowerTick : 84222,
            upperTick : 86129,
            liquidity : 1517882343751509868544,
            sqrtPriceX96 : 5602277097478614198912276234240,
            shouldTransferInCallback : true,
            mintLiquidity : true
        });

        (uint256 poolBalance0, uint256 poolBalance1) = setUpTestCase(params);
        uint256 expectedAmount0 = 0.998976618347425408 ether;
        uint256 expectedAmount1 = 5000 ether;
        // assertEq(poolBalance0, expectedAmount0);
        require(poolBalance0 == expectedAmount0, "invalid token0 deposit amount");
        require(poolBalance1 == expectedAmount1, "invalid token1 deposit amount");
        require(token0.balanceOf(address(pool)) == expectedAmount0, "invalid token0 deposit in pool");
        require(token1.balanceOf(address(pool)) == expectedAmount1, "invalid token1 deposit in pool");
        bytes32 positionKey = keccak256(abi.encodePacked(
            address(this),
            params.lowerTick,
            params.upperTick
        ));
        uint128 poolLiquidity = pool.positions(positionKey);
        require(poolLiquidity == params.liquidity, "invalid liquidity add in pool");
        (bool tickInitialized, uint128 tickLiquidity) = pool.ticks(params.lowerTick);
        require(tickInitialized, "tick update failed");
        require(tickLiquidity == params.liquidity, "invalid tick liquidity");

        (tickInitialized, tickLiquidity) = pool.ticks(params.upperTick);
        require(tickInitialized, "tick update failed");
        require(tickLiquidity == params.liquidity, "invalid tick liquidity");

        (uint160 sqrtPriceX96, int24 tick) = pool.slot0;
        require(sqrtPriceX96 == params.sqrtPriceX96, "invalid price in pool");
        require(tick = params.currentTick, "invalid tick in pool");
        

    }

    function setUpTestCase(TestCaseParams memory params) internal returns(uint256 poolBalance0, uint256 poolBalance1) {
        token0.mint(address(this), 1 ether);
        token1.mint(address(this), 5000 ether);

        pool = new UnisawpV3Pool(
            address(token0),
            address(token1),
            params.sqrtPriceX96,
            params.currentTick
        );

        shouldTransferInCallback = params.shouldTransferInCallback;

        if(params.mintLiquidity) {
            (poolBalance0, poolBalance1) = pool.mint(
                address(this),
                params.lowerTick,
                params.upperTick,
                params.liquidity
            );
        }
    }

    function uniswapV3MintCallback(uint256 amount0, uint256 amount1) external {
        if(shouldTransferInCallback) {
            token0.transfer(msg.sender, amount0);
            token1.transfer(msg.sender, amount1);
        }
    }

    // function testFail
}