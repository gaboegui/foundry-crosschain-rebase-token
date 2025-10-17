// SPDX-License-Identifier: MIT
/**
 * @title IRebaseToken Interface
 * @author Gabriel Eguiguren P.
 * @notice This interface defines the external functions for the RebaseToken contract.
 * It allows other contracts to interact with the RebaseToken, including minting, burning,
 * checking balances, and managing interest rates.
 */
pragma solidity ^0.8.24;

interface IRebaseToken {
    /**
     * @notice Mints new tokens to a specified address.
     * @dev This function should only be callable by authorized accounts (e.g., a vault or owner).
     * @param _to The address to mint the tokens to.
     * @param _amount The amount of tokens to mint.
     * @param _userInterestRate The interest rate for the user.
     */
    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external;

    /**
     * @notice Burns tokens from a specified address.
     * @dev This function should only be callable by authorized accounts (e.g., a vault or owner).
     * @param _from The address to burn the tokens from.
     * @param _amount The amount of tokens to burn.
     */
    function burn(address _from, uint256 _amount) external;

    /**
     * @notice Gets the balance of a user, including accumulated interest.
     * @param _user The address to get the balance of.
     * @return linearInterest The user's balance including interest.
     */
    function balanceOf(address _user) external view returns (uint256 linearInterest);

    /**
     * @notice Gets the global interest rate of the protocol.
     * @return interest The global interest rate.
     */
    function getInterestRate() external view returns (uint256 interest);

    /**
     * @notice Gets the interest rate for a specific user.
     * @param _user The address of the user.
     * @return The user's specific interest rate.
     */
    function getUserInterestRate(address _user) external view returns (uint256);

    /**
     * @notice Grants the mint and burn role to a specified account.
     * @dev This allows the account to call the mint and burn functions.
     * @param _account The address to grant the role to.
     */
    function grantMintAndBurnRole(address _account) external;
}