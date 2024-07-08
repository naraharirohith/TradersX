// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockPriceOracle {
    mapping(string => int) private prices;

    function setPrice(string memory symbol, int price) external {
        prices[symbol] = price;
    }

    function getLatestBTCPrice() external view returns (int) {
        return prices["BTC"];
    }

    function getLatestUSDCPrice() external view returns (int) {
        return prices["USDC"];
    }
}