// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {Tick} from "helpers/Tick.sol";
import {Position} from "helpers/Position.sol";

interface IUniswapV3MintCallback {
    function uniswapV3MintCallback(uint256, uint256) external;
}

interface IERC20 {
    function balanceOf(address) external returns(uint256);
}

contract UnisawpV3Pool {

    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    int24 internal immutable MIN_TICK = -887272;
    int24 internal immutable MAX_TICK = -MIN_TICK;

    address public immutable token0;
    address public immutable token1;

    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
    }

    Slot0 public slot0;

    // Amount of liquidity
    uint128 public liquidity;

    // Ticks info
    mapping(int24 => Tick.Info) public ticks;
    // Positions info
    mapping(bytes32 => Position.Info) public positions;

    event Mint(address indexed sender, address indexed owner, int24 lowerTick, int24 upperTick, uint256 amount, uint256 amount0, uint256 amount1);
    constructor(
        address _token0,
        address _token1,
        uint160 _sqrtPriceX96,
        int24 _tick
    ) {
        token0 = _token0;
        token1 = _token1;
        slot0 = Slot0({
            sqrtPriceX96 : _sqrtPriceX96,
            tick : _tick
        });
    }

    function mint(
        address owner,
        int24 lowerTick,
        int24 upperTick,
        uint128 amount
    ) public returns(uint256 amount0, uint256 amount1) {
        require(lowerTick < upperTick && lowerTick > MIN_TICK && upperTick < MAX_TICK, "invalid tick range");
        require(amount > 0, "invalid amount input");

        ticks.update(lowerTick, amount);
        ticks.update(upperTick, amount);

        Position.Info storage position = positions.get(
            owner,
            lowerTick,
            upperTick 
        );
        position.update(amount);

        amount0 = 0.998976618347425408 ether;
        amount1 = 5000 ether;

        uint256 balance0Before;
        uint256 balance1Before;
        if(amount0 > 0) balance0Before = balance0();
        if(amount1 > 0) balance1Before = balance1();
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(
            amount0,
            amount1
        );
        if(amount0 > 0) require(balance0() >= balance0Before + amount0, "token0 add failed"); 
        if(amount1 > 0) require(balance1() >= balance1Before + amount1, "token1 add failed");

        emit Mint(msg.sender, owner, lowerTick, upperTick, amount, amount0, amount1);
    }

    function balance0() internal returns(uint256) {
        return IERC20(token0).balanceOf(address(this));
    }

    function balance1() internal returns(uint256) {
        return IERC20(token1).balanceOf(address(this));
    }
}