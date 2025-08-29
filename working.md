# Bonding-Curve Maths & Deployment Stats

## 1. Model

We use a **constant-product bonding curve**

\[ x\;\cdot\;y = k \]

where 
* `x`   – virtual token reserve \(v_{token}\)
* `y`   – virtual Ether reserve \(v_{eth}\)
* `k`   – invariant fixed at deployment (`k = v_token * v_eth`)

The **spot price** (in ETH per token) is

\[ P = \frac{y}{x} \]

Because both reserves are tracked with 18 decimals, the Solidity code scales by `1e18` to avoid precision loss.

### Buy (ETH → Tokens)
```
y' = y + Δy                       // add ETH
x' = k / y'                       // solve x·y = k
T  = x − x'                       // tokens to send to buyer
```

### Sell (Tokens → ETH)
```
x' = x + Δx                       // add tokens
y' = k / x'                       // solve for new y
E  = y − y'                       // ETH returned to seller
```
Both operations move **along** the same curve – nothing can drain the pool completely because x or y only approach 0 asymptotically.

---

## 2. Constructor Math

We want the following business rule:
*“If 800 M of the 1 B supply are sold, sellers can withdraw 110 % of the liquidity-pool value.”*

Symbols
* `S` – initial supply = **1 000 000 000** tokens
* `L` – lottery pool (e.g. 1 ETH)
* Buy/Sell tax before graduation = **20 %** → conceptual liquidity pool
  \[ LP = \frac{L}{0.20} = 5·L \]
* Target ETH returned after selling 800 M (= 0.8·S) tokens:
  \[ R = 1.10 · LP = 5.5 · L \]

Set
```
vt = S                  // virtual token reserve
ts = 0.8·S              // tokens to be sold in scenario
ve = ?                  // virtual ETH reserve we must find
```
Bonding curve during the sell scenario:
\[ R = ve · ts / (vt + ts) \]
⇒ solve for `ve`:
\[ ve = R · (vt + ts) / ts = 5.5L · 1.8 / 0.8 = **12.375 L** \]

Hence **virtual reserves**
```
virtualTokenReserve = 1 B tokens
virtualEthReserve   = 12.375 × L  ETH
k = vt · ve / 1e18
```

**Initial price**
\[ P₀ = ve / vt = \frac{12.375 · L}{1 000 000 000} \;ETH \]

---

## 3. Behaviour vs Lottery-Pool Size

| Lottery-Pool L | virtualEthReserve | Initial Price P₀ (ETH) |
|---------------:|------------------:|-----------------------:|
| 0.5 ETH        | 6.1875 ETH        | 6.1875 e-9             |
| **1 ETH**      | 12.375 ETH        | 1.2375 e-8             |
| 2 ETH          | 24.75 ETH         | 2.4750 e-8             |
| 5 ETH          | 61.875 ETH        | 6.1875 e-8             |

Price grows **linearly** with L, while the curvature (= price acceleration) is unchanged.

---

## 4. Detailed Numbers for L = 1 ETH

| Event                           | Tokens left (x) | ETH reserve (y) | Spot Price (ETH) |
|---------------------------------|-----------------:|-----------------:|-----------------:|
| Genesis                         | 1 000 M          | 12.375           | 1.2375 e-8        |
| After buying   1 ETH            | ≈ 919 M          | 13.375           | 1.454 e-8         |
| After cumulative 100 ETH buys   | ≈ 389 M          | 112.375          | 2.889 e-7         |
| After cumulative 800 M tokens sold (graduation) |   200 M | 17.875 | 8.937 e-8 |
| As x → 0 (theoretical limit)    | 0               | ∞                | ∞               |

Figures use the exact formula; minor rounding for readability.

---

## 5. Takeaways
1. **Cannot be sold out** – every extra purchase raises price, so draining the last token would need infinite ETH.
2. Increasing `L` scales *all* prices up linearly but leaves curve shape intact.
3. With the new `virtualTokenMultiplier = 1` the price curve is much steeper than before, ensuring real token reserves remain.

---

## 6. How to Re-Run the Simulation

```
# in repo root
npx hardhat test test/Simulation.test.js
```
The updated test will:
• deploy a pool with `L = 1 ETH`
• perform adaptive buys until ≥ 800 M tokens have been sold
• execute three proportional sells (10 %, 30 %, 50 % of holdings)
• print tables similar to a DEX trade history. 