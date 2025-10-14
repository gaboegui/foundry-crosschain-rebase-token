// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

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

    function test_InitialState() public {
        assertEq(rebaseToken.owner(), owner);
        assertEq(rebaseToken.name(), "Rebase Token");
        assertEq(rebaseToken.symbol(), "RBT");
        assertEq(rebaseToken.getInterestRate(), INTEREST_RATE);
    }

    function test_grantMintAndBurnRole() public {
        assertTrue(rebaseToken.hasRole(MINT_AND_BURN_ROLE, minter));
    }

    function test_fail_grantMintAndBurnRole_NotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        rebaseToken.grantMintAndBurnRole(user2);
    }

    function test_setInterestRate() public {
        uint256 newInterestRate = 4e10;
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit InterestRateSet(newInterestRate);
        rebaseToken.setInterestRate(newInterestRate);
        assertEq(rebaseToken.getInterestRate(), newInterestRate);
    }

    function test_fail_setInterestRate_NotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        rebaseToken.setInterestRate(4e10);
    }

    function test_fail_setInterestRate_RateNotLower() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector, INTEREST_RATE + 1, INTEREST_RATE));
        rebaseToken.setInterestRate(INTEREST_RATE + 1);
    }

    function test_mint() public {
        uint256 amount = 1000 * PRECISION_FACTOR;
        vm.prank(minter);
        rebaseToken.mint(user1, amount, rebaseToken.getUserInterestRate(user1));

        assertEq(rebaseToken.principleBalanceOf(user1), amount);
        assertEq(rebaseToken.getUserInterestRate(user1), rebaseToken.getInterestRate());
    }

    function test_fail_mint_NotMinter() public {
        vm.prank(user1);
        vm.expectRevert();
        rebaseToken.mint(user1, 1000, rebaseToken.getUserInterestRate(user1));
    }

    function test_burn() public {
        uint256 mintAmount = 1000 * PRECISION_FACTOR;
        vm.prank(minter);
        rebaseToken.mint(user1, mintAmount, rebaseToken.getUserInterestRate(user1));

        uint256 burnAmount = 200 * PRECISION_FACTOR;
        vm.prank(minter);
        rebaseToken.burn(user1, burnAmount);

        assertEq(rebaseToken.principleBalanceOf(user1), mintAmount - burnAmount);
    }

    function test_fail_burn_NotMinter() public {
        vm.prank(user1);
        vm.expectRevert();
        rebaseToken.burn(user1, 100);
    }
    
    function test_burn_max() public {
        uint256 mintAmount = 1000 * PRECISION_FACTOR;
        vm.prank(minter);
        rebaseToken.mint(user1, mintAmount, rebaseToken.getUserInterestRate(user1));

        vm.warp(block.timestamp + 100); // 100 seconds pass

        vm.prank(minter);
        rebaseToken.burn(user1, type(uint256).max);

        assertEq(rebaseToken.balanceOf(user1), 0);
    }

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

    function test_principleBalanceOf() public {
        uint256 mintAmount = 1000 * PRECISION_FACTOR;
        vm.prank(minter);
        rebaseToken.mint(user1, mintAmount, rebaseToken.getUserInterestRate(user1));

        vm.warp(block.timestamp + 100);

        assertEq(rebaseToken.principleBalanceOf(user1), mintAmount);
    }

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
