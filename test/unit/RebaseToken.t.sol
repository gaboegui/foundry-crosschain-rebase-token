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

contract RebaseTokenTest is Test {
    RebaseToken public rebaseToken;
    address public owner;
    address public user1;
    address public user2;
    address public minter;

    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private constant INTEREST_RATE = (5 * PRECISION_FACTOR) / 1e8;

    event InterestRateSet(uint256 interestRate);

    /**
     * @notice Sets up the test environment by deploying the RebaseToken and assigning roles.
     */
    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        minter = makeAddr("minter");

        vm.prank(owner);
        rebaseToken = new RebaseToken();

        vm.prank(owner);
        rebaseToken.grantMintAndBurnRole(minter);
    }

    /**
     * @notice Tests the initial state of the contract upon deployment.
     */
    function test_InitialState() public {
        assertEq(rebaseToken.owner(), owner);
        assertEq(rebaseToken.name(), "Rebase Token");
        assertEq(rebaseToken.symbol(), "RBT");
        assertEq(rebaseToken.getInterestRate(), INTEREST_RATE);
    }

    /**
     * @notice Tests that the mint and burn role can be granted successfully.
     */
    function test_grantMintAndBurnRole() public {
        assertTrue(rebaseToken.hasRole(MINT_AND_BURN_ROLE, minter));
    }

    /**
     * @notice Tests that granting the mint and burn role fails if not called by the owner.
     */
    function test_fail_grantMintAndBurnRole_NotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        rebaseToken.grantMintAndBurnRole(user2);
    }

    /**
     * @notice Tests that the interest rate can be set successfully.
     */
    function test_setInterestRate() public {
        uint256 newInterestRate = 4e10;
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit InterestRateSet(newInterestRate);
        rebaseToken.setInterestRate(newInterestRate);
        assertEq(rebaseToken.getInterestRate(), newInterestRate);
    }

    /**
     * @notice Tests that setting the interest rate fails if not called by the owner.
     */
    function test_fail_setInterestRate_NotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        rebaseToken.setInterestRate(4e10);
    }

    /**
     * @notice Tests that setting the interest rate fails if the new rate is not lower.
     */
    function test_fail_setInterestRate_RateNotLower() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector, INTEREST_RATE + 1, INTEREST_RATE));
        rebaseToken.setInterestRate(INTEREST_RATE + 1);
    }

    /**
     * @notice Tests that tokens can be minted successfully.
     */
    function test_mint() public {
        uint256 amount = 1000 * PRECISION_FACTOR;
        vm.prank(minter);
        rebaseToken.mint(user1, amount, rebaseToken.getUserInterestRate(user1));

        assertEq(rebaseToken.principleBalanceOf(user1), amount);
        assertEq(rebaseToken.getUserInterestRate(user1), rebaseToken.getInterestRate());
    }

    /**
     * @notice Tests that minting fails if not called by a minter.
     */
    function test_fail_mint_NotMinter() public {
        vm.prank(user1);
        vm.expectRevert();
        rebaseToken.mint(user1, 1000, rebaseToken.getUserInterestRate(user1));
    }

    /**
     * @notice Tests that tokens can be burned successfully.
     */
    function test_burn() public {
        uint256 mintAmount = 1000 * PRECISION_FACTOR;
        vm.prank(minter);
        rebaseToken.mint(user1, mintAmount, rebaseToken.getUserInterestRate(user1));

        uint256 burnAmount = 200 * PRECISION_FACTOR;
        vm.prank(minter);
        rebaseToken.burn(user1, burnAmount);

        assertEq(rebaseToken.principleBalanceOf(user1), mintAmount - burnAmount);
    }

    /**
     * @notice Tests that burning fails if not called by a minter.
     */
    function test_fail_burn_NotMinter() public {
        vm.prank(user1);
        vm.expectRevert();
        rebaseToken.burn(user1, 100);
    }
    
    /**
     * @notice Tests burning the maximum amount of tokens.
     */
    function test_burn_max() public {
        uint256 mintAmount = 1000 * PRECISION_FACTOR;
        vm.prank(minter);
        rebaseToken.mint(user1, mintAmount, rebaseToken.getUserInterestRate(user1));

        vm.warp(block.timestamp + 100); // 100 seconds pass

        vm.prank(minter);
        rebaseToken.burn(user1, type(uint256).max);

        assertEq(rebaseToken.balanceOf(user1), 0);
    }

    /**
     * @notice Tests that the balance correctly includes accumulated interest.
     */
    function test_balanceOf_withInterest() public {
        uint256 mintAmount = 1000 * PRECISION_FACTOR;
        vm.prank(minter);
        rebaseToken.mint(user1, mintAmount, rebaseToken.getUserInterestRate(user1));

        uint256 timeToWarp = 100;
        vm.warp(block.timestamp + timeToWarp);

        uint256 interestRate = rebaseToken.getUserInterestRate(user1);
        uint256 expectedInterest = (mintAmount * (PRECISION_FACTOR + (interestRate * timeToWarp))) / PRECISION_FACTOR;
        
        assertEq(rebaseToken.balanceOf(user1), expectedInterest);
    }

    /**
     * @notice Tests a simple token transfer.
     */
    function test_transfer() public {
        uint256 mintAmount = 1000 * PRECISION_FACTOR;
        vm.prank(minter);
        rebaseToken.mint(user1, mintAmount, rebaseToken.getUserInterestRate(user1));

        uint256 transferAmount = 300 * PRECISION_FACTOR;
        vm.prank(user1);
        rebaseToken.transfer(user2, transferAmount);

        assertEq(rebaseToken.principleBalanceOf(user2), transferAmount);
        assertEq(rebaseToken.getUserInterestRate(user2), rebaseToken.getUserInterestRate(user1));
    }

    /**
     * @notice Tests transferring the maximum amount of tokens.
     */
    function test_transfer_max() public {
        uint256 mintAmount = 1000 * PRECISION_FACTOR;
        vm.prank(minter);
        rebaseToken.mint(user1, mintAmount, rebaseToken.getUserInterestRate(user1));

        vm.warp(block.timestamp + 100);

        uint256 user1Balance = rebaseToken.balanceOf(user1);

        vm.prank(user1);
        rebaseToken.transfer(user2, type(uint256).max);

        assertEq(rebaseToken.balanceOf(user2), user1Balance);
        assertEq(rebaseToken.balanceOf(user1), 0);
    }

    /**
     * @notice Tests the transferFrom function.
     */
    function test_transferFrom() public {
        uint256 mintAmount = 1000 * PRECISION_FACTOR;
        vm.prank(minter);
        rebaseToken.mint(user1, mintAmount, rebaseToken.getUserInterestRate(user1));

        uint256 approveAmount = 500 * PRECISION_FACTOR;
        vm.prank(user1);
        rebaseToken.approve(user2, approveAmount);

        assertEq(rebaseToken.allowance(user1, user2), approveAmount);

        uint256 transferAmount = 300 * PRECISION_FACTOR;
        vm.prank(user2);
        rebaseToken.transferFrom(user1, user2, transferAmount);

        assertEq(rebaseToken.principleBalanceOf(user2), transferAmount);
    }

    /**
     * @notice Tests transferring the maximum amount of tokens using transferFrom.
     */
    function test_transferFrom_max() public {
        uint256 mintAmount = 1000 * PRECISION_FACTOR;
        vm.prank(minter);
        rebaseToken.mint(user1, mintAmount, rebaseToken.getUserInterestRate(user1));

        vm.warp(block.timestamp + 100);

        uint256 user1Balance = rebaseToken.balanceOf(user1);

        vm.prank(user1);
        rebaseToken.approve(user2, type(uint256).max);

        vm.prank(user2);
        rebaseToken.transferFrom(user1, user2, type(uint256).max);

        assertEq(rebaseToken.balanceOf(user2), user1Balance);
        assertEq(rebaseToken.balanceOf(user1), 0);
    }

    /**
     * @notice Tests that the principle balance is not affected by interest accrual.
     */
    function test_principleBalanceOf() public {
        uint256 mintAmount = 1000 * PRECISION_FACTOR;
        vm.prank(minter);
        rebaseToken.mint(user1, mintAmount, rebaseToken.getUserInterestRate(user1));

        vm.warp(block.timestamp + 100);

        assertEq(rebaseToken.principleBalanceOf(user1), mintAmount);
    }

    /**
     * @notice Tests the interest calculation over time with multiple mints.
     */
    function test_interestCalculation() public {
        // 1. Mint 1000 tokens to user1
        uint256 mintAmount = 1000 * PRECISION_FACTOR;
        vm.prank(minter);
        rebaseToken.mint(user1, mintAmount, rebaseToken.getUserInterestRate(user1));
        assertEq(rebaseToken.balanceOf(user1), mintAmount);

        // 2. Warp time by 100 seconds
        uint256 timeToWarp1 = 100;
        vm.warp(block.timestamp + timeToWarp1);

        // Calculation: balance = principle * (1 + interestRate * time)
        // interestRate is per second
        uint256 interestRate = rebaseToken.getUserInterestRate(user1);
        uint256 expectedBalance1 = (mintAmount * (PRECISION_FACTOR + (interestRate * timeToWarp1))) / PRECISION_FACTOR;
        assertEq(rebaseToken.balanceOf(user1), expectedBalance1);

        // 3. Mint another 500 tokens to user1. This should trigger a rebase.
        uint256 mintAmount2 = 500 * PRECISION_FACTOR;
        vm.prank(minter);
        rebaseToken.mint(user1, mintAmount2, rebaseToken.getUserInterestRate(user1));

        // The principle balance should now be the previous balance with interest + the new mint amount
        uint256 expectedPrincipleAfterRebase = expectedBalance1 + mintAmount2;
        assertEq(rebaseToken.principleBalanceOf(user1), expectedPrincipleAfterRebase);

        // 4. Warp time again by 50 seconds
        uint256 timeToWarp2 = 50;
        vm.warp(block.timestamp + timeToWarp2);

        // Calculation for the next period
        uint256 expectedBalance2 = (expectedPrincipleAfterRebase * (PRECISION_FACTOR + (interestRate * timeToWarp2))) / PRECISION_FACTOR;
        assertEq(rebaseToken.balanceOf(user1), expectedBalance2);
    }

    /**
     * @notice Tests that a recipient with no balance inherits the sender's interest rate.
     */
    function test_transfer_recipient_inherits_interest() public {
        uint256 mintAmount = 1000 * PRECISION_FACTOR;
        vm.prank(minter);
        rebaseToken.mint(user1, mintAmount, rebaseToken.getUserInterestRate(user1));

        // User2 has no tokens and no interest rate
        assertEq(rebaseToken.balanceOf(user2), 0);
        assertEq(rebaseToken.getUserInterestRate(user2), 0);

        uint256 transferAmount = 400 * PRECISION_FACTOR;
        vm.prank(user1);
        rebaseToken.transfer(user2, transferAmount);

        // User2 should inherit user1's interest rate
        assertEq(rebaseToken.getUserInterestRate(user2), rebaseToken.getUserInterestRate(user1));
    }

    /**
     * @notice Tests that a recipient with an existing balance keeps their own interest rate after a transfer.
     */
    function test_transfer_recipient_keeps_interest() public {
        // Mint to user1
        uint256 mintAmount1 = 1000 * PRECISION_FACTOR;
        vm.prank(minter);
        rebaseToken.mint(user1, mintAmount1, rebaseToken.getUserInterestRate(user1));
        uint256 user1InterestRate = rebaseToken.getUserInterestRate(user1);

        // Lower interest rate and mint to user2
        uint256 newInterestRate = 4e10;
        vm.prank(owner);
        rebaseToken.setInterestRate(newInterestRate);

        uint256 mintAmount2 = 500 * PRECISION_FACTOR;
        vm.prank(minter);
        rebaseToken.mint(user2, mintAmount2, rebaseToken.getUserInterestRate(user2));
        uint256 user2InterestRate = rebaseToken.getUserInterestRate(user2);

        assertNotEq(user1InterestRate, user2InterestRate);

        // Transfer from user1 to user2
        uint256 transferAmount = 200 * PRECISION_FACTOR;
        vm.prank(user1);
        rebaseToken.transfer(user2, transferAmount);

        // User2 should keep their original, lower interest rate
        assertEq(rebaseToken.getUserInterestRate(user2), user2InterestRate);
    }
}