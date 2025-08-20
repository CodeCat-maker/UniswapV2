// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;
import {Test, console} from "forge-std/Test.sol";
import {Exchange} from "../src/UniswapV2.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "forge-std/console2.sol";

contract TestToken is ERC20 {
  constructor() ERC20("Test", "TST") {
    _mint(msg.sender, 1_000_000 ether);
  }
}

contract ExchangeTest is Test {
  Exchange public exchange;
  TestToken public token;

  address user = address(this);

  // Events defined in the contract
  event LiquidityAdded(address indexed provider, uint256 ethAmount, uint256 tokenAmount);
  event Swap(address indexed trader, uint256 amountIn, uint256 amountOut, bool ethToToken);

  function setUp() public {
    token = new TestToken();
    exchange = new Exchange(address(token));
    token.approve(address(exchange), type(uint256).max);
  }

  function test_addLiquidity() public {
    uint256 initialTokenBalance = token.balanceOf(address(exchange));
    uint256 initialEthBalance = address(exchange).balance;

    uint256 ethToAdd = 10 ether;
    uint256 tokenToAdd = 100 ether;

    // vm.expectEmit();
    // emit LiquidityAdded(address(this), ethToAdd, tokenToAdd);

    exchange.addLiquidity{value: ethToAdd}(tokenToAdd);

    uint256 finalTokenBalance = token.balanceOf(address(exchange));
    uint256 finalEthBalance = address(exchange).balance;

    assertEq(finalTokenBalance, initialTokenBalance + tokenToAdd, "exchange token balance should increase");
    assertEq(finalEthBalance, initialEthBalance + ethToAdd, "exchange ETH balance should increase");
  }

function test_addLiquidity_RevertOnZeroAmount() public {
  vm.expectRevert(Exchange.ZERO_LIQ.selector);
  exchange.addLiquidity{value: 0}(1 ether);

  vm.expectRevert(Exchange.ZERO_LIQ.selector);
  exchange.addLiquidity{value: 1 ether}(0);
}


  function test_addLiquidity_RevertOnInsufficientAllowance() public {
    // Clear approval
    token.approve(address(exchange), 0);
    vm.expectRevert();
    exchange.addLiquidity{value: 1 ether}(1 ether);
  }

  function test_addLiquidity_RevertOnInsufficientBalance() public {
    uint256 bal = token.balanceOf(address(this));
    token.transfer(address(0xdead), bal);
    vm.expectRevert();
    exchange.addLiquidity{value: 1 ether}(1 ether);
  }

  function test_quote_MatchesUniswapFormula() public {
    // Add liquidity first
    uint256 ethReserve = 200 ether;
    uint256 tokenReserve = 200 ether;

    exchange.addLiquidity{value: ethReserve}(tokenReserve);

    uint256 ethIn = 100 ether;

    uint256 inputAmountWithFee = ethIn * 997;
    uint256 numerator = inputAmountWithFee * tokenReserve;
    uint256 denominator = (ethReserve * 1000) + inputAmountWithFee;
    uint256 expectedTokenOut = numerator / denominator;

    uint256 actualTokenOut = exchange.quote(ethIn, true);

    console2.log("Expected:", expectedTokenOut);
    console2.log("Actual  :", actualTokenOut);
    assertEq(actualTokenOut, expectedTokenOut, "quote mismatch");
  }

function test_quote_ZeroInput() public {
  exchange.addLiquidity{value: 200 ether}(200 ether);
  vm.expectRevert(Exchange.INSUFFICIENT_LIQUIDITY.selector);
  exchange.quote(0, true);
}

  function testFuzz_quote_Monotonic(uint128 ethIn1, uint128 ethIn2) public {
    vm.assume(ethIn1 > 0 && ethIn2 > 0);
    vm.assume(ethIn1 <= 1e36 && ethIn2 <= 1e36);

    // Add sufficient liquidity
    exchange.addLiquidity{value: 1_000_000 ether}(1_000_000 ether);

    uint256 out1 = exchange.quote(uint256(ethIn1), true);
    uint256 out2 = exchange.quote(uint256(ethIn2), true);

    if (ethIn1 < ethIn2) {
      assertLe(out1, out2, "monotonicity violated");
    } else if (ethIn1 > ethIn2) {
      assertGe(out1, out2, "monotonicity violated");
    } else {
      assertEq(out1, out2, "equal inputs must yield equal outputs");
    }
  }

  function test_swapEthForToken() public {
    // Add liquidity first
    uint256 ethReserve = 200 ether;
    uint256 tokenReserve = 200 ether;
    exchange.addLiquidity{value: ethReserve}(tokenReserve);

    uint256 ethIn = 10 ether;
    uint256 expectedOut = exchange.quote(ethIn, true);

    uint256 balanceBefore = token.balanceOf(address(this));
    exchange.swapEthForToken{value: ethIn}();
    uint256 balanceAfter = token.balanceOf(address(this));

    assertEq(balanceAfter - balanceBefore, expectedOut, "incorrect token output");
  }

  function test_swapTokenForEth() public {
    // Add liquidity first
    uint256 ethReserve = 200 ether;
    uint256 tokenReserve = 200 ether;
    exchange.addLiquidity{value: ethReserve}(tokenReserve);

    uint256 tokenIn = 10 ether;
    uint256 expectedOut = exchange.quote(tokenIn, false);

    uint256 balanceBefore = address(this).balance;
    exchange.swapTokenForEth(tokenIn);
    uint256 balanceAfter = address(this).balance;

    assertEq(balanceAfter - balanceBefore, expectedOut, "incorrect ETH output");
  }

  receive() external payable {}
}
