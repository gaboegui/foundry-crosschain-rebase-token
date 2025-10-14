// SPDX-License-Identifier: MIT
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

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken))); 
        rebaseToken.grantMintAndBurnRole(address(vault));  //set the vault as the minter
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        // founding the vault with rewards
        (bool success,) = payable(address(vault)).call{value: rewardAmount}(""); 
    }

    // Fuzzy test, the amount will vary between 1e5 and 1e18
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

    function testAnyUserCanNotSetInterest(uint256 newInterestRate) public {
        vm.prank(user);
        // Because error OwnableUnauthorizedAccount(user) uses a paremeter we can use expectPartialRevert
        vm.expectPartialRevert(bytes4(Ownable.OwnableUnauthorizedAccount.selector));
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testInterestCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 initialInterestRate = rebaseToken.getInterestRate();
        newInterestRate = bound(newInterestRate, initialInterestRate, type(uint96).max) ;

        vm.prank(owner);
        vm.expectPartialRevert(bytes4(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector));
        rebaseToken.setInterestRate(newInterestRate);
        assertEq(rebaseToken.getInterestRate(), initialInterestRate);
        
    }
    
    function testAnyUserCanNotCallMint() public {
        vm.prank(user);
        vm.expectRevert();
        rebaseToken.mint(user, 100, rebaseToken.getUserInterestRate(user));
    }

    function testAnyUserCanNotCallBurn() public {
        vm.prank(user);
        vm.expectRevert();
        rebaseToken.burn(user, 100);
    }

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