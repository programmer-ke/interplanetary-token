// SPDX-License-Identifier: MIT

pragma solidity ^0.8.33;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

/// @title Interplanetary Token
/// @author Programmer KE
/// @notice A cross chain token where users deposit into a vault and
///   earn interest. Interest can only decrease with time.
///   Users lock in the global interest rate at the time of deposit.
contract RebaseToken is IRebaseToken, ERC20, Ownable, AccessControl {
    /*//////////////////////////////////////////////////////////////
                             Errors
    //////////////////////////////////////////////////////////////*/

    error RebaseToken__InterestCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    /*//////////////////////////////////////////////////////////////
                             State Variables
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private s_interestRate = 5e10;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    /*//////////////////////////////////////////////////////////////
                             Events
    //////////////////////////////////////////////////////////////*/

    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("Interplanetary Token", "IPT") Ownable(msg.sender) {}

    /*//////////////////////////////////////////////////////////////
                             External Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Set the global interest rate
    /// @param _newInterestRate The new interest rate to set
    /// @dev Interest rate can only decrease
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate > s_interestRate) {
            revert RebaseToken__InterestCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /// @notice Mints tokens to the user upon deposit
    /// @param _to The address to mint tokens to
    /// @param _amount The principal amount of tokens to mint
    /// @dev Also mints accrued interest and locks current global interest to the user
    function mint(address _to, uint256 _amount, uint256 _interestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = _interestRate;
        _mint(_to, _amount);
    }

    /// @notice Burns the user tokens
    ///   e.g. when withdrawing from vault of for cross-chain transfers
    /// @dev By convention, burns entire balance if amount is type(uint256).max
    /// @param _from The address who's tokens are being burnt
    /// @param _amount The amount of tokens to burn
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if (_amount == type(uint256).max) {
            // Amount of type(uint256).max indicates the current total balance by convention
            // This works around the token dust problem
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /// @notice Grant an account the mint and burn role as the owner
    /// @param _account The account to grant role to
    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /// @notice Returns the minted balance of the user excluding any pending accrued interest
    /// @param _user The address of the user balance to query
    function principalBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    /// @notice Returns the current global interest rate
    /// @return Global Interest Rate
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    /// @notice Returns the locked in interest rate of a user
    /// @param _user The address of the user
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }

    /*//////////////////////////////////////////////////////////////
                              Public Functions
     //////////////////////////////////////////////////////////////*/

    /// @notice Transfer amount from message sender to a recipient
    /// @dev Accrued interest of both sender and recipient is minted
    ///   before the transfer. If the recepient is new, they inherit
    ///   the senders interest rate. An amount of type(uint256).max indicates
    ///   transfering the sender's maximum balance.
    /// @param _recipient The address to transfer tokens to
    /// @param _amount The amount of tokens to transfer
    /// @return Boolean indicating whether the transfer was successful
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);

        if (_amount == type(uint256).max) {
            // send entire balance of sender by convention
            _amount = balanceOf(msg.sender);
        }

        if (balanceOf(_recipient) == 0 && s_userInterestRate[_recipient] == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }

        return super.transfer(_recipient, _amount);
    }

    /// @notice Transfer amount on behalf of a sender to a recipient
    /// @dev Accrued interest of both sender and recipient is minted
    ///   before the transfer. If the recipient is new, they inherit
    ///   the senders interest rate. An amount of type(uint256).max indicates
    ///   transfering the sender's maximum balance.
    /// @param _sender The address authorizing the transfer of funds
    /// @param _recipient The address receiving the funds
    /// @param _amount The amount to transfer
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);

        if (_amount == type(uint256).max) {
            // send entire balance of sender by convention
            _amount = balanceOf(_sender);
        }

        if (balanceOf(_recipient) == 0 && s_userInterestRate[_recipient] == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }

        return super.transferFrom(_sender, _recipient, _amount);
    }

    /// @notice Returns the current balance of the account, including accrued interest
    /// @param _user The address of the account
    /// @return The total balance including interest
    function balanceOf(address _user) public view override(IRebaseToken, ERC20) returns (uint256) {
        uint256 principalBalance = super.balanceOf(_user);
        uint256 growthFactor = _calculateAccumulatedInterestSinceLastUpdate(_user);
        return principalBalance * growthFactor / PRECISION_FACTOR;
    }

    /// @notice Returns the total minted supply in the contract excluding any pending accrued interest
    /// @return The total minted supply
    function totalSupply() public view override returns (uint256) {
        return super.totalSupply();
    }

    /*//////////////////////////////////////////////////////////////
                             Internal Functions
    //////////////////////////////////////////////////////////////*/

    /// @dev Calculate and mint user's accrued interest.
    ///   Updates a timestamp indicating the last minted interest.
    /// @param _user The address of the user
    function _mintAccruedInterest(address _user) internal {
        uint256 previousPrincipalBalance = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);
        uint256 balanceIncrease = currentBalance - previousPrincipalBalance;
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        if (balanceIncrease > 0) {
            _mint(_user, balanceIncrease);
        }
    }

    /// @dev Calculates growth factor due to accumulated interest since users' last update
    /// @param _user The address of the user
    /// @return Growth factor scaled by precision e.g. 1.05x growth is 1.05 * 1e18
    function _calculateAccumulatedInterestSinceLastUpdate(address _user) private view returns (uint256) {
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];

        if (timeElapsed == 0 || s_userInterestRate[_user] == 0) {
            // no time has elapsed or zero interest rate
            return PRECISION_FACTOR;
        }

        // calculate rate per second
        uint256 fractionalInterest = s_userInterestRate[_user] * timeElapsed;

        // fractional interest is already scaled and 1 is represented as PRECISION_FACTOR
        uint256 linearInterestRate = PRECISION_FACTOR + fractionalInterest;
        return linearInterestRate;
    }
}
