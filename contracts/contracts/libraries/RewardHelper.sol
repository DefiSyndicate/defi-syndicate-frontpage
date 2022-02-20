// SPDX-License-Identifier: MIT
/*
Forked (and heavilly modified) from: SafeMoonV2
Author: CuriouslyCory
Website: https://curiouslycory.com
Twitter: @CuriouslyCory
*/

pragma solidity ^0.8.12;

import "hardhat/console.sol";

contract RewardHelper {
    uint constant pointMultiplier = 10e18;

    struct Account {
        uint balance;
        uint lastDividendPoints;
    }

    mapping(address=>Account) accounts;
    uint totalSupply;
    uint totalDividendPoints;
    uint unclaimedDividends;

    function dividendsOwing(address account) internal returns(uint) {
        uint newDividendPoints = totalDividendPoints - accounts[account].lastDividendPoints;
        return (accounts[account].balance * newDividendPoints) / pointMultiplier;
    }

    modifier updateAccount(address account) {
        uint owing = dividendsOwing(account);
        if(owing > 0) {
            unclaimedDividends -= owing;
            accounts[account].balance += owing;
            accounts[account].lastDividendPoints = totalDividendPoints;
        }
        _;
    }

    function disburse(uint amount) {
        totalDividendPoints += (amount * pointsMultiplier / totalSupply);
        totalSupply += amount;
        unclaimedDividends += amount;
    }
}
