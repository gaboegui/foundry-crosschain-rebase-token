// SPDX-License-Identifier: MIT
/**
 * @title Fuzzy Rebase Token Test
 * @author Gabriel Eguiguren P.
 * @notice This test suite validates the functionality of the RebaseToken and Vault
 */
pragma solidity ^0.8.27;

import { Test , console } from "forge-std/Test.sol";
import { RebaseToken } from "../../src/RebaseToken.sol";
import { IRebaseToken } from "../../src/interfaces/IRebaseToken.sol";
import { Vault } from "../../src/Vault.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";


contract RebaseTokenTest is Test {

    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    address public user2 = makeAddr("user2");

    /**
     * @dev Sets up the test environment.
     *      - Deploys RebaseToken and Vault contracts.
     *      - Grants mint and burn roles to the Vault.
     */
    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken))); 
        rebaseToken.grantMintAndBurnRole(address(vault));  //set the vault as the minter
        vm.stopPrank();
    }

    /**
     * @dev Adds rewards to the vault.
     * @param rewardAmount The amount of rewards to add.
     */
    function addRewardsToVault(uint256 rewardAmount) public {
        // founding the vault with rewards
        (bool success,) = payable(address(vault)).call{value: rewardAmount}(""); 
    }

    // Fuzzy test, the amount will vary between 1e5 and 1e18
    /**
     * @dev Tests that the interest rate is linear over time.
     *      - Deposits a fuzzed amount.
     *      - Warps time forward in two equal intervals.
     *      - Asserts that the interest gained in each interval is approximately equal.
     * @param amount The fuzzed amount to deposit.
     */
    function testDepositInterestRateIsLinear(uint256 amount) public {
        //vm.assume(amount > 1e5); // fuzz
        amount = bound(amount, 1e5, 1e18);  // fuzz
        vm.startPrank(user);
        vm.deal(user, amount);  // found the user
        // deposit user into vault
        vault.deposit{value: amount}();
        uint256 startBalance = rebaseToken.balanceOf(user);
        assertEq(startBalance, amount);
        // warp the time and check balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        assert(middleBalance > startBalance);
        // warp the time and check balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        assert(endBalance > middleBalance);
        // because the same period has passed, the interest gained shoud be equal to the balance gained
        // due truncation aprox we set a tolerance of 1 wei diference in calcs
        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);
        vm.stopPrank();    
    }

    /**
     * @dev Tests depositing and immediately redeeming the full amount.
     *      - Deposits a fuzzed amount.
     *      - Redeems the maximum possible amount.
     *      - Asserts that the user's token balance is 0 and their ETH balance is restored.
     * @param amount The fuzzed amount to deposit.
     */
    function testDepositAndRedeemInmediatly(uint256 amount) public {
        amount = bound(amount, 1e5, 1e18);
        
        vm.startPrank(user);
        vm.deal(user, amount);  // found the user
        // deposit user into vault
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount); 
        // now redeem
        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(user), 0);  // check the balance of rebase token
        assertEq(address(user).balance, amount); // check the balance of the user in ether
        vm.stopPrank();
    }

    /**
     * @dev Tests redeeming after a period of time has passed.
     *      - Deposits a fuzzed amount.
     *      - Warps time forward by a fuzzed duration.
     *      - Adds rewards to the vault to cover the interest.
     *      - Redeems the full balance.
     *      - Asserts that the user's final ETH balance matches their token balance and is greater than the initial deposit.
     * @param amount The fuzzed amount to deposit.
     * @param time The fuzzed time to warp forward.
     */
     function testRedeemAfterTimePassed(uint256 amount, uint16 time) public {
        amount = bound(amount, 1e5, 10e18);
        time = uint16(bound(time, 1000, type(uint16).max)); // at least 1000 seconds
                
        vm.deal(user, amount);  
        vm.prank(user);
        vault.deposit{value: amount}();

        vm.warp(time); // time passed
        uint256 newBalance = rebaseToken.balanceOf(user);
        // we add the exact necesary quantity of reward to the vault;
        vm.deal(owner, newBalance - amount);
        vm.prank(owner);
        addRewardsToVault(newBalance - amount);
        
        // now redeem
        vm.prank(user);
        vault.redeem(type(uint256).max);
     
        uint256 ethBalance = address(user).balance;
        assertEq(newBalance, ethBalance);
        assertGt(ethBalance, amount); // there should be a gained interest
    }

    /**
     * @dev Tests the transfer of rebase tokens between users.
     *      - Deposits a fuzzed amount for `user`.
     *      - Transfers a fuzzed amount from `user` to `user2`.
     *      - Asserts that the balances are updated correctly.
     *      - Asserts that both users retain the original (higher) interest rate after the transfer, even if the global rate is lowered.
     * @param amount The fuzzed amount for the initial deposit.
     * @param amountToSend The fuzzed amount to transfer.
     */
    function testTransfer(uint256 amount, uint256 amountToSend) public {
        // set the boundries 
        amount = bound(amount, 1e5 + 1e3 , type(uint128).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e3) ;
        // 1. deposit the total amount
        vm.deal(user, amount);  
        vm.prank(user);
        vault.deposit{value: amount}();

        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);
        assertEq(userBalance, amount);
        assertEq(user2Balance, 0);

        vm.prank(owner);
        rebaseToken.setInterestRate(4e10); // reduce the global interest rate to 

        // 2. transfer some amount to user2
        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);

        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 user2BalanceAferTransfer = rebaseToken.balanceOf(user2);

        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);
        assertEq(user2BalanceAferTransfer, amountToSend);

        // 3. check the interest rate have inherited 5e10 not 4e10
        assertEq(rebaseToken.getUserInterestRate(user), 5e10);
        assertEq(rebaseToken.getUserInterestRate(user2), 5e10);
    }

    /**
     * @dev Tests that a non-owner cannot set the interest rate.
     *      - Expects the transaction to revert with `OwnableUnauthorizedAccount`.
     * @param newInterestRate A fuzzed new interest rate.
     */
    function testAnyUserCanNotSetInterest(uint256 newInterestRate) public {
        vm.prank(user);
        // Because error OwnableUnauthorizedAccount(user) uses a paremeter we can use expectPartialRevert
        vm.expectPartialRevert(bytes4(Ownable.OwnableUnauthorizedAccount.selector));
        rebaseToken.setInterestRate(newInterestRate);
    }

    /**
     * @dev Tests that the interest rate can only be decreased by the owner.
     *      - Expects the transaction to revert with `RebaseToken__InterestRateCanOnlyDecrease` when trying to set a higher rate.
     * @param newInterestRate A fuzzed new interest rate, bounded to be >= the initial rate.
     */
    function testInterestCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 initialInterestRate = rebaseToken.getInterestRate();
        newInterestRate = bound(newInterestRate, initialInterestRate, type(uint96).max) ;

        vm.prank(owner);
        vm.expectPartialRevert(bytes4(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector));
        rebaseToken.setInterestRate(newInterestRate);
        assertEq(rebaseToken.getInterestRate(), initialInterestRate);
        
    }
    
    /**
     * @dev Tests that a non-minter cannot call the mint function.
     *      - Expects the transaction to revert.
     */
    function testAnyUserCanNotCallMint() public {
        vm.prank(user);
        vm.expectRevert();
        rebaseToken.mint(user, 100, rebaseToken.getUserInterestRate(user));
    }

    /**
     * @dev Tests that a non-burner cannot call the burn function.
     *      - Expects the transaction to revert.
     */
    function testAnyUserCanNotCallBurn() public {
        vm.prank(user);
        vm.expectRevert();
        rebaseToken.burn(user, 100);
    }

    /**
     * @dev Tests the `principleBalanceOf` function.
     *      - Deposits a fuzzed amount.
     *      - Asserts that the principle balance equals the deposited amount.
     *      - Warps time forward and asserts that the principle balance remains unchanged.
     * @param amount The fuzzed amount to deposit.
     */
    function testGetPrincipleBalance(uint256 amount) public {
        // set the boundries 
        amount = bound(amount, 1e5, type(uint96).max);
        // 1. deposit the total amount 
        vm.deal(user, amount);  
        vm.prank(user);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.principleBalanceOf(user), amount);

        //because principleBalanceOf dont take account the interest should be the same after some time
        vm.warp(block.timestamp + 1 hours);
        assertEq(rebaseToken.principleBalanceOf(user), amount);
    }

    function testGetRebaseTokenAddress() public {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }

}