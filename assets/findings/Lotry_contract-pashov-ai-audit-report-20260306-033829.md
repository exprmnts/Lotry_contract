# Security Review — Lotry Contracts

---

## Scope

|                                  |                                                        |
| -------------------------------- | ------------------------------------------------------ |
| **Mode**                         | default                                                |
| **Files reviewed**               | `LotryLaunch.sol` · `LotryStaking.sol`<br>`LotryTicket.sol` · `RandomWalletPicker.sol` |
| **Confidence threshold (1-100)** | 80                                                     |

---

## Findings

[100] **1. Missing Slippage Protection on Bonding Curve Buy and Sell**

`LotryTicket.buy` · `LotryTicket.sell` · Confidence: 100

**Description**
The `buy()` and `sell()` functions lack minimum output parameters (`minTokensOut` / `minLotryOut`), allowing sandwich attacks where a frontrunner manipulates the bonding curve price before and after the victim's transaction, extracting value from the victim who receives fewer tokens (or less LOTRY) than expected.

**Fix**

```diff
- function buy(uint256 lotryAmountExternal) public nonReentrant {
+ function buy(uint256 lotryAmountExternal, uint256 minTokensOut) public nonReentrant {
      if (liquidityPulled) revert Ticket__TradingDisabled();
      if (lotryTokenAddress == address(0)) revert Ticket__NoLotryTokenSet();
      if (lotryAmountExternal < MIN_BUY) revert Ticket__BelowMinimumBuy();
      // ... existing logic ...
      uint256 tokensToTransfer = calculateBuyReturn(netLotryForCurve);
      if (tokensToTransfer <= 0) revert Ticket__ZeroTokenReturn();
+     if (tokensToTransfer < minTokensOut) revert Ticket__SlippageExceeded();
      // ... rest of function ...

- function sell(uint256 tokenAmount) public nonReentrant {
+ function sell(uint256 tokenAmount, uint256 minLotryOut) public nonReentrant {
      // ... existing logic ...
      uint256 lotryToReturnNetExternal = lotryToReturnNetInternal * LOTRY_SCALE;
+     if (lotryToReturnNetExternal < minLotryOut) revert Ticket__SlippageExceeded();
      // ... rest of function ...
```

---

[100] **2. Unbounded Stakers Array Enables Gas-Limit DoS Locking All Staked Funds**

`LotryStaking.stake` / `LotryStaking.withdrawAll` · Confidence: 100

**Description**
The `stake()` function is callable by anyone and pushes new addresses to the `stakers` array with no upper bound; an attacker can call `stake(1)` from thousands of unique addresses (each costing only 1 wei of the stake token), growing `stakers` indefinitely until `withdrawAll()` — which iterates over every element to reset `stakedAmount` — exceeds the block gas limit, permanently preventing the admin from withdrawing any staked funds.

**Fix**

```diff
- function withdrawAll() external onlyOwner nonReentrant {
-     uint256 amount = totalStaked;
-     if (amount == 0) revert ZeroAmount();
-
-     // Reset all staker balances
-     uint256 length = stakers.length;
-     for (uint256 i = 0; i < length; i++) {
-         stakedAmount[stakers[i]] = 0;
-     }
-
-     // Reset total staked
-     totalStaked = 0;
-
-     // Transfer all tokens to owner
-     stakeToken.safeTransfer(msg.sender, amount);
-
-     emit AdminWithdraw(msg.sender, amount);
- }
+ function withdrawAll() external onlyOwner nonReentrant {
+     uint256 amount = totalStaked;
+     if (amount == 0) revert ZeroAmount();
+
+     // Reset total staked (individual balances become stale but
+     // totalStaked == 0 prevents double-withdrawal on re-stake)
+     totalStaked = 0;
+
+     // Transfer all tokens to owner
+     stakeToken.safeTransfer(msg.sender, amount);
+
+     emit AdminWithdraw(msg.sender, amount);
+ }
```

---

[85] **3. Truncation Loss in LOTRY_SCALE Division Leaves Unaccounted Tokens in Contract**

`LotryTicket.buy` · `LotryTicket.depositLotryTokens` · Confidence: 85

**Description**
When `buy()` or `depositLotryTokens()` converts external LOTRY amounts to internal scale via `lotryAmountExternal / LOTRY_SCALE`, any remainder (`lotryAmountExternal % LOTRY_SCALE`, up to 9,999,999,999 wei per call) is silently absorbed by the contract without being tracked in `lotryRaised` or `accumulatedPoolFee`, permanently locking those tokens with no recovery path for users.

**Fix**

```diff
  function buy(uint256 lotryAmountExternal) public nonReentrant {
      if (liquidityPulled) revert Ticket__TradingDisabled();
      if (lotryTokenAddress == address(0)) revert Ticket__NoLotryTokenSet();
      if (lotryAmountExternal < MIN_BUY) revert Ticket__BelowMinimumBuy();
+     if (lotryAmountExternal % LOTRY_SCALE != 0) revert Ticket__InvalidLotryAmount();

      IERC20 lotryToken = IERC20(lotryTokenAddress);
      lotryToken.safeTransferFrom(msg.sender, address(this), lotryAmountExternal);
```

```diff
  function depositLotryTokens(uint256 amountExternal) external nonReentrant {
      if (lotryTokenAddress == address(0)) revert Ticket__NoLotryTokenSet();
      if (amountExternal == 0) revert Ticket__InvalidTokenAmount();
+     if (amountExternal % LOTRY_SCALE != 0) revert Ticket__InvalidLotryAmount();

      IERC20 lotryToken = IERC20(lotryTokenAddress);
      lotryToken.safeTransferFrom(msg.sender, address(this), amountExternal);
```

---

| # | Confidence | Title |
|---|---|---|
| 1 | [100] | Missing Slippage Protection on Bonding Curve Buy and Sell |
| 2 | [100] | Unbounded Stakers Array Enables Gas-Limit DoS Locking All Staked Funds |
| 3 | [85] | Truncation Loss in LOTRY_SCALE Division Leaves Unaccounted Tokens in Contract |
| | | **Below Confidence Threshold** |
| 4 | [75] | Fee-on-Transfer Token Accounting Mismatch in Buy, Sell, and Deposit Functions |

---

> This review was performed by an AI assistant. AI analysis can never verify the complete absence of vulnerabilities and no guarantee of security is given. Team security reviews, bug bounty programs, and on-chain monitoring are strongly recommended. For a consultation regarding your projects' security, visit [https://www.pashov.com](https://www.pashov.com)
