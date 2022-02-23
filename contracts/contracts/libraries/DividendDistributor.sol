// SPDX-License-Identifier: MIT
/*
Forked from: ECG/STEEM
Author: CuriouslyCory
Website: https://curiouslycory.com
Twitter: @CuriouslyCory
*/
pragma solidity ^0.8.12;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IDividendDistributor {
    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external;
    function setShare(address payable shareholder, uint256 amount) external;
    function deposit() external payable;
    function process(uint256 gas) external;
}

contract DividendDistributor is IDividendDistributor {
    using SafeMath for uint256;

    address _token;

    struct Share {
        uint256 amount;
        uint256 totalExcluded;// excluded dividend
        uint256 totalRealised;
    }

    address payable[] shareholders;
    mapping (address => uint256) shareholderIndexes;
    mapping (address => uint256) shareholderClaims;

    mapping (address => Share) public shares;

    uint256 public totalShares;
    uint256 public totalDividends;
    uint256 public totalDistributed;// to be shown in UI
    uint256 public dividendsPerShare;
    uint256 public dividendsPerShareAccuracyFactor = 10 ** 36;

    //uint256 public minPeriod = 1 hours;
    uint256 public minPeriod = 1 seconds;
    uint256 public minDistribution = 0.0002 * (10 ** 18);

    uint256 currentIndex;

    bool initialized;
    modifier initialization() {
        require(!initialized);
        _;
        initialized = true;
    }

    modifier onlyToken() {
        require(msg.sender == _token); _;
    }

    constructor () {
        _token = msg.sender;
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external override onlyToken {
        minPeriod = _minPeriod;
        minDistribution = _minDistribution;
    }

    function setShare(address payable shareholder, uint256 amount) external override onlyToken {
        console.log("DividendDistributor#setShare");
        console.log(amount);
        if(shares[shareholder].amount > 0){
            distributeDividend(shareholder);
        }

        if(amount > 0 && shares[shareholder].amount == 0){
            addShareholder(shareholder);
        }else if(amount == 0 && shares[shareholder].amount > 0){
            removeShareholder(shareholder);
        }

        totalShares = totalShares.sub(shares[shareholder].amount).add(amount);
        shares[shareholder].amount = amount;
        console.log(shares[shareholder].amount);
        shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
    }

    function deposit() external payable override onlyToken {
        console.log("DividendDistributor#deposit");
        uint256 amount = msg.value;
        console.log(amount);

        totalDividends = totalDividends.add(amount);
        dividendsPerShare = dividendsPerShare.add(dividendsPerShareAccuracyFactor.mul(amount).div(totalShares));
    }

    function process(uint256 gas) external override onlyToken {
        console.log("DividendDistributor#process");
        uint256 shareholderCount = shareholders.length;

        if(shareholderCount == 0 || totalDividends == 0) { return; }

        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();

        uint256 iterations = 0;

        while(gasUsed < gas && iterations < shareholderCount) {
            if(currentIndex >= shareholderCount){
                currentIndex = 0;
            }

            if(shouldDistribute(shareholders[currentIndex])){
                distributeDividend(shareholders[currentIndex]);
            }

            gasUsed = gasUsed.add(gasLeft.sub(gasleft()));
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }
    }

    function shouldDistribute(address shareholder) internal view returns (bool) {
        console.log("DividendDistributor#shouldDistribute@timestamp");
        //console.log(getUnpaidEarnings(shareholder) / 10 ** 18);
        console.log(shareholderClaims[shareholder] + minPeriod < block.timestamp ? "true" : "false");
        console.log("DividendDistributor#shouldDistribute@minDistribution");
        console.log(getUnpaidEarnings(shareholder));
        return shareholderClaims[shareholder] + minPeriod < block.timestamp
        && getUnpaidEarnings(shareholder) > minDistribution;
    }

    function distributeDividend(address payable shareholder) internal {
        console.log("DividendDistributor#distributeDividend");
        if(shares[shareholder].amount == 0){ return; }

        uint256 amount = getUnpaidEarnings(shareholder);
        if(amount > 0){
            console.log("*************ACTUAL DISTRIBUTION HAPPENING**************");
            console.log(shareholder);
            console.log(amount);
            totalDistributed = totalDistributed.add(amount);
            bool sent = shareholder.send(amount);
            require(sent, "TransferHelper: TRANSFER_FAILED");

            shareholderClaims[shareholder] = block.timestamp;
            shares[shareholder].totalRealised = shares[shareholder].totalRealised.add(amount);
            shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
        }
    }

    function claimDividend() external payable {
        distributeDividend(payable(msg.sender));
    }
/*
returns the  unpaid earnings
*/
    function getUnpaidEarnings(address shareholder) public view returns (uint256) {
        console.log("DividendDistributor#getUnpaidEarnings");
        console.log(shareholder);
        console.log(shares[shareholder].amount);
        if(shares[shareholder].amount == 0){ return 0; }

        uint256 shareholderTotalDividends = getCumulativeDividends(shares[shareholder].amount);
        uint256 shareholderTotalExcluded = shares[shareholder].totalExcluded;
        console.log(shareholderTotalDividends);
        console.log(shareholderTotalExcluded);
        if(shareholderTotalDividends <= shareholderTotalExcluded){ return 0; }

        return shareholderTotalDividends.sub(shareholderTotalExcluded);
    }

    function getCumulativeDividends(uint256 share) internal view returns (uint256) {
        return share.mul(dividendsPerShare).div(dividendsPerShareAccuracyFactor);
    }

    function addShareholder(address payable shareholder) internal {
        shareholderIndexes[shareholder] = shareholders.length;
        shareholders.push(shareholder);
    }

    function removeShareholder(address shareholder) internal {
        shareholders[shareholderIndexes[shareholder]] = shareholders[shareholders.length-1];
        shareholderIndexes[shareholders[shareholders.length-1]] = shareholderIndexes[shareholder];
        shareholders.pop();
    }
}