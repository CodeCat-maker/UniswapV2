
# UniswapV2 Breakdown Project

## Project Purpose

This project aims to break down and reimplement the core logic of Uniswap V2, providing a simplified version of an Automated Market Maker (AMM) for educational and experimental purposes. The main contract demonstrates how liquidity pools, pricing formulas, and token swaps work in a decentralized exchange.

Deploy address https://sepolia.etherscan.io/address/0x4e6037b6613dba5aba761e3b14c7954f114947b7

## Structure

- `src/UniswapV2.sol`: Main contract implementing the AMM logic
- `lib/openzeppelin-contracts/`: ERC20 standard contract dependency
- `test/`: Test scripts and cases
- `script/`: Deployment scripts

## Main Contract Flow

### 1. Add Liquidity
- Users call `addLiquidity` with ETH and ERC20 tokens
- Tokens are transferred in, reserves are synced
- Emits `LiquidityAdded` event

### 2. Price Quotation
- `quote` function calculates output amount based on current reserves and Uniswap V2 formula (0.3% fee)

### 3. Swaps
- **ETH to Token**: `swapEthForToken`
  - User sends ETH
  - Contract calculates token output and transfers tokens
  - Reserves are synced, emits `Swap` event
- **Token to ETH**: `swapTokenForEth`
  - User sends tokens
  - Contract calculates ETH output and transfers ETH
  - Reserves are synced, emits `Swap` event

### 4. Reserve Sync
- After each liquidity or swap operation, `_sync` updates internal reserves to match actual balances

## Getting Started

1. Install dependencies (Foundry, OpenZeppelin)
2. Build contracts:
	```sh
	forge build
	```
3. Run tests:
	```sh
	forge test
	```
4. Deploy contract:
	```sh
	forge script script/Deploy.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key>
	```

## References

- [Uniswap V2 Whitepaper](https://uniswap.org/whitepaper.pdf)
- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)
