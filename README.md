🧮 UniTwap — Uniswap V2 TWAP (Time-Weighted Average Price) Oracle
Overview

UniTwap is a lightweight on-chain oracle contract that fetches reserves from a Uniswap V2 pair and computes the Time-Weighted Average Price (TWAP) of both assets over time.

It allows safe on-chain retrieval of the average price of tokens in a Uniswap V2 liquidity pool, reducing the effects of short-term volatility and manipulation.

⚙️ Key Features

Fetches reserves and token addresses from a Uniswap V2 pair

Computes instant (spot) and time-weighted average prices

Uses a configurable updater to record prices periodically

Prevents update spam using a fixed interval (10 minutes)

Accumulates multiple samples (10 rounds by default) to compute TWAP

Handles tokens with different decimals

Emits events for every major update

🧩 Contract Details
Item Description
Compiler Version ^0.8.20
License MIT
Interface Used IUniswapV2Pair
Oracle Type Pull-based TWAP Oracle
Default Rounds 10
Default Interval 10 minutes per round
Price Scale 1e18 (1 ether)
📜 How It Works

1. Fetching Reserves

The contract reads data from a Uniswap V2 pair contract:

function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

These reserves represent the current liquidity for token0 and token1.

2. Computing Spot Prices

At any time, you can call getPricesUnsafe() to compute the current ratio-based price:

price0In1 = (reserve1 _ 10^decimals0 _ 1e18) / (reserve0 _ 10^decimals1)
price1In0 = (reserve0 _ 10^decimals1 _ 1e18) / (reserve1 _ 10^decimals0)

This gives the spot price of each token in terms of the other, scaled to 1e18 precision.

3. Recording Cumulative Prices

Every 10 minutes (the interval), the designated updater calls:

updateCumulativePrice()

This function:

Fetches the latest prices

Adds them to cumulative totals (price0CumulativeLast, price1CumulativeLast)

Increments the round counter

Emits CumulativePriceUpdated

4. Computing TWAP

After 10 rounds (i.e., ~100 minutes total), the updater calls:

updateTwap()

This calculates:

price0 = price0CumulativeLast / ROUNDS
price1 = price1CumulativeLast / ROUNDS

These represent the time-weighted average prices (TWAPs).

The contract then:

Resets accumulators

Resets round counter

Emits TwapUpdated

👤 Roles
Role Description
Owner The admin who can change the updater address
Updater The bot or off-chain script that calls update functions periodically
🧾 Key Functions
Function Description
getPricesUnsafe() Returns current (spot) prices based on reserves
getPricesSafe() Returns the latest stored TWAP prices
updateCumulativePrice() Updates cumulative price values every interval
updateTwap() Calculates and stores the TWAP after ROUNDS are completed
getPairInfo() Fetches token addresses, reserves, and decimals
getTokens() Returns the Uniswap pair’s token0 and token1 addresses
changeUpdater() Allows the owner to change the updater address
🚨 Errors
Error Meaning
E_ONLY_UPDATER() Called by a non-updater address
E_ONLY_OWNER() Called by a non-owner
E_INTERVAL_NOT_PASSED() Update called before the interval has elapsed
E_ZERO_RESERVES() One or both token reserves are zero
E_TWAP_NOT_READY() Attempt to calculate TWAP before enough rounds
📡 Events
Event Description
TwapUpdated(uint256 price0, uint256 price1) Emitted when TWAP values are computed
CumulativePriceUpdated(uint256 price0Cumulative, uint256 price1Cumulative) Emitted after each cumulative update
UpdaterChanged(address newUpdater) Emitted when the updater is changed
