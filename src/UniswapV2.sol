// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Exchange {
    IERC20 public immutable token;

    // 内部记账的储备；始终与合约真实余额保持一致（见 _sync）
    uint256 public reserveEth;
    uint256 public reserveToken;

    // 事件（与测试用例一致）
    event LiquidityAdded(address indexed provider, uint256 ethAmount, uint256 tokenAmount);
    event Swap(address indexed trader, uint256 amountIn, uint256 amountOut, bool ethToToken);

    error ZERO_LIQ();
    error INSUFFICIENT_LIQUIDITY();
    error INSUFFICIENT_OUTPUT();

    constructor(address _token) {
        token = IERC20(_token);
    }

    // 接收 ETH
    receive() external payable {}

    /// @notice 添加流动性：msg.value 为 ETH，参数为 Token 数量
    function addLiquidity(uint256 tokenAmount) external payable {
        uint256 ethIn = msg.value;
        if (ethIn == 0 || tokenAmount == 0) revert ZERO_LIQ();

        // 先把 token 转进来
        require(token.transferFrom(msg.sender, address(this), tokenAmount), "TOKEN_TRANSFER");

        // 同步内部储备到真实余额，避免算差
        _sync();

        emit LiquidityAdded(msg.sender, ethIn, tokenAmount);
    }

    /// @notice 纯报价（基于当前储备，Uniswap V2 0.3% fee）
    /// @param amountIn 输入数量（ETH 或 Token，取决于 ethToToken）
    /// @param ethToToken true 表示 ETH→Token，false 表示 Token→ETH
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
        // 如果极端情况下向下取整为 0，可视需要选择 revert；这里沿用 0 也允许，但 swap 时再做下限检查
    }

    /// @notice 交换：用 ETH 换 Token
    function swapEthForToken() external payable {
        uint256 ethIn = msg.value;
        uint256 tokenOut = quote(ethIn, true);
        if (tokenOut == 0 || tokenOut > reserveToken) revert INSUFFICIENT_OUTPUT();

        // 发送 Token
        require(token.transfer(msg.sender, tokenOut), "TOKEN_TRANSFER_OUT");

        // 最后再同步储备到真实余额，避免中途读脏数据
        _sync();

        emit Swap(msg.sender, ethIn, tokenOut, true);
    }

    /// @notice 交换：用 Token 换 ETH
    function swapTokenForEth(uint256 tokenIn) external {
        if (tokenIn == 0) revert INSUFFICIENT_LIQUIDITY();

        uint256 ethOut = quote(tokenIn, false);
        if (ethOut == 0 || ethOut > reserveEth) revert INSUFFICIENT_OUTPUT();

        // 先把 Token 收进来
        require(token.transferFrom(msg.sender, address(this), tokenIn), "TOKEN_TRANSFER_IN");

        // 再发 ETH
        (bool ok, ) = payable(msg.sender).call{value: ethOut}("");
        require(ok, "ETH_TRANSFER_OUT");

        // 同步储备
        _sync();

        emit Swap(msg.sender, tokenIn, ethOut, false);
    }

    /// @dev 将内部储备同步为真实余额，避免手工加减出现下溢/溢出
    function _sync() internal {
        reserveEth = address(this).balance;
        reserveToken = token.balanceOf(address(this));
    }
}