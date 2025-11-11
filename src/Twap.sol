// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUniswapV2Pair {
    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

contract UniTwap {
    address public immutable pairAddress;
    address public updater;
    address public owner;

    uint256 public price0;
    uint256 public price1;

    uint8 public constant ROUNDS = 10; // Number of intervals to average over
    uint256 public constant INTERVAL = 10 minutes; // Length of each interval
    uint256 public constant SCALE = 1 ether;

    uint256 public lastUpdateTime;
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public currentRound;

    struct PairInfo {
        address token0;
        address token1;
        uint112 reserve0;
        uint112 reserve1;
        uint8 decimals0;
        uint8 decimals1;
    }

    // EVENTS
    event TwapUpdated(uint256 price0, uint256 price1);
    event CumulativePriceUpdated(uint256 price0Cumulative, uint256 price1Cumulative);
    event UpdaterChanged(address newUpdater);


    //ERRORS

    Error E_ONLY_UPDATER();
    Error E_ONLY_OWNER();
    Error E_INTERVAL_NOT_PASSED();
    Error E_ZERO_RESERVES();
    Error E_TWAP_ALREADY_UPDATED();
    Error E_TWAP_NOT_READY();

    constructor(address _pairAddress, address _updater,address _owner) {
        pairAddress = _pairAddress;
        updater = _updater;
        owner = _owner;
        lastUpdateTime = block.timestamp;
    }

    function updateCumulativePrice() external {
        if (msg.sender != updater) revert E_ONLY_UPDATER();

        if (block.timestamp < lastUpdateTime + INTERVAL) revert E_INTERVAL_NOT_PASSED();

        (uint256 price0In1, uint256 price1In0) = getPrices();

        // Update cumulative prices
        price0CumulativeLast += price0In1;
        price1CumulativeLast += price1In0;

        // Update last update time
        lastUpdateTime = block.timestamp;
        currentRound += 1;

        emit CumulativePriceUpdated(price0CumulativeLast, price1CumulativeLast);
    }

    function updateTwap() external {
        if (msg.sender != updater) revert E_ONLY_UPDATER();
        if (currentRound < ROUNDS) revert E_TWAP_NOT_READY();

        // Calculate TWAPs
        price0 = price0CumulativeLast / ROUNDS;
        price1 = price1CumulativeLast / ROUNDS;

        // Reset cumulative prices for next TWAP calculation
        price0CumulativeLast = 0;
        price1CumulativeLast = 0;
        currentRound = 0;

        emit TwapUpdated(price0, price1);
    }


    function changeUpdater(address newUpdater) external {
        if (msg.sender != owner) revert E_ONLY_OWNER();
        updater = newUpdater;
        emit UpdaterChanged(newUpdater);
    }


    function getPricesSafe()
        external
        view
        returns (uint256 twap0, uint256 twap1)
    {
        twap0 = price0;
        twap1 = price1;
    }

    function getPricesUnsafe()
        public
        view
        returns (uint256 price0In1, uint256 price1In0)
    {
        PairInfo memory info = getPairInfo(pairAddress);

        // Protect against zero reserves
        if (info.reserve0 == 0 || info.reserve1 == 0) revert E_ZERO_RESERVES();

        uint256 r0 = uint256(info.reserve0);
        uint256 r1 = uint256(info.reserve1);

        uint256 decimals0Pow = 10 ** uint256(info.decimals0);
        uint256 decimals1Pow = 10 ** uint256(info.decimals1);

        price0In1 = (r1 * decimals0Pow * SCALE) / (r0 * decimals1Pow);
        price1In0 = (r0 * decimals1Pow * SCALE) / (r1 * decimals0Pow);
    }

    function getTokens() external view returns (address, address) {
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        return (pair.token0(), pair.token1());
    }

    function getPairInfo(
        address pair
    ) public view returns (PairInfo memory info) {
        IUniswapV2Pair p = IUniswapV2Pair(pair);
        (uint112 r0, uint112 r1, ) = p.getReserves();
        address t0 = p.token0();
        address t1 = p.token1();

        uint8 d0 = _safeDecimals(t0);
        uint8 d1 = _safeDecimals(t1);

        info = PairInfo({
            token0: t0,
            token1: t1,
            reserve0: r0,
            reserve1: r1,
            decimals0: d0,
            decimals1: d1
        });
    }

    function _safeDecimals(address token) internal view returns (uint8) {
        (bool ok, bytes memory data) = token.staticcall(
            abi.encodeWithSignature("decimals()")
        );
        if (!ok || data.length < 32) {
            return 18;
        }
        uint256 dec = abi.decode(data, (uint256));
        if (dec > 255) return 18;
        return uint8(dec);
    }
}
