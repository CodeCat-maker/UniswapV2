// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Exchange {
  IERC20 public immutable token;

  // Internal accounting reserves; always kept in sync with the contract's actual balance (see _sync)
  uint256 public reserveEth;
  uint256 public reserveToken;

  // Events (consistent with test cases)
  event LiquidityAdded(address indexed provider, uint256 ethAmount, uint256 tokenAmount);
  event Swap(address indexed trader, uint256 amountIn, uint256 amountOut, bool ethToToken);

  error ZERO_LIQ();
  error INSUFFICIENT_LIQUIDITY();
  error INSUFFICIENT_OUTPUT();

  constructor(address _token) {
    token = IERC20(_token);
  }

  // Receive ETH
  receive() external payable {}

  /// @notice Add liquidity: msg.value for ETH, parameter for Token amount
  function addLiquidity(uint256 tokenAmount) external payable {
    uint256 ethIn = msg.value;
    if (ethIn == 0 || tokenAmount == 0) revert ZERO_LIQ();

    // First transfer tokens in
    require(token.transferFrom(msg.sender, address(this), tokenAmount), "TOKEN_TRANSFER");

    // Sync internal reserves to actual balances to avoid calculation errors
    _sync();

    emit LiquidityAdded(msg.sender, ethIn, tokenAmount);
  }

  /// @notice Pure quote (based on current reserves, Uniswap V2 0.3% fee)
  /// @param amountIn Input amount (ETH or Token, depends on ethToToken)
  /// @param ethToToken true means ETH→Token, false means Token→ETH
  function quote(uint256 amountIn, bool ethToToken) public view returns (uint256 amountOut) {
    if (amountIn == 0) revert INSUFFICIENT_LIQUIDITY();

    (uint256 reserveIn, uint256 reserveOut) = ethToToken
      ? (reserveEth, reserveToken)
      : (reserveToken, reserveEth);

    if (reserveIn == 0 || reserveOut == 0) revert INSUFFICIENT_LIQUIDITY();

    // amountOut = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997)
    uint256 amountInWithFee = amountIn * 997;
    uint256 numerator = amountInWithFee * reserveOut;
    uint256 denominator = reserveIn * 1000 + amountInWithFee;
    amountOut = numerator / denominator;
    // In extreme cases where rounding down results in 0, revert as needed; here we allow 0 but check the lower limit during swap
  }

  /// @notice Swap: Exchange ETH for Token
  function swapEthForToken() external payable {
    uint256 ethIn = msg.value;
    uint256 tokenOut = quote(ethIn, true);
    if (tokenOut == 0 || tokenOut > reserveToken) revert INSUFFICIENT_OUTPUT();

    // Send Tokens
    require(token.transfer(msg.sender, tokenOut), "TOKEN_TRANSFER_OUT");

    // Sync reserves to actual balances afterward to avoid dirty reads during execution
    _sync();

    emit Swap(msg.sender, ethIn, tokenOut, true);
  }

  /// @notice Swap: Exchange Token for ETH
  function swapTokenForEth(uint256 tokenIn) external {
    if (tokenIn == 0) revert INSUFFICIENT_LIQUIDITY();

    uint256 ethOut = quote(tokenIn, false);
    if (ethOut == 0 || ethOut > reserveEth) revert INSUFFICIENT_OUTPUT();

    // First collect the Tokens
    require(token.transferFrom(msg.sender, address(this), tokenIn), "TOKEN_TRANSFER_IN");

    // Then send ETH
    (bool ok, ) = payable(msg.sender).call{value: ethOut}("");
    require(ok, "ETH_TRANSFER_OUT");

    // Sync reserves
    _sync();

    emit Swap(msg.sender, tokenIn, ethOut, false);
  }

  /// @dev Sync internal reserves to actual balances to avoid underflows/overflows from manual calculations
  function _sync() internal {
    reserveEth = address(this).balance;
    reserveToken = token.balanceOf(address(this));
  }
}