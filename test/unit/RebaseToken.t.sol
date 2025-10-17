// SPDX-License-Identifier: MIT
/**
 * @title Rebase Token Unit Test
 * @author Gabriel Eguiguren
 * @notice This test suite covers the unit tests for the RebaseToken contract,
 * ensuring all individual functions and state changes behave as expected.
 */
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { RebaseToken } from "../../src/RebaseToken.sol";

contract RebaseTokenUnitTest is Test {
    RebaseToken public rebaseToken;
    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public minter = makeAddr("minter");

    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private constant MIN_AMOUNT = 1000;
    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private constant INTEREST_RATE = (5 * PRECISION_FACTOR) / 1e8;

    event InterestRateSet(uint256 interestRate);

    /**
     * @notice Sets up the test environment by deploying the RebaseToken and assigning roles.
     */
    function setUp() public {
        vm.prank(owner);
        rebaseToken = new RebaseToken();

        vm.prank(owner);
        rebaseToken.grantMintAndBurnRole(minter);
    }

    /**
     * @notice Tests the initial state of the contract upon deployment.
     */
    function testInitialState() public view {
        assertEq(rebaseToken.owner(), owner);
        assertEq(rebaseToken.name(), "Rebase Token");
        assertEq(rebaseToken.symbol(), "RBT");
        assertEq(rebaseToken.getInterestRate(), INTEREST_RATE);
    }

    /**
     * @notice Tests that the mint and burn role can be granted successfully.
     */
    function testGrantMintAndBurnRole() public view {
        assertTrue(rebaseToken.hasRole(MINT_AND_BURN_ROLE, minter));
    }

    /**
     * @notice Tests that granting the mint and burn role fails if not called by the owner.
     */
    function testRevertIfMintAndBurnRoleNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        rebaseToken.grantMintAndBurnRole(user2);
    }

    /**
     * @notice Tests that the interest rate can be set successfully when decreased.
     * @dev New rate must be lower than current rate. Example: Initial rate 5e10, set to 4e10.
     */
    function testSetInterestRateSuccess() public {
        uint256 newRate = 4e10; // Lower than initial INTEREST_RATE (5e10)
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit InterestRateSet(newRate);
        rebaseToken.setInterestRate(newRate);
        assertEq(rebaseToken.getInterestRate(), newRate);
    }

    /**
     * @notice Tests that setting interest rate reverts if new rate is not lower.
     * @dev Reverts with RebaseToken__InterestRateCanOnlyDecrease. Example: Try to set 6e10 > 5e10.
     */
    function testSetInterestRateRevertIfNotDecreased() public {
        uint256 newRate = 6e10; // Higher than initial INTEREST_RATE (5e10)
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector, newRate, INTEREST_RATE));
        rebaseToken.setInterestRate(newRate);
    }

    /**
     * @notice Tests that setting interest rate fails if not called by owner.
     */
    function testSetInterestRateRevertIfNotOwner() public {
        uint256 newRate = 4e10;
        vm.prank(user1);
        vm.expectRevert();
        rebaseToken.setInterestRate(newRate);
    }

    /**
     * @notice Tests minting tokens successfully.
     * @dev Mints 1000 tokens to user1 with interest rate. Checks balance and user interest rate.
     */
    function testMintSuccess() public {
        uint256 amount = MIN_AMOUNT;
        uint256 userRate = INTEREST_RATE;
        vm.prank(minter);
        rebaseToken.mint(user1, amount, userRate);
        assertEq(rebaseToken.principleBalanceOf(user1), amount);
        assertEq(rebaseToken.getUserInterestRate(user1), userRate);
    }

    /**
     * @notice Tests that minting fails if not called by minter role.
     */
    function testMintRevertIfNotMinter() public {
        uint256 amount = MIN_AMOUNT;
        uint256 userRate = INTEREST_RATE;
        vm.prank(user1);
        vm.expectRevert();
        rebaseToken.mint(user1, amount, userRate);
    }

    /**
     * @notice Tests burning tokens successfully.
     * @dev First mint, then burn. Example: Mint 1000, burn 500, balance should be 500.
     */
    function testBurnSuccess() public {
        uint256 amount = MIN_AMOUNT;
        uint256 userRate = INTEREST_RATE;
        vm.prank(minter);
        rebaseToken.mint(user1, amount, userRate);
        vm.prank(minter);
        rebaseToken.burn(user1, amount / 2);
        assertEq(rebaseToken.principleBalanceOf(user1), amount / 2);
    }

    /**
     * @notice Tests burning max amount (type(uint256).max) burns all balance.
     * @dev Mints 1000, burns max, balance should be 0.
     */
    function testBurnMaxAmount() public {
        uint256 amount = MIN_AMOUNT;
        uint256 userRate = INTEREST_RATE;
        vm.prank(minter);
        rebaseToken.mint(user1, amount, userRate);
        vm.prank(minter);
        rebaseToken.burn(user1, type(uint256).max);
        assertEq(rebaseToken.principleBalanceOf(user1), 0);
    }

    /**
     * @notice Tests that burning fails if not called by minter role.
     */
    function testBurnRevertIfNotMinter() public {
        uint256 amount = MIN_AMOUNT;
        uint256 userRate = INTEREST_RATE;
        vm.prank(minter);
        rebaseToken.mint(user1, amount, userRate);
        vm.prank(user1);
        vm.expectRevert();
        rebaseToken.burn(user1, amount / 2);
    }

    /**
     * @notice Tests balanceOf includes accumulated interest.
     * @dev Since time doesn't pass in test, interest factor is 1. Balance should equal principle.
     * Arithmetic example: balance = principle * (PRECISION_FACTOR + (rate * time)) / PRECISION_FACTOR
     * With time=0, balance = principle * PRECISION_FACTOR / PRECISION_FACTOR = principle.
     */
    function testBalanceOfWithInterest() public {
        uint256 amount = MIN_AMOUNT;
        uint256 userRate = INTEREST_RATE;
        vm.prank(minter);
        rebaseToken.mint(user1, amount, userRate);
        // No time passed, so balanceOf should equal principleBalanceOf
        assertEq(rebaseToken.balanceOf(user1), rebaseToken.principleBalanceOf(user1));
    }

    /**
     * @notice Tests transfer function.
     * @dev Transfers 500 from user1 to user2. Checks balances and interest rates.
     */
    function testTransferSuccess() public {
        uint256 amount = MIN_AMOUNT;
        uint256 userRate = INTEREST_RATE;
        vm.prank(minter);
        rebaseToken.mint(user1, amount, userRate);
        vm.prank(user1);
        rebaseToken.transfer(user2, amount / 2);
        assertEq(rebaseToken.principleBalanceOf(user1), amount / 2);
        assertEq(rebaseToken.principleBalanceOf(user2), amount / 2);
        assertEq(rebaseToken.getUserInterestRate(user2), userRate); // Inherits rate
    }

    /**
     * @notice Tests transfer with max amount transfers all balance.
     */
    function testTransferMaxAmount() public {
        uint256 amount = MIN_AMOUNT;
        uint256 userRate = INTEREST_RATE;
        vm.prank(minter);
        rebaseToken.mint(user1, amount, userRate);
        vm.prank(user1);
        rebaseToken.transfer(user2, type(uint256).max);
        assertEq(rebaseToken.principleBalanceOf(user1), 0);
        assertEq(rebaseToken.principleBalanceOf(user2), amount);
    }

    /**
     * @notice Tests transferFrom function.
     * @dev Approves user2 to transfer from user1, then transfers.
     */
    function testTransferFromSuccess() public {
        uint256 amount = MIN_AMOUNT;
        uint256 userRate = INTEREST_RATE;
        vm.prank(minter);
        rebaseToken.mint(user1, amount, userRate);
        vm.prank(user1);
        rebaseToken.approve(user2, amount / 2);
        vm.prank(user2);
        rebaseToken.transferFrom(user1, user2, amount / 2);
        assertEq(rebaseToken.principleBalanceOf(user1), amount / 2);
        assertEq(rebaseToken.principleBalanceOf(user2), amount / 2);
    }

    /**
     * @notice Tests getUserInterestRate returns correct rate.
     */
    function testGetUserInterestRate() public {
        uint256 userRate = INTEREST_RATE;
        vm.prank(minter);
        rebaseToken.mint(user1, MIN_AMOUNT, userRate);
        assertEq(rebaseToken.getUserInterestRate(user1), userRate);
    }

    /**
     * @notice Tests principleBalanceOf returns balance without interest.
     */
    function testPrincipleBalanceOf() public {
        uint256 amount = MIN_AMOUNT;
        vm.prank(minter);
        rebaseToken.mint(user1, amount, INTEREST_RATE);
        assertEq(rebaseToken.principleBalanceOf(user1), amount);
    }

    /**
     * @notice Tests balanceOf includes accumulated interest over time.
     * @dev Warps time by 1 second. Balance should increase by interest.
     * Arithmetic example: Initial balance 1e18, rate 5e10/sec, time 1s.
     * Interest factor = PRECISION_FACTOR + (rate * time) = 1e18 + 5e10 = 1000000500000000000
     * New balance = 1e18 * 1000000500000000000 / 1e18 = 1e18 + 5e10
     */
    function testBalanceOfWithTimePassed() public {
        uint256 amount = 1e18; // 1 ether to avoid lossing decimals
        uint256 userRate = INTEREST_RATE;
        vm.prank(minter);
        rebaseToken.mint(user1, amount, userRate);
        uint256 initialBalance = rebaseToken.balanceOf(user1);
        vm.warp(block.timestamp + 1); // Advance time by 1 second
        uint256 expectedInterestFactor = PRECISION_FACTOR + (userRate * 1);
        uint256 expectedBalance = (amount * expectedInterestFactor) / PRECISION_FACTOR;
        assertEq(rebaseToken.balanceOf(user1), expectedBalance);
        assertGt(rebaseToken.balanceOf(user1), initialBalance);
    }

    /**
     * @notice Tests transfer mints accumulated interest for sender and recipient.
     * @dev Mints to user1, warps time, transfers. Sender's interest should be minted, recipient inherits rate.
     * Arithmetic example: Mint 1e18, time 1s, transfer 5e17. Sender principle after: (1e18 + 5e10) - 5e17 = 5e17 + 5e10
     */
    function testTransferWithInterestAccumulation() public {
        uint256 amount = 1e18;
        uint256 userRate = INTEREST_RATE;
        vm.prank(minter);
        rebaseToken.mint(user1, amount, userRate);
        vm.warp(block.timestamp + 1);
        vm.prank(user1);
        rebaseToken.transfer(user2, amount / 2);
        uint256 expectedInterestFactor = PRECISION_FACTOR + (userRate * 1);
        uint256 expectedSenderBalance = ((amount * expectedInterestFactor) / PRECISION_FACTOR) - (amount / 2);
        assertEq(rebaseToken.principleBalanceOf(user1), expectedSenderBalance);
        assertEq(rebaseToken.principleBalanceOf(user2), amount / 2);
        assertEq(rebaseToken.getUserInterestRate(user2), userRate);
    }

    /**
     * @notice Tests transferFrom mints accumulated interest for sender and recipient.
     * @dev Similar to transfer, but via transferFrom.
     */
    function testTransferFromWithInterestAccumulation() public {
        uint256 amount = 1e18;
        uint256 userRate = INTEREST_RATE;
        vm.prank(minter);
        rebaseToken.mint(user1, amount, userRate);
        vm.warp(block.timestamp + 1);
        vm.prank(user1);
        rebaseToken.approve(user2, amount / 2);
        vm.prank(user2);
        rebaseToken.transferFrom(user1, user2, amount / 2);
        uint256 expectedInterestFactor = PRECISION_FACTOR + (userRate * 1);
        uint256 expectedSenderBalance = ((amount * expectedInterestFactor) / PRECISION_FACTOR) - (amount / 2);
        assertEq(rebaseToken.principleBalanceOf(user1), expectedSenderBalance);
        assertEq(rebaseToken.principleBalanceOf(user2), amount / 2);
    }

    /**
     * @notice Tests burn mints accumulated interest before burning.
     * @dev Mints, warps time, burns. Interest should be added to principle before burn.
     * Arithmetic example: Mint 1e18, time 1s, burn 5e17. Principle after: (1e18 + 5e10) - 5e17 = 5e17 + 5e10
     */
    function testBurnWithInterestAccumulation() public {
        uint256 amount = 1e18;
        uint256 userRate = INTEREST_RATE;
        vm.prank(minter);
        rebaseToken.mint(user1, amount, userRate);
        vm.warp(block.timestamp + 1);
        vm.prank(minter);
        rebaseToken.burn(user1, amount / 2);
        uint256 expectedInterestFactor = PRECISION_FACTOR + (userRate * 1);
        uint256 expectedPrinciple = ((amount * expectedInterestFactor) / PRECISION_FACTOR) - (amount / 2);
        assertEq(rebaseToken.principleBalanceOf(user1), expectedPrinciple);
    }

    /**
     * @notice Tests multiple mints accumulate correctly.
     * @dev Mint twice, check principle sums.
     */
    function testMultipleMints() public {
        uint256 amount1 = 1e18;
        uint256 amount2 = 2e18;
        uint256 userRate = INTEREST_RATE;
        vm.prank(minter);
        rebaseToken.mint(user1, amount1, userRate);
        vm.prank(minter);
        rebaseToken.mint(user1, amount2, userRate);
        assertEq(rebaseToken.principleBalanceOf(user1), amount1 + amount2);
    }

    /**
     * @notice Tests transfer to zero balance user inherits interest rate.
     * @dev Transfer to new user, check rate inheritance.
     */
    function testTransferToZeroBalanceInheritsRate() public {
        uint256 amount = 1e18;
        uint256 userRate = INTEREST_RATE;
        vm.prank(minter);
        rebaseToken.mint(user1, amount, userRate);
        vm.prank(user1);
        rebaseToken.transfer(user2, amount / 2);
        assertEq(rebaseToken.getUserInterestRate(user2), userRate);
    }

    /**
     * @notice Tests transfer max amount with interest.
     * @dev Similar to existing, but ensure interest is handled.
     */
    function testTransferMaxAmountWithInterest() public {
        uint256 amount = 1e18;
        uint256 userRate = INTEREST_RATE;
        vm.prank(minter);
        rebaseToken.mint(user1, amount, userRate);
        vm.warp(block.timestamp + 1);
        vm.prank(user1);
        rebaseToken.transfer(user2, type(uint256).max);
        uint256 expectedInterestFactor = PRECISION_FACTOR + (userRate * 1);
        uint256 expectedTransferred = (amount * expectedInterestFactor) / PRECISION_FACTOR;
        assertEq(rebaseToken.principleBalanceOf(user1), 0);
        assertEq(rebaseToken.principleBalanceOf(user2), expectedTransferred);
    }

    /**
     * @notice Tests burn max amount with interest.
     * @dev Burns all after interest accumulation.
     */
    function testBurnMaxAmountWithInterest() public {
        uint256 amount = 1e18;
        uint256 userRate = INTEREST_RATE;
        vm.prank(minter);
        rebaseToken.mint(user1, amount, userRate);
        vm.warp(block.timestamp + 1);
        vm.prank(minter);
        rebaseToken.burn(user1, type(uint256).max);
        assertEq(rebaseToken.principleBalanceOf(user1), 0);
    }
}
