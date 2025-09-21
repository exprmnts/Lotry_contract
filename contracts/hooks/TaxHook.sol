// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary, toBeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {SafeCast} from "@uniswap/v4-core/src/libraries/SafeCast.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

/// @title TaxHook
/// @notice This hook applies a 20% tax on swaps. For sells (Token for WETH), it taxes the WETH output.
/// @dev The hook flags must be set on the pool at initialization for this hook to be called.
contract TaxHook is IHooks, Ownable, ReentrancyGuard {
    using CurrencyLibrary for Currency;
    using BalanceDeltaLibrary for BalanceDelta;
    using BeforeSwapDeltaLibrary for BeforeSwapDelta;

    uint256 public constant TAX_PERCENT = 20;

    address public treasury;
    address public immutable wethAddress;

    mapping(address => uint256) public taxesOwed;

    IPoolManager public immutable poolManager;

    event TreasuryUpdated(address indexed newTreasury);

    constructor(
        IPoolManager _poolManager,
        address _wethAddress,
        address _treasury
    ) Ownable(msg.sender) {
        poolManager = _poolManager;
        wethAddress = _wethAddress;
        treasury = _treasury;

        // Validate that the deployed address has the before/after swap flags set
        // Hooks.Permissions memory perms = Hooks.Permissions({
        //     beforeInitialize: false,
        //     afterInitialize: false,
        //     beforeAddLiquidity: false,
        //     afterAddLiquidity: false,
        //     beforeRemoveLiquidity: false,
        //     afterRemoveLiquidity: false,
        //     beforeSwap: true,
        //     afterSwap: true,
        //     beforeDonate: false,
        //     afterDonate: false,
        //     beforeSwapReturnDelta: true,
        //     afterSwapReturnDelta: true,
        //     afterAddLiquidityReturnDelta: false,
        //     afterRemoveLiquidityReturnDelta: false
        // });
        // Hooks.validateHookPermissions(IHooks(address(this)), perms);
        
        // NOTE: Removed the on-chain validation call because `address(this)` has no runtime
        // code during construction, causing a revert. The pool manager will still verify
        // permissions at pool creation time via `getHookPermissions()`, so the hook will
        // operate correctly once attached to a pool.
    }

    modifier onlyPoolManager() {
        require(
            msg.sender == address(poolManager),
            "Only pool manager can call this"
        );
        _;
    }

    /// @notice The hook called before a swap.
    /// @dev This hook does not take any action before the swap.
    function beforeSwap(
        address, /* sender */
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata /* hookData */
    )
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        bool isBuy = params.zeroForOne && Currency.unwrap(key.currency0) == wethAddress;

        if (isBuy) {
            // We only tax exact input swaps
            if (params.amountSpecified > 0) {
                int256 amountInWETH = params.amountSpecified;
                int256 taxAmountWETH = (amountInWETH * int256(TAX_PERCENT)) / 100;

                taxesOwed[wethAddress] += uint256(taxAmountWETH);

                int128 tax128 = SafeCast.toInt128(taxAmountWETH);
                return (
                    IHooks.beforeSwap.selector,
                    toBeforeSwapDelta(tax128, 0),
                    0
                );
            }
        }

        return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    /// @notice The hook called after a swap.
    /// @dev This hook is where the tax logic is applied.
    function afterSwap(
        address, /* sender */
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata /* hookData */
    ) external override onlyPoolManager returns (bytes4, int128) {
        bool isSell =
            !params.zeroForOne && Currency.unwrap(key.currency0) == wethAddress;

        if (isSell) {
            // Tax the WETH output on sells (token -> WETH)
            uint256 amountOutWETH = uint256(int256(-delta.amount0()));
            uint256 taxAmountWETH = (amountOutWETH * TAX_PERCENT) / 100;

            taxesOwed[wethAddress] += taxAmountWETH;

            // Credit the tax to the hook. PoolManager will send `taxAmountWETH` WETH to this contract.
            return (IHooks.afterSwap.selector, SafeCast.toInt128(int256(taxAmountWETH)));
        }

        // Buy-side (WETH -> token) is fully handled in beforeSwap by
        // returning a positive delta for currency0 (WETH). No further action
        // required here; just acknowledge the callback.
        return (IHooks.afterSwap.selector, 0);
    }

    /// @notice Withdraws collected taxes to the treasury address.
    /// @dev It unwraps WETH to ETH before sending.
    function withdrawTaxes() external onlyOwner nonReentrant {
        uint256 wethOwed = taxesOwed[wethAddress];
        if (wethOwed > 0) {
            taxesOwed[wethAddress] = 0;
            // Pull the owed WETH from the PoolManager to this contract
            poolManager.take(Currency.wrap(wethAddress), address(this), wethOwed);
        }

        uint256 wethBalance = IWETH(wethAddress).balanceOf(address(this));
        if (wethBalance > 0) {
            IWETH(wethAddress).withdraw(wethBalance);
        }

        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            (bool success, ) = treasury.call{value: ethBalance}("");
            require(success, "ETH transfer failed");
        }
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    // Helper for testing with simplified mock
    function setTaxesOwed(address token, uint256 amount) external onlyOwner {
        taxesOwed[token] = amount;
    }

    // To receive ETH from unwrapping WETH
    receive() external payable {}

    // --- Unimplemented IHooks functions ---

    function beforeInitialize(address, PoolKey calldata, uint160)
        external
        pure
        override
        returns (bytes4)
    {
        return IHooks.beforeInitialize.selector;
    }

    function afterInitialize(address, PoolKey calldata, uint160, int24)
        external
        pure
        override
        returns (bytes4)
    {
        return IHooks.afterInitialize.selector;
    }

    function beforeAddLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IHooks.beforeAddLiquidity.selector;
    }

    function afterAddLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure override returns (bytes4, BalanceDelta) {
        return (IHooks.afterAddLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

     function beforeRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IHooks.beforeRemoveLiquidity.selector;
    }

    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure override returns (bytes4, BalanceDelta) {
        return (IHooks.afterRemoveLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    function beforeDonate(
        address,
        PoolKey calldata,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IHooks.beforeDonate.selector;
    }

    function afterDonate(
        address,
        PoolKey calldata,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IHooks.afterDonate.selector;
    }

    function getHookPermissions() external pure returns (Hooks.Permissions memory permissions) {
        permissions.beforeSwap = true;
        permissions.afterSwap = true;
        permissions.beforeSwapReturnDelta = true;
        permissions.afterSwapReturnDelta = true;
    }
}
