// SPDX-License-Identifier: MIT

pragma solidity ^0.8.33;

import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";

contract Vault {
    /*//////////////////////////////////////////////////////////////
                             Errors
    //////////////////////////////////////////////////////////////*/
    error Vault__RedeemFailed();
    error Vault__MustBeGreaterThanZero();

    /*//////////////////////////////////////////////////////////////
                               State Variables
      //////////////////////////////////////////////////////////////*/

    IRebaseToken private immutable i_rebaseToken;

    /*//////////////////////////////////////////////////////////////
                             Events
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    constructor(IRebaseToken _rebaseTokenAddress) {
        require(address(_rebaseTokenAddress) != address(0), "Must not be Zero Address");
        i_rebaseToken = _rebaseTokenAddress;
    }

    /*//////////////////////////////////////////////////////////////
                             External Functions
    //////////////////////////////////////////////////////////////*/

    receive() external payable {}

    /// @notice Allows a user to deposit ETH and receive a similar amount of RebaseTokens (1:1 peg)
    function deposit() external payable {
        uint256 amountToMint = msg.value;

        if (amountToMint == 0) {
            revert Vault__MustBeGreaterThanZero();
        }
        emit Deposit(msg.sender, amountToMint);

        i_rebaseToken.mint(msg.sender, amountToMint);
    }

    /// @notice Allows a user to burn their Rebase Token and receive a corresponding amount of ETH (1:1 peg)
    /// @param _amount The amount of tokens to burn/redeem
    function redeem(uint256 _amount) external {
        uint256 redeemAmount = _amount;

        if (_amount == type(uint256).max) {
            // redeem entire balance of sender by convention
            redeemAmount = i_rebaseToken.balanceOf(msg.sender);
        }

        if (redeemAmount == 0) {
            revert Vault__MustBeGreaterThanZero();
        }

        emit Redeem(msg.sender, redeemAmount);

        i_rebaseToken.burn(msg.sender, _amount);

        (bool sent,) = payable(msg.sender).call{value: redeemAmount}("");

        if (!sent) {
            revert Vault__RedeemFailed();
        }
    }

    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}
