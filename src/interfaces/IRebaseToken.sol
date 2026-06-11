// SPDX-License-Identifier: MIT

pragma solidity ^0.8.33;

interface IRebaseToken {
    /// @notice Mints new tokens to the specified address
    /// @param _to The address to mint tokens to
    /// @param _amount The amount of tokens to mint
    function mint(address _to, uint256 _amount, uint256 _interestRate) external;

    /// @notice Burns tokens from the specified address
    /// @param _from The address to burn tokens from
    /// @param _amount The amount of tokens to burn
    function burn(address _from, uint256 _amount) external;

    /// @notice Returns a user's balance
    /// @param _user The user who's balance to query
    function balanceOf(address _user) external view returns (uint256);

    /// @notice Returns a user's interest rate
    /// @param _user The user who's interest rate we're querying
    function getUserInterestRate(address _user) external view returns (uint256);

    /// @notice Gets the global interest rate
    /// @return The global interest rate
    function getInterestRate() external view returns (uint256);

    /// @notice grant an account mint and burn role
    /// @param _account The account to grant role
    function grantMintAndBurnRole(address _account) external;
}
