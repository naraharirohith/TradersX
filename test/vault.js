const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LiquidityVault", function () {
    let LiquidityVault, liquidityVault, MockToken, mockToken;
    let owner, user1, user2
    const initialSupply = ethers.parseEther("1000000");

    console.log(initialSupply);

    beforeEach(async function () {
        [owner, user1, user2] = await ethers.getSigners();

        // Deploy mock ERC20 token
        MockToken = await ethers.getContractFactory("MockERC20");
        mockToken = await MockToken.deploy("Mock Token", "MTK", initialSupply);
        // await MockToken.waitForDeployment();

        console.log(MockToken.target);

        // Deploy LiquidityVault
        LiquidityVault = await ethers.getContractFactory("LiquidityVault");
        liquidityVault = await LiquidityVault.deploy(mockToken.target);
        // await liquidityVault.waitForDeployment();

        console.log(liquidityVault.target);

        // Approve LiquidityVault to spend tokens
        await mockToken.approve(liquidityVault.target, ethers.MaxUint256);
        await mockToken.connect(user1).approve(liquidityVault.target, ethers.MaxUint256);
        await mockToken.connect(user2).approve(liquidityVault.target, ethers.MaxUint256);

        // Transfer some tokens to users for testing
        await mockToken.transfer(user1.address, ethers.parseEther("10000"));
        await mockToken.transfer(user2.address, ethers.parseEther("10000"));
    });

    describe("Deposit", function () {
        it("Should deposit assets and mint shares", async function () {
          const depositAmount = ethers.parseEther("1000");
          await expect(liquidityVault.connect(user1).deposit(depositAmount, user1.address))
            .to.emit(liquidityVault, "CollateralLocked")
            .withArgs(user1.address, depositAmount);
    
          expect(await liquidityVault.balanceOf(user1.address)).to.equal(depositAmount);
          expect(await liquidityVault.lockedCollateral(user1.address)).to.equal(depositAmount);
        });
      });

      describe("Withdraw", function () {
        it("Should withdraw assets and burn shares", async function () {
          const depositAmount = ethers.parseEther("1000");
          await liquidityVault.connect(user1).deposit(depositAmount, user1.address);
      
          const withdrawAmount = ethers.parseEther("500");
          await expect(liquidityVault.connect(user1).withdraw(withdrawAmount, user1.address, user1.address))
            .to.emit(liquidityVault, "CollateralUnlocked")
            .withArgs(user1.address, withdrawAmount);
      
          expect(await liquidityVault.balanceOf(user1.address)).to.equal(depositAmount - withdrawAmount);
          expect(await liquidityVault.lockedCollateral(user1.address)).to.equal(depositAmount - withdrawAmount);
        });
      
        it("Should not allow withdrawing more than locked collateral", async function () {
          const depositAmount = ethers.parseEther("1000");
          await liquidityVault.connect(user1).deposit(depositAmount, user1.address);
      
          const withdrawAmount = ethers.parseEther("1001");
          await expect(liquidityVault.connect(user1).withdraw(withdrawAmount, user1.address, user1.address))
            .to.be.revertedWith("Exceeds max withdraw amount");
        });
      });
    
      describe("MaxWithdraw", function () {
        it("Should return correct max withdraw amount", async function () {
          const depositAmount = ethers.parseEther("1000");
          await liquidityVault.connect(user1).deposit(depositAmount, user1.address);
      
          const maxWithdraw = await liquidityVault.maxWithdraw(user1.address);
          expect(maxWithdraw).to.equal(depositAmount);
      
          // Deposit more to increase available balance
          await liquidityVault.connect(user1).deposit(depositAmount, user1.address);
          const newMaxWithdraw = await liquidityVault.maxWithdraw(user1.address);
          expect(newMaxWithdraw).to.equal(depositAmount * BigInt(2));
        });
      
        it("Should limit max withdraw to locked collateral", async function () {
          const depositAmount = ethers.parseEther("1000");
          await liquidityVault.connect(user1).deposit(depositAmount, user1.address);
      
          // Simulate a situation where the vault has more assets than the user's locked collateral
          await mockToken.transfer(liquidityVault.target, depositAmount);
      
          const maxWithdraw = await liquidityVault.maxWithdraw(user1.address);
          expect(maxWithdraw).to.equal(depositAmount);
        });
      });
    
      describe("PreviewWithdraw", function () {
        it("Should return correct preview withdraw amount", async function () {
          const depositAmount = ethers.parseEther("1000");
          await liquidityVault.connect(user1).deposit(depositAmount, user1.address);
      
          const previewWithdraw = await liquidityVault.previewWithdraw(depositAmount);
          expect(previewWithdraw).to.equal(depositAmount);
      
          // Try to preview more than deposited
          const largeAmount = ethers.parseEther("2000");
          const largePreviewWithdraw = await liquidityVault.previewWithdraw(largeAmount);
          expect(largePreviewWithdraw).to.equal(depositAmount);
        });
      
        it("Should limit preview withdraw to locked collateral", async function () {
          const depositAmount = ethers.parseEther("1000");
          await liquidityVault.connect(user1).deposit(depositAmount, user1.address);
      
          // Simulate a situation where the vault has more assets than the user's locked collateral
          await mockToken.transfer(liquidityVault.target, depositAmount);
      
          const previewWithdraw = await liquidityVault.previewWithdraw(depositAmount);
          expect(previewWithdraw).to.equal(depositAmount);
      
          const largePreviewWithdraw = await liquidityVault.previewWithdraw(depositAmount.mul(2));
          expect(largePreviewWithdraw).to.equal(depositAmount);
        });
      });
    });