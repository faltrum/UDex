// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MockV3Aggregator} from "../mock/MockV3Aggregator.sol";
import {UDex} from "../../src/UDex.sol";
import {DeployUDex} from "../../script/DeployUDex.s.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract UDexTest is StdCheats, Test {
    UDex uDex;
    HelperConfig public helperConfig;

    address public ethXdcPriceFeed;
    address public xdc;
    uint256 public deployerKey;

    address public lP1 = makeAddr("lP1");
    address public lP2 = makeAddr("lP2");
    address public trader1 = makeAddr("trader1");
    address public trader2 = makeAddr("trader2");
    address public liquidator = makeAddr("liquidator");

    ERC20Mock public XDC;

    using SafeCast for int256;
    using SafeCast for uint256;

    //================================================================================
    // Setup
    //================================================================================
    function setUp() public {
        DeployUDex deployer = new DeployUDex();
        (uDex, helperConfig) = deployer.run();
        (ethXdcPriceFeed, xdc, deployerKey) = helperConfig.activeNetworkConfig();
        if (block.chainid == 31337) {
            XDC = ERC20Mock(uDex.asset());
            XDC.mint(lP1, 100_000);
            XDC.mint(lP2, 100_000);
            XDC.mint(trader1, 50_000);
            XDC.mint(trader2, 10_000);
        }
    }

    modifier addLP() {
        vm.startPrank(lP1);
        XDC.approve(address(uDex), 10_000);
        uDex.deposit(10_000, lP1);
        vm.stopPrank();
        vm.startPrank(lP2);
        XDC.approve(address(uDex), 20_000);
        uDex.deposit(20_000, lP2);
        vm.stopPrank();
        _;
    }

    modifier addTrader() {
        vm.startPrank(trader1);
        XDC.approve(address(uDex), 1_000);
        uDex.openPosition(5_000, 1_000, false);
        vm.stopPrank();
        vm.startPrank(trader2);
        XDC.approve(address(uDex), 1_000);
        uDex.openPosition(5_000, 1_000, true);
        vm.stopPrank();
        _;
    }

    //================================================================================
    // LP tests
    //================================================================================
    function testDepositLiquidity() public {
        vm.startPrank(lP1);
        XDC.approve(address(uDex), 10_000);
        uDex.deposit(10_000, lP1);
        assertEq(uDex.balanceOf(lP1), 10_000);

        uDex.withdraw(1_000, lP1, lP1);
        assertEq(uDex.balanceOf(lP1), 9_000);
        vm.stopPrank();
    }
}
