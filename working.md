# Bonding-Curve Maths & Deployment Stats

## 1. Model

We use a **constant-product bonding curve** defined by the invariant:

\[ (V_T - S_c) \cdot (V_E + E_r) = k \]

where:
*   \(V_T\) – Virtual Token Reserve (constant)
*   \(V_E\) – Virtual ETH Reserve (constant)
*   \(S_c\) – Circulating Supply of tokens
*   \(E_r\) – ETH Raised by the curve
*   \(k\)   – The invariant, calculated at deployment: \(k = V_T \cdot V_E\)

The **spot price** \(P\) in ETH per token is the ratio of the effective reserves:

\[ P = \frac{V_E + E_r}{V_T - S_c} \]

Substituting the invariant, we can express the price as a function of the circulating supply:

\[ P(S_c) = \frac{k}{(V_T - S_c)^2} \]

## 2. Constructor Math: Targeting a 20x Price Increase

We set the curve parameters to achieve a **20x price increase** when **500 million tokens** (50% of the initial supply) have been sold.

Let:
*   \(P_0\) be the initial price at \(S_c = 0\).
*   \(P_f\) be the final price when \(S_c = S_{target} = 500 \cdot 10^6\) tokens.

The price ratio is:
\[ \frac{P_f}{P_0} = \frac{k / (V_T - S_{target})^2}{k / (V_T - 0)^2} = \left(\frac{V_T}{V_T - S_{target}}\right)^2 \]

We require this ratio to be 20:
\[ \left(\frac{V_T}{V_T - S_{target}}\right)^2 = 20 \]
\[ \frac{V_T}{V_T - S_{target}} = \sqrt{20} \]

Solving for \(V_T\):
\[ V_T = \sqrt{20} \cdot (V_T - S_{target}) \]
\[ V_T \cdot (\sqrt{20} - 1) = \sqrt{20} \cdot S_{target} \]
\[ V_T = S_{target} \cdot \frac{\sqrt{20}}{\sqrt{20} - 1} \]

### Calculation

Using high-precision values:
*   \(S_{target} = 500,000,000 \cdot 10^{18}\)
*   \(\sqrt{20} \approx 4.472135955\)

\[ V_T = (5 \cdot 10^{26}) \cdot \frac{4.472135955}{4.472135955 - 1} \approx 6.44007939 \cdot 10^{26} \]

This value is set as a constant in the contract's constructor for gas efficiency:
`virtualTokenReserve = 644007939147311001867;`

The `virtualEthReserve` is then calculated based on a target initial price (e.g., \(0.000000005\) ETH), and `k` is set. This configuration ensures the desired price volatility is baked into the curve from the start.

## 3. How to Run the Simulation

The simulation test verifies that the implemented curve behaves as designed, including the 20x price increase milestone.

To run the test:
```bash
# In the repository root
npx hardhat test test/Simulation.test.js
```
The test will:
*   Deploy a pool with the new curve parameters.
*   Perform a series of buys to simulate market activity.
*   Verify that the price has increased by approximately 20x when 500M tokens are sold.
*   Log detailed tables of market state changes. 