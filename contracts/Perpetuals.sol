// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./PriceOracle.sol";
import "./Vault.sol";

contract PerpetualProtocol {
    ERC20 public collateralToken; // The token used as collateral (e.g., USDC)
    uint public maxLeverage = 15; // Maximum allowed leverage
    address public liquityVaultAddress;
    address public priceOracleAddress;

    uint internal totalNoOfPositions;

    PriceOracle price = PriceOracle(priceOracleAddress);
    LiquidityVault public vault= LiquidityVault(liquityVaultAddress);

    struct Position {
        address trader;
        int size;
        int collateral;
        int borrowedValue;
        bool isOpen;
        bool isLong; // true for long, false for short
    }

    mapping(address => mapping(uint => Position)) public positions;
    mapping(address => uint) public totalPositions;

    constructor(ERC20 _collateralToken, address _liquityVaultAddress, address _priceOracleAddress) {
        collateralToken = _collateralToken;
        liquityVaultAddress = _liquityVaultAddress;
        priceOracleAddress = _priceOracleAddress;
        totalNoOfPositions = 0;
    }

    // size, collateral amount in USDC
    function openPosition(int size, int collateralAmount, bool isLong) external {
        require(!positions[msg.sender][totalPositions[msg.sender]].isOpen, "Position already open");
        require(size / collateralAmount <= int(maxLeverage), "Exceeds maximum leverage");

        int collateralAmountInUSDC = price.getLatestUSDCPrice();

        vault.deposit(uint(collateralAmount), msg.sender);

        int latestBTCPrice = price.getLatestBTCPrice();
        int _borrowedValue = size * latestBTCPrice;
        
        totalPositions[msg.sender]++;

        positions[msg.sender][totalPositions[msg.sender]] = Position({
            trader: msg.sender,
            size: size,
            collateral: collateralAmountInUSDC,
            borrowedValue: _borrowedValue,
            isOpen: true,
            isLong: isLong
        });
    
        // Additional logic for position opening might include price checks, etc.
    }

    function increasePositionSize(uint positionIndex, int additionalSize) external {
        Position storage position = positions[msg.sender][positionIndex];
        require(position.isOpen, "Position is not open");
        require(position.trader == msg.sender, "Not authorized to modify this position");
        require(additionalSize > 0 , "Additional size cannot be zero");

        int newBorrowedValue = position.borrowedValue + (additionalSize * price.getLatestBTCPrice());
        int newSize = position.size + additionalSize;
        int collateralAmountInUSDC = position.collateral;

        require(newSize / collateralAmountInUSDC <= int(maxLeverage), "Exceeds max leverage");

        position.size = additionalSize;
        position.borrowedValue = newBorrowedValue;
    }

    function increasePositionCollateral(uint positionIndex, int additionalCollateral) external {
        Position storage position = positions[msg.sender][positionIndex];
        require(position.isOpen, "Position is not open");
        require(position.trader == msg.sender, "Not authorized to modify this position");

        require(additionalCollateral > 0, "Additional collateral must be positive");
        require(int(collateralToken.balanceOf(msg.sender)) >= additionalCollateral, "Insufficient collateral");
    
        int newCollateral = position.collateral + additionalCollateral;
        int newSize = position.size;

        require(newSize / newCollateral <= int(maxLeverage), "Exceeds maximum leverage");


        vault.deposit(uint(additionalCollateral), msg.sender);
        position.collateral += additionalCollateral;
    }

    function decreasePositionSize(uint positionIndex, int sizeDecrease) external {
        Position storage position = positions[msg.sender][positionIndex];
        require(position.isOpen, "Position is not open");
        require(position.trader == msg.sender, "Not authorized to modify this position");
        require(sizeDecrease > 0 , "No change in size");

        (int currentPnl, int temp) = calculatePnL(position);
        int realizedPnl = currentPnl * sizeDecrease / position.size;

            // Update position size and borrowed value
        position.size -= sizeDecrease;
        position.borrowedValue = (position.borrowedValue * position.size) / (position.size + sizeDecrease);

        // Handle realized PnL
        if (realizedPnl > 0) {
            // Pay profit to trader
            vault.withdraw(uint(realizedPnl), msg.sender, address(this));
        } else if (realizedPnl < 0) {
            // Deduct loss from collateral
            position.collateral += realizedPnl; // realizedPnl is negative, so this reduces collateral
        }

        // Check if position should be closed
        if (position.size == 0) {
            // Close position and return remaining collateral
            uint remainingCollateral = uint(position.collateral);
            vault.withdraw(remainingCollateral, msg.sender, address(this));
            position.isOpen = false;
            position.collateral = 0;
        } else {
            // Ensure remaining position is not liquidatable
            require(getCurrentLeverage(positionIndex, msg.sender) <= maxLeverage, "Resulting position would be liquidatable");
        }
    }

    function decreasePositionCollateral(uint positionIndex, int collateralDecrease) external {
        Position storage position = positions[msg.sender][positionIndex];
        require(position.isOpen, "Position is not open");
        require(position.trader == msg.sender, "Not authorized to modify this position");
        require(collateralDecrease > 0 && collateralDecrease <= position.collateral, "Invalid collateral decrease");

        // Update position collateral
        position.collateral -= collateralDecrease;

        // Ensure remaining position is not liquidatable
        require(getCurrentLeverage(positionIndex, msg.sender) <= maxLeverage, "Resulting position would be liquidatable");

        // Withdraw collateral to trader
        vault.withdraw(uint(collateralDecrease), msg.sender, address(this));

        // Emit event or perform additional actions as needed
    }

    function getCurrentLeverage(uint positionIndex, address trader) public view returns (uint) {
        Position storage position = positions[trader][positionIndex];
        require(position.isOpen, "Position is not open");

        int currentPositionValue = position.size * int(price.getLatestBTCPrice());
        uint leverage;

        if (currentPositionValue > 0) {
            leverage = uint((currentPositionValue + position.borrowedValue) / position.collateral);
        } else {
            leverage = uint((position.borrowedValue - currentPositionValue) / position.collateral);
        }

    return leverage;
    }

    function calculatePnL(Position storage position) private view returns (int, int) {
        int currentMarketValue = price.getLatestBTCPrice();
        int averagePositionPrice = position.borrowedValue;

        if (position.isLong) {
            return ((currentMarketValue - averagePositionPrice) * position.size, position.collateral / (currentMarketValue * position.borrowedValue));
        } else {
            return ((averagePositionPrice - currentMarketValue) * position.size, position.collateral / (currentMarketValue * position.borrowedValue));
        }
    }

}