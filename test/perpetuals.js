const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PerpetualProtocol", function () {
  let PerpetualProtocol, perpetualProtocol, MockERC20, mockUSDC, MockPriceOracle, mockPriceOracle, MockVault, mockVault;
  let owner, user1, user2;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // Deploy mock USDC
    MockERC20 = await ethers.getContractFactory("MockERC20");
    mockUSDC = await MockERC20.deploy("Mock USDC", "mUSDC", ethers.parseUnits("1000000", 6));

    // Deploy mock PriceOracle
    MockPriceOracle = await ethers.getContractFactory("MockPriceOracle");
    mockPriceOracle = await MockPriceOracle.deploy();

    // Deploy mock Vault
    MockVault = await ethers.getContractFactory("MockVault");
    mockVault = await MockVault.deploy(mockUSDC.target);

    console.log(mockPriceOracle.target, mockUSDC.target, mockVault.target)

    // Deploy PerpetualProtocol
    PerpetualProtocol = await ethers.getContractFactory("PerpetualProtocol");
    perpetualProtocol = await PerpetualProtocol.deploy(mockUSDC.target, mockVault.target, mockPriceOracle.target);

    console.log("perpetual , " , perpetualProtocol.target)

    // Set up initial balances and approvals
    await mockUSDC.transfer(user1.address, ethers.parseUnits("10000", 6));
    await mockUSDC.transfer(user2.address, ethers.parseUnits("10000", 6));
    await mockUSDC.connect(user1).approve(perpetualProtocol.target, ethers.MaxUint256);
    await mockUSDC.connect(user2).approve(perpetualProtocol.target, ethers.MaxUint256);

    // Set initial prices
    await mockPriceOracle.setPrice("BTC", ethers.parseUnits("50000", 8)); // $50,000 per BTC
    await mockPriceOracle.setPrice("USDC", ethers.parseUnits("1", 8)); // $1 per USDC
  });

  describe("Open Position", function () {
    it("Should open a long position", async function () {
      await perpetualProtocol.connect(user1).openPosition(
        ethers.parseUnits("1", 18), // 1 BTC
        ethers.parseUnits("10000", 6), // 10,000 USDC collateral
        true // long position
      );

      const position = await perpetualProtocol.positions(user1.address, 1);
      expect(position.isOpen).to.be.true;
      expect(position.isLong).to.be.true;
      expect(position.size).to.equal(ethers.parseUnits("1", 18));
      expect(position.collateral).to.equal(ethers.parseUnits("10000", 6));
    });

    it("Should open a short position", async function () {
      await perpetualProtocol.connect(user1).openPosition(
        ethers.parseUnits("1", 18), // 1 BTC
        ethers.parseUnits("10000", 6), // 10,000 USDC collateral
        false // short position
      );

      const position = await perpetualProtocol.positions(user1.address, 1);
      expect(position.isOpen).to.be.true;
      expect(position.isLong).to.be.false;
      expect(position.size).to.equal(ethers.parseUnits("1", 18));
      expect(position.collateral).to.equal(ethers.parseUnits("10000", 6));
    });

    it("Should fail to open a position with insufficient collateral", async function () {
      await expect(
        perpetualProtocol.connect(user1).openPosition(
          ethers.parseUnits("1", 18), // 1 BTC
          ethers.parseUnits("100", 6), // 100 USDC collateral (insufficient)
          true
        )
      ).to.be.revertedWith("Insufficient collateral");
    });

    it("Should fail to open a position with excessive leverage", async function () {
      await expect(
        perpetualProtocol.connect(user1).openPosition(
          ethers.parseUnits("10", 18), // 10 BTC
          ethers.parseUnits("10000", 6), // 10,000 USDC collateral (50x leverage)
          true
        )
      ).to.be.revertedWith("Exceeds maximum leverage");
    });

    it("Should fail to open a position with zero size", async function () {
      await expect(
        perpetualProtocol.connect(user1).openPosition(
          ethers.parseUnits("0", 18), // 0 BTC
          ethers.parseUnits("10000", 6), // 10,000 USDC collateral
          true
        )
      ).to.be.revertedWith("Invalid position size");
    });

    it("Should fail to open a position with zero collateral", async function () {
      await expect(
        perpetualProtocol.connect(user1).openPosition(
          ethers.parseUnits("1", 18), // 1 BTC
          ethers.parseUnits("0", 6), // 0 USDC collateral
          true
        )
      ).to.be.revertedWith("Invalid collateral amount");
    });

    it("Should emit PositionOpened event", async function () {
      await expect(perpetualProtocol.connect(user1).openPosition(
        ethers.parseUnits("1", 18),
        ethers.parseUnits("10000", 6),
        true
      )).to.emit(perpetualProtocol, "PositionOpened")
        .withArgs(user1.address, 1, ethers.parseUnits("1", 18), ethers.parseUnits("10000", 6), true);
    });
  });
});