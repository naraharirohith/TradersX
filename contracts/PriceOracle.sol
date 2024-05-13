pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract PriceOracle {
    AggregatorV3Interface internal bitcoinPriceFeed;
    AggregatorV3Interface internal USDCPriceFeed;

    constructor() {
        bitcoinPriceFeed = AggregatorV3Interface(0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43);
        USDCPriceFeed = AggregatorV3Interface(0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E);
    }

    /**
     * Returns the latest price
     */
    function getLatestBTCPrice() public view returns (int) {
        (
            uint80 roundID,
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = bitcoinPriceFeed.latestRoundData();
        return price;
    }

    function getLatestUSDCPrice() public view returns (int) {
        (
            uint80 roundID,
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = USDCPriceFeed.latestRoundData();
        return price;
    }
}