# How does the system work? How would a user interact with it?

Our Perpetual Protocol supports both long and short positions. DAI is required as collateral, and we offer the option to trade with ETH.
For example:

- ETH/USD market with both long and short collateral tokens as DAI, and the index token as ETH.

Liquidity providers can deposit DAI.
Liquidity providers bear the profits and losses of traders in the market for which they provide liquidity.

## How users interract with it

Traders can use

- `openPosition` to open a position. Traders can only open one position at a time. The function accepts `size` and `collateral`in DAI as well as a boolean to indicate if the position is long or short. We accept only one position per trader.
- `increasePositionSize` to increase a position's size. The function accepts `size` in DAI, and will be converted to the it's current `ETH` value, in order to be added to the position.
- `increasePositionCollateral` to increase collateral. Raw amount of `DAI` is taken.
- `decreasePosition` to decrease size and collateral. Accepts `DAI` for both size and collateral. Calculates partial PnL. If the PnL is positive, it distributes it to the trader. If the PnL is negative, it trasfers it to the liquidity pool.

Liquidity providers can use

- `addLiquidity` to add liquidity
- `removeLiquidity` to remove liquidity

Liquidators can use

- `isLiquidatable` to check if a trader's position could be liquidated. We account for all fees and PnL before calculating the leverage.
- `liquidate` to liquidate a trader's position. PnL goes to LPs, Fees go to LPs, 10% of the remaining collateral goes to the liquidator and all the rest is sent back to the trader.

Owner can use

- `setPositionFeeBasisPoints` used to adjust the position fee between 1 and 200 basis points

## Oracle System

Prices are provided by an off-chain oracle system:

Whenever a function is executed where the user sends a transaction, the asset prices are updated to have the current price, ensuring the correct token price.

The protocol obtains the updated prices instantly thanks to a library we have added with the name PRICECONVERTER, which utilizes the AggregatorV3Interface interface from Chainlink.

## Fees and Pricing

We support:

- liquidation fees -> 10% of the remaining collateral after fees and PnL is accounted for
- position fees -> changeable percentage of the amount of position increased. Starts with 1%
- borrowing fees -> 10% yearly rate

## Structure

There is one contract (`PerpetualGuardian`) and one library(`PriceConverter`) for receiving oracle prices.

The PerpetualGuardian contract inherits ERC4626, where we use it to create a vault for deposits and withdrawals by Liquidity Providers.

In it, we can also find functions to open positions for traders and close options.

One function created to maintain the protocol's security is called "liquidate," where any user other than the trader with a bad "position" can call it to liquidate the bad position.

We also maintain functions that calculate the positions to ensure they are safe for the protocol before opening and while they are open

The library used to receive oracle prices, "PriceConverter," uses the interface of the ChainLink library "AggregatorV3." We receive the price of the ETH/USD asset, allowing us to obtain the current price at any given moment.

## Implementation details

We keep all the positions we use the following struct

```
struct  Position {
uint256 collateral; //in DAI
uint256 avgEthPrice; // changes when the position is changed. We use it to account for PnL
uint256 ethAmount;
bool isLong; //indicates if the position is long or short
uint256 lastChangeTimestamp; // Used for borrowing fee
}
```

---

We use this struct to keep count of Open Interest. We have two instances of it - for short and long positions. Could be merged together in the future.

```
struct  PositionsSummary {
uint256 sizeInDai;
uint256 sizeInETH;
}
```

---

`totalAssets` is calculated by taking into consideration the DAI tokens in the vault and adding the PnL of traders as well as removing the collateral added from traders.

## Protocolo Perpetual Contract & Library

This section provides a technical description of the contracts.

- PerpetualGuardian: We have introduced functions that allow Liquidity Providers to deposit and withdraw assets to provide liquidity to the protocol. Furthermore, we have enabled the creation and cancellation of orders. To uphold the system's integrity, we have also implemented a liquidation function that closes positions if they do not meet the necessary requirements.
- PriceConverter : We utilize a custom library in our protocol that includes an interface from ChainLink, specifically AggregatorV3Interface. The built-in functions, such as getPrice, interact with the oracle to fetch the price of the ETH/USD pair. Additionally, we employ the getConversionRateinDai function to determine the specific value in DAI for a given amount of ETH.

# Deposits

Deposits add DAI to the market's pool.

Deposit requests are created by calling the `addLiquidity` function, specifying:

- The amount of DAI to deposit.

Deposits are added to the vault and aggregated to provide liquidity to the protocol.

# Withdrawals

Withdrawals are initiated by calling `removeLiquidity` and specifying:

- The amount of DAI you wish to withdraw.

- Withdrawals involve removing liquidity from the market pool.
- To ensure the availability of sufficient liquidity for potential withdrawals and to prevent any adverse effects on open positions, we have implemented the "checkForAvailableLiquidity" modifier.
- This modifier verifies that the withdrawal amount will not negatively impact ongoing operations and will not disrupt the protocol.

# Open Position

To open a position, requests must be created by calling `openPosition``, specifying:

- The amount to increase in the position ETH(up to a maximum of x15 on the provided DAI collateral).
- The amount of DAI used as collateral for the position.
- Specify whether the position will be long or short.

- We use the `checkForAvailableLiquidity` modifier to ensure that the operation to be executed is viable for the protocol's liquidity.
- Additionally, we ensure with the `_checkPositionHealth` function that the positions to be opened are suitable for the protocol's operation.
- To store the user's position, we've created a struct where we store all the data when opening the operation, and we add it to a mapping called `positions`.

# Position Decrease

Close or decrease a long/short perpetual position.

Market decrease order requests are created by calling `decreasePosition`, specifying:

- The amount of collateral to withdraw.
- The amount to decrease in the position.

- We use the `_applyBorrowingFee` function to apply a borrowing fee based on the position's size and the time it has been open.
- Additionally, with the `_calculatePositionPnL` function, we calculate Profit and Loss (PnL) to ensure accurate accounting before closing a trade.Thanks to the result, we know the amount that belongs to the LPs or traders.
- We utilize the `_checkPositionHealth` function to verify if the user's request to decrease a position is suitable for the protocol.

# Liquidating a Perpetual Position

To liquidate a long or short perpetual position, order requests are created by calling `liquidate`, specifying:

- The user's address with the open position.

- We ensure that the same user cannot liquidate their own position and that the position to be liquidated exceeds the available x15 leverage that the user has for trading.
- Additionally, with the `_calculatePositionPnL` function, we calculate Profit and Loss (PnL) to ensure accurate accounting before closing a trade. Thanks to the result, we know the amount that belongs to the LPs or traders.
- Additionally, we use the `_applyBorrowingFee` function to apply a borrowing fee based on the position's size and the time it has been open.
- A transfer is then made to the entity calling the `liquidate` operation, totaling 10% of the available collateral, while the remaining collateral is returned to the user from the position.

# Known risks and limitations

- We are aware of precision issues, due to the fact that in some places we keep `DAI` with precision of 1e18, but in others (Like totalAssets()) we keep it as is.
- One trader can only open one position at a time.
- We thought last moment that it might be useful to have a separate `closePosition` func, so the trader can close the position without much calculations.