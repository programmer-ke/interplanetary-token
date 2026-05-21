// SPDX-License-Identifier: MIT

pragma solidity ^0.8.33;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {Vault} from "src/Vault.sol";
import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);

        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));

        rebaseToken.grantMintAndBurnRole(address(vault));

        vm.stopPrank();
    }

    function testInterestAccruesLinearlyAfterDeposit(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        vm.startPrank(user);
        vm.deal(user, amount);

        // user deposits
        vault.deposit{value: amount}();
        uint256 initialBalance = rebaseToken.balanceOf(user);

        // simulate time travel forward
        uint256 timeDelta = 1 hours;

        vm.warp(block.timestamp + timeDelta);
        uint256 balanceAfterFirstWarp = rebaseToken.balanceOf(user);
        uint256 interestAfterFirstWarp = balanceAfterFirstWarp - initialBalance;

        // second time travel
        vm.warp(block.timestamp + timeDelta);
        uint256 balanceAfterSecondWarp = rebaseToken.balanceOf(user);
        uint256 interestAfterSecondWarp = balanceAfterSecondWarp - balanceAfterFirstWarp;

        assertEq(initialBalance, amount);
        assertApproxEqAbs(
            interestAfterFirstWarp, interestAfterSecondWarp, 1, "Interest Accrual Is Not Linear"
        );

        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);

        // user deposits
        vault.deposit{value: amount}();
        assertEq(user.balance, 0);
        assertEq(rebaseToken.balanceOf(user), amount);

        vault.redeem(type(uint256).max);
        assertEq(user.balance, amount);
        assertEq(rebaseToken.balanceOf(user), 0);
        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 amount, uint256 time) public {
        amount = bound(amount, 1e5, type(uint96).max);
        time = bound(time, 1, type(uint96).max);

        vm.deal(user, amount);
        vm.prank(user);

        // user deposits
        vault.deposit{value: amount}();
        uint256 initialBalance = rebaseToken.balanceOf(user);
        assertEq(initialBalance, amount);

        // warp time
        vm.warp(block.timestamp + time);
        uint256 finalBalance = rebaseToken.balanceOf(user);

        // ensure vault can pay additional interest
        uint256 additionalInterest = finalBalance - initialBalance;
        vm.deal(owner, additionalInterest);
        vm.prank(owner);
        addRewardsToVault(additionalInterest);

        vm.prank(user);
        vault.redeem(type(uint256).max);
        assertEq(user.balance, amount + additionalInterest);
        assertEq(rebaseToken.balanceOf(user), 0);
    }

    function testTransfer(uint256 amount, uint256 amountToTransfer) public {
        amount = bound(amount, 1e5, type(uint96).max);
        amountToTransfer = bound(amountToTransfer, 1e4, amount);

        vm.deal(user, amount);

        // user deposits into contract
        vm.prank(user);
        vault.deposit{value: amount}();

        // owner lowers interest rate
        uint256 originalInterestRate = rebaseToken.getInterestRate();
        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        assertLt(rebaseToken.getInterestRate(), originalInterestRate);

        address newUser = makeAddr("newUser");

        vm.prank(user);
        rebaseToken.transfer(newUser, amountToTransfer);

        // confirm expected balances
        assertEq(rebaseToken.balanceOf(newUser), amountToTransfer);
        assertEq(rebaseToken.balanceOf(user), amount - amountToTransfer);

        // check that new user inherited sender's original interest rate
        assertEq(rebaseToken.getUserInterestRate(newUser), rebaseToken.getUserInterestRate(user));
        assertEq(rebaseToken.getUserInterestRate(newUser), originalInterestRate);
    }

    function testGetPrincipalAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);

        // user deposits into contract
        vm.prank(user);
        vault.deposit{value: amount}();

        assertEq(rebaseToken.principalBalanceOf(user), amount);

        // warp time
        vm.warp(block.timestamp + 1 days);

        // principal balance remains
        assertEq(rebaseToken.principalBalanceOf(user), amount);

        // balance inclusive of interest should be greater
        assertGt(rebaseToken.balanceOf(user), amount);
    }

    function testNonOwnerCannotSetInterestRate(uint256 newInterestRate) public {
        newInterestRate = bound(newInterestRate, 0, rebaseToken.getInterestRate());

        vm.prank(user);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testUnauthorizedCannotCallMintAndBurn() public {
        uint256 interestRate = rebaseToken.getInterestRate();
        vm.prank(user);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.mint(user, 1 ether, interestRate);

        vm.prank(user);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.burn(user, 1 ether);
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success,) = payable(address(vault)).call{value: rewardAmount}("");
        require(success, "Failed to deposit rewards!");
    }
}
