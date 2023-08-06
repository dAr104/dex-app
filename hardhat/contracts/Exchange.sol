// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Exchange is ERC20 {

    address public tokenAddress;

    /* 
    Exchange is inheriting from ERC20, because our exchange itself is an ERC-20 contract.
    as it is responsable for minting and issueing LP tokens
    */

    constructor(address token) ERC20("ETH TOKEN LP Token", "lpETHTOKEN") {
        require(token != address(0), "Token address passed is a null address");
        tokenAddress = token;
    }

    /**
    @dev returns the balance of token held by the contract
    @return uint token balance held by the contract
    */
    function getReserve() public view returns (uint) {
        return ERC20(tokenAddress).balanceOf(address(this));
    }

    /**
    @dev allow user to add liquidity too the exchange
    @param amountOfToken value of TOKEN to add to liquidity pool
    @return amount of lp minted to the caller
    */
    function addLiquidity(uint amountOfToken) 
        public
        payable
        returns (uint)
    {
        uint lpTokensToMint;
        uint ethReserveBalance = address(this).balance;
        uint tokenReserveBalance = getReserve();

        ERC20 token = ERC20(tokenAddress);

        // If the reserve is empty, take any user supplied value for initial liquidity
        if (tokenReserveBalance == 0) {
            token.transferFrom(msg.sender, address(this), amountOfToken);

            // lpTokensToMint = ethReserveBalance = msg.value
            lpTokensToMint = ethReserveBalance;

            _mint(msg.sender, lpTokensToMint);

            return lpTokensToMint;
        }

        // If the reserve is not empty, calculate the amount of LP tokens to mint
        // based on the amount of ETH and token supplied

        // Calculate the ether reserve before the function call
        uint ethReservePriorToFunctionCall = ethReserveBalance - msg.value;

        // Calculate the minimum amount of token required to add liquidity
        uint minTokenAmountRequired = (msg.value * tokenReserveBalance) / ethReservePriorToFunctionCall;

        require(amountOfToken >= minTokenAmountRequired, "Insufficient token amount provided");

        token.transferFrom(msg.sender, address(this), amountOfToken);

        // Calculate the amount of LP tokens to mint
        lpTokensToMint = (totalSupply() * msg.value) / ethReservePriorToFunctionCall;

        _mint(msg.sender, lpTokensToMint);

        return lpTokensToMint;
    }

    /**
    @dev allow user to remove liquidity from the exchange
    @param amountOfLPTokens value of LP tokens to calculate the amount of ETH and TOKEN to remove from liquidity pool
    @return amount of ETH and TOKEN returned to the caller
    */
    function removeLiquidity(uint amountOfLPTokens) public returns (uint, uint) {

        require (amountOfLPTokens > 0, "Amount of tokens to remove must be greater than 0");

        uint ethReserveBalance = address(this).balance;
        uint lpTokenTotalSupply = totalSupply();

        // Calculate the amount of ETH to send to the caller: % of LP tokens * ETH reserve
        uint ethToReturn = (ethReserveBalance * amountOfLPTokens) / lpTokenTotalSupply;
        uint tokenToReturn = (getReserve() * amountOfLPTokens) / lpTokenTotalSupply;

        // burn the amount of LP from the user, and transfer the ETH and tokens to the user
        _burn(msg.sender, amountOfLPTokens);
        payable(msg.sender).transfer(ethToReturn);
        ERC20(tokenAddress).transfer(msg.sender, tokenToReturn);

        return (ethToReturn, tokenToReturn);
    }

    /**
    @dev calculates the amount of output tokens to be received based on xy = (x + dx)(y - dy):
     x = inputReserve, y = outputReserve, dx = inputAmount in swap, dy = outputAmount in swap
    @param inputAmount amount of input token (ETH)
    @param inputReserve amount of input token (ETH) in the reserve
    @param outputReserve amount of output tokens (TOKEN) in the reserve
    @return amount of output tokens (TOKEN) to be received
    */
    function getOutputAmountFromSwap(
        uint inputAmount,
        uint inputReserve,
        uint outputReserve
    )
        public
        pure
        returns (uint)
    {
        require(inputReserve > 0 && outputReserve > 0, "Reserve values must be greater than 0");

        uint inputAmountWithFee = inputAmount * 99;
        uint numerator = inputAmountWithFee * outputReserve;
        uint denominator = (inputReserve * 100) + inputAmountWithFee;

        return numerator / denominator;
    }

    /**
    @dev allow user to swap ETH for TOKEN
    @param minTokensToReceive minimum amount of TOKEN to receive from the swap
    */  
    function ethToTokenSwap(uint minTokensToReceive) public payable {
        uint tokenReserveBalance = getReserve();
        uint tokenToReceive = getOutputAmountFromSwap(
            msg.value,
            address(this).balance - msg.value,
            tokenReserveBalance
        );

        require(tokenToReceive >= minTokensToReceive, "Tokens received are less than minimum tokens expected");

        ERC20(tokenAddress).transfer(msg.sender, tokenToReceive);
    }

    /**
    @dev allow user ti swao TOKEN for ETH
    @param tokenToSwap amount to token to swap
    @param minEthToReceive minimum amount of ETH to receive from the swap
    */
    function tokenToEthSwap(
        uint tokenToSwap,
        uint minEthToReceive
    ) public {
        uint tokenReserveBalance = getReserve();
        uint ethToReceive = getOutputAmountFromSwap(
            tokenToSwap,
            tokenReserveBalance,
            address(this).balance
        );

        require(ethToReceive >= minEthToReceive, "ETH received is less than minimum ETH expected");

        ERC20(tokenAddress).transferFrom(
            msg.sender, address(this), tokenToSwap);
        payable(msg.sender).transfer(ethToReceive);
    }
}