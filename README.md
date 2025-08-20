# 🦄 Uniswap V2 Mini Exchange (Simplified)

This project is a **minimal AMM (Automated Market Maker)**, inspired by **Uniswap V2**.
It supports **adding liquidity**, **quoting prices**, and **swapping ETH ↔ Token**.

Deploy address https://sepolia.etherscan.io/address/0x4e6037b6613dba5aba761e3b14c7954f114947b7


## Structure

- `src/UniswapV2.sol`: Main contract implementing the AMM logic
- `lib/openzeppelin-contracts/`: ERC20 standard contract dependency
- `test/`: Test scripts and cases
- `script/`: Deployment scripts

## Main Contract Flow

Core invariant:

```
x * y = k
```

- `x` = ETH reserve
- `y` = Token reserve
- `k` = Constant (liquidity invariant)

---

## 🔑 Core Components

### 1. Storage
```solidity
IERC20 public immutable token;
uint256 public reserveEth;
uint256 public reserveToken;
```

- `token`: ERC20 token contract
- `reserveEth`: ETH liquidity stored
- `reserveToken`: Token liquidity stored

👉 These reserves are always **synced** with the actual contract balances.

---

### 2. Add Liquidity
```solidity
function addLiquidity(uint256 tokenAmount) external payable
```

- User sends **ETH + Tokens**
- Both are deposited into the pool
- Internal reserves are updated via `_sync()`

📌 **Check**: Zero liquidity is rejected.

---

### 3. Quote Function (Pricing Formula)

```solidity
function quote(uint256 amountIn, bool ethToToken)
```

Formula (with 0.3% fee):

```
amountOut = (amountIn * 997 * reserveOut)
          / (reserveIn * 1000 + amountIn * 997)
```

- Preserves `x * y = k`
- Larger trades = **higher slippage**

---

### 4. Swap ETH → Token

```solidity
function swapEthForToken() external payable
```

Steps:
1. User sends ETH (`msg.value`)
2. Contract calculates `tokenOut = quote(ethIn, true)`
3. Transfer Tokens to user
4. Sync reserves

---

### 5. Swap Token → ETH

```solidity
function swapTokenForEth(uint256 tokenIn) external
```

Steps:
1. User sends Tokens via `transferFrom`
2. Contract calculates ETH out using `quote`
3. Contract sends ETH (`.call{value: ethOut}`)
4. Sync reserves

---

## 📊 AMM Curve

The **constant product formula** produces a hyperbolic curve:

![amm_curve](https://pub-db67a7eda04943498d6a86fbf4df7e03.r2.dev/amm_curve.jpeg)

- Adding ETH decreases available Token (and vice versa)
- Prevents draining the pool completely
- Defines **price slippage**

---

## 🧪 Unit Tests

Covered cases:
- ✅ Add liquidity success & revert on zero input
- ✅ Quote matches Uniswap V2 formula
- ✅ Swap ETH→Token & Token→ETH
- ✅ Reverts on insufficient liquidity

Run tests:

```bash
forge test -vv
```

---

## 🚀 Deployment

Deploy on Sepolia testnet:

```bash
forge script script/Deploy.s.sol:DeployExchange \
  --rpc-url $SEPOLIA_RPC \
  --broadcast
```

---

## 📌 Takeaways

- Simple AMM = **no order book**, only liquidity pool
- Core invariant = **x * y = k**
- Prices adjust automatically → **slippage is inevitable**
- Liquidity providers earn fees from swaps

---


## References

- [Uniswap V2 Whitepaper](https://uniswap.org/whitepaper.pdf)
- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)
