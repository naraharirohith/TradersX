// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LiquidityVault is ERC4626 {
    // Track locked collateral for each user
    mapping(address => uint256) public lockedCollateral;

    address public tokenAddress;

    // Event emitted when collateral is locked
    event CollateralLocked(address indexed user, uint256 amount);

    // Event emitted when collateral is unlocked
    event CollateralUnlocked(address indexed user, uint256 amount);

    constructor(address assetAddress_) ERC4626(IERC20(assetAddress_)) ERC20("MyVaultShares", "MVS"){ }

    // Override deposit function to lock collateral
    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        uint256 shares = super.deposit(assets, receiver);
        lockedCollateral[receiver] += assets; // Lock collateral
        emit CollateralLocked(receiver, assets);
        return shares;
    }

    // Override withdraw function to handle locked collateral
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256) {
        require(assets <= maxWithdraw(owner), "Exceeds max withdraw amount");
        require(assets <= lockedCollateral[owner], "Cannot withdraw locked collateral");
        uint256 shares = super.withdraw(assets, receiver, owner);
        lockedCollateral[owner] -= assets; // Unlock collateral
        emit CollateralUnlocked(owner, assets);
        return shares;
    }

    // Override previewWithdraw function to consider locked collateral
    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        uint256 availableAssets = super.previewWithdraw(assets);
        uint256 lockedAssets = lockedCollateral[msg.sender];
        if (availableAssets > lockedAssets) {
            return availableAssets - lockedAssets;
        }
        return 0;
    }

    // Override maxWithdraw function to consider locked collateral
    // function maxWithdraw(address owner) public view override returns (uint256) {
    //     uint256 maxWithdrawAmount = super.maxWithdraw(owner);
    //     uint256 lockedAssets = lockedCollateral[owner];
    //     if (maxWithdrawAmount > lockedAssets) {
    //         return maxWithdrawAmount - lockedAssets;
    //     }
    //     return 0;
    // }

    // Override maxWithdraw function to consider locked collateral
    function maxWithdraw(address owner) public view override returns (uint256) {
        uint256 maxWithdrawAmount = super.maxWithdraw(owner);
        uint256 lockedAssets = lockedCollateral[owner];
        if (maxWithdrawAmount > lockedAssets) {
            return maxWithdrawAmount - lockedAssets;
        }
        return 0;
    }
}