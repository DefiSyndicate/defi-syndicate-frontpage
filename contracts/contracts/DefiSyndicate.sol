// SPDX-License-Identifier: MIT
/*
Forked (and heavilly modified) from: SafeMoonV2
Author: CuriouslyCory
Website: https://curiouslycory.com
Twitter: @CuriouslyCory
*/

pragma solidity ^0.8.12;

import "hardhat/console.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IDividendDistributor, DividendDistributor} from "./libraries/DividendDistributor.sol";
import {IUniswapV2Factory, IUniswapV2Pair, IUniswapV2Router01, IUniswapV2Router02} from "./deps/UniswapV2.sol";

contract DefiSyndicate is IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    struct FeeTier {
        uint256 buyReflectFee;
        uint256 sellReflectFee;
        uint256 buyBurnFee;
        uint256 sellBurnFee;
        uint256 buyEcosystemFee;
        uint256 sellEcosystem;
        address ecoSystem;
    }

    struct FeeValues {
        uint256 rAmount;
        uint256 rTransferAmount;
        uint256 rReflectFee;
        uint256 tTransferAmount;
        uint256 tEcoSystem;
        uint256 tReflectFee;
        uint256 tBurn;
        uint256 tAvaxReflect;
    }

    struct tFeeValues {
        uint256 tTransferAmount;
        uint256 tEcoSystem;
        uint256 tReflect;
        uint256 tBurn;
        uint256 tAvaxReflect;
    }

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => uint256) private _avaxCache;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _isExcludedFromFee;
    mapping (address => bool) private _isExcluded;
    mapping (address => bool) private _isBlacklisted;
    mapping (address => uint256) private _accountsTier;

    address[] private _excluded;

    uint256 private constant MAX = ~uint256(0);
    uint256 private immutable _tTotal;
    uint256 private _rTotal;
    uint256 private _tFeeTotal;
    uint256 private _maxFee;

    string private constant _name = "Syndicate ID Number";
    string private constant _symbol = "SIN";
    uint8 private immutable _decimals;

    FeeTier public _defaultFees;
    FeeTier private _previousFees;
    FeeTier private _emptyFees;

    FeeTier[] private feeTiers;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    address public WAVAX;
    address private _initializerAccount;
    address public immutable _burnAddress;

    uint256 public _maxTxAmount;
    uint256 immutable _maxWalletAmount;
    uint256 private numTokensSellToAddToLiquidity;

    DividendDistributor distributor;
    address public distributorAddress;
    uint256 distributorGas = 500000;
    uint256 public swapThreshold;

    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 avaxReceived,
        uint256 tokensIntoLiquidity
    );

    modifier checkTierIndex(uint256 _index) {
        require(feeTiers.length > _index, "DefiSyndicate: Invalid tier index");
        _;
    }

    modifier preventBlacklisted(address _account, string memory errorMsg) {
        require(!_isBlacklisted[_account], errorMsg);
        _;
    }

    modifier isRouter(address _sender) {
        {
            uint32 size;
            assembly {
                size := extcodesize(_sender)
            }
            if(size > 0) {
                uint256 senderTier = _accountsTier[_sender];
                if(senderTier == 0) {
                    IUniswapV2Router02 _routerCheck = IUniswapV2Router02(_sender);
                    try _routerCheck.factory() returns (address factory) {
                        _accountsTier[_sender] = 1;
                    } catch {

                    }
                }
            }
        }

        _;
    }

    constructor(address _joeRouter) {
        _decimals = 9;

        _tTotal = 9000000 * 10**9;
        _rTotal = (MAX - (MAX % _tTotal));
        _maxFee = 1500;

        swapAndLiquifyEnabled = false;
        swapThreshold = _tTotal / 1000; // 0.01%

        _maxTxAmount = _rTotal.div(100);
        _maxWalletAmount = _maxTxAmount;
        numTokensSellToAddToLiquidity = 500 * 10**6 * 10**9;

        _burnAddress = 0x000000000000000000000000000000000000dEaD;
        _initializerAccount = _msgSender();

        _rOwned[_initializerAccount] = _rTotal;
        uniswapV2Router = IUniswapV2Router02(_joeRouter); //0x60aE616a2155Ee3d9A68541Ba4544862310933d4
        WAVAX = uniswapV2Router.WAVAX();
        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
            .createPair(address(this), WAVAX);


        //exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_burnAddress] = true;

        // init distributor for AVAX reflections
        distributor = new DividendDistributor(address(uniswapV2Router));
        distributorAddress = address(distributor);
        

        __DefiSyndicate_tiers_init();

        emit Transfer(address(0), _msgSender(), _tTotal);

        _getRate();
    }

    function __DefiSyndicate_tiers_init() private {
        // uint256 buyReflectFee;
        // uint256 sellReflectFee;
        // uint256 buyBurnFee;
        // uint256 sellBurnFee;
        // uint256 buyEcosystemFee;
        // uint256 sellEcosystem;
        // address ecoSystem;
        _defaultFees = _addTier(900, 300, 0, 0, 600, 1200, address(0));
        _addTier(900, 300, 0, 0, 600, 1200, address(0));
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "WAVAX: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "WAVAX: decreased allowance below zero"));
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function reflectionFromTokenInTiers(uint256 tAmount, uint256 _tierIndex, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            FeeValues memory _values = _getValues(tAmount, _tierIndex, uint(0));
            return _values.rAmount;
        } else {
            FeeValues memory _values = _getValues(tAmount, _tierIndex, uint(0));
            return _values.rTransferAmount;
        }
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        return reflectionFromTokenInTiers(tAmount, 0, deductTransferFee);
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromReward(address account) public onlyOwner {
        //require(!_isExcluded[account], "Account is already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    // todo: this could be much more effecient with some index mapping
    function includeInReward(address account) external onlyOwner {
        require(_isExcluded[account], "Account is already included");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function setSwapThreshold(uint256 threshold) public onlyOwner {
        swapThreshold = _tTotal / threshold; // 1000 = 0.01%
    }

    function whitelistAddress(
        address _account,
        uint256 _tierIndex
    )
    public
    onlyOwner
    checkTierIndex(_tierIndex)
    preventBlacklisted(_account, "DefiSyndicate: Selected account is in blacklist")
    {
        require(_account != address(0), "DefiSyndicate: Invalid address");
        _accountsTier[_account] = _tierIndex;
    }

    function excludeWhitelistedAddress(address _account) public onlyOwner {
        require(_account != address(0), "DefiSyndicate: Invalid address");
        require(_accountsTier[_account] > 0, "DefiSyndicate: Account is not in whitelist");
        _accountsTier[_account] = 0;
    }

    function accountTier(address _account) public view returns (FeeTier memory) {
        return feeTiers[_accountsTier[_account]];
    }

    function isWhitelisted(address _account) public view returns (bool) {
        return _accountsTier[_account] > 0;
    }

    function checkFees(FeeTier memory _tier) internal view returns (FeeTier memory) {
        uint256 _buyFees = addBuyFees(_tier);
        uint256 _sellFees = addSellFees(_tier);
        require(_buyFees <= _maxFee && _sellFees <= _maxFee, "DefiSyndicate: Fees exceeded max limitation");

        return _tier;
    }

    function checkBuyFeesChanged(FeeTier memory _tier, uint256 _oldFee, uint256 _newFee) internal view {
        uint256 _buyFees = addBuyFees(_tier)
            .sub(_oldFee)
            .add(_newFee);

        require(_buyFees <= _maxFee, "DefiSyndicate: Fees exceeded max limitation");
    }

    function checkSellFeesChanged(FeeTier memory _tier, uint256 _oldFee, uint256 _newFee) internal view {
        uint256 _sellFees = addSellFees(_tier)
            .sub(_oldFee)
            .add(_newFee);

        require(_sellFees <= _maxFee, "DefiSyndicate: Fees exceeded max limitation");
    }

    function addBuyFees(FeeTier memory _tier) internal pure returns(uint256){
        return _tier.buyBurnFee
            .add(_tier.buyEcosystemFee)
            .add(_tier.buyReflectFee);
    }

    function addSellFees(FeeTier memory _tier) internal pure returns(uint256){
        return _tier.sellBurnFee
            .add(_tier.sellEcosystem)
            .add(_tier.sellReflectFee);
    }

    function setBuyEcoSystemFeePercent(uint256 _tierIndex, uint256 _buyEcosystemFee) external onlyOwner checkTierIndex(_tierIndex) {
        FeeTier memory tier = feeTiers[_tierIndex];
        checkBuyFeesChanged(tier, tier.buyEcosystemFee, _buyEcosystemFee);
        feeTiers[_tierIndex].buyEcosystemFee = _buyEcosystemFee;
        if(_tierIndex == 0) {
            _defaultFees.buyEcosystemFee = _buyEcosystemFee;
        }
    }

    function setSellEcoSystemFeePercent(uint256 _tierIndex, uint256 _sellEcoSystem) external onlyOwner checkTierIndex(_tierIndex) {
        FeeTier memory tier = feeTiers[_tierIndex];
        checkSellFeesChanged(tier, tier.sellEcosystem, _sellEcoSystem);
        feeTiers[_tierIndex].sellEcosystem = _sellEcoSystem;
        if(_tierIndex == 0) {
            _defaultFees.sellEcosystem = _sellEcoSystem;
        }
    }

    function setBuyReflectFeePercent(uint256 _tierIndex, uint256 _buyReflectFee) external onlyOwner checkTierIndex(_tierIndex) {
        FeeTier memory tier = feeTiers[_tierIndex];
        checkBuyFeesChanged(tier, tier.buyReflectFee, _buyReflectFee);
        feeTiers[_tierIndex].buyReflectFee = _buyReflectFee;
        if(_tierIndex == 0) {
            _defaultFees.buyReflectFee = _buyReflectFee;
        }
    }

    function setSellReflectFeePercent(uint256 _tierIndex, uint256 _sellReflectFee) external onlyOwner checkTierIndex(_tierIndex) {
        FeeTier memory tier = feeTiers[_tierIndex];
        checkSellFeesChanged(tier, tier.sellReflectFee, _sellReflectFee);
        feeTiers[_tierIndex].sellReflectFee = _sellReflectFee;
        if(_tierIndex == 0) {
            _defaultFees.sellReflectFee = _sellReflectFee;
        }
    }

    function setBuyBurnFeePercent(uint256 _tierIndex, uint256 _buyBurnFee) external onlyOwner checkTierIndex(_tierIndex) {
        FeeTier memory tier = feeTiers[_tierIndex];
        checkBuyFeesChanged(tier, tier.buyBurnFee, _buyBurnFee);
        feeTiers[_tierIndex].buyBurnFee = _buyBurnFee;
        if(_tierIndex == 0) {
            _defaultFees.buyBurnFee = _buyBurnFee;
        }
    }

    function setSellBurnFeePercent(uint256 _tierIndex, uint256 _sellBurnFee) external onlyOwner checkTierIndex(_tierIndex) {
        FeeTier memory tier = feeTiers[_tierIndex];
        checkSellFeesChanged(tier, tier.sellBurnFee, _sellBurnFee);
        feeTiers[_tierIndex].sellBurnFee = _sellBurnFee;
        if(_tierIndex == 0) {
            _defaultFees.sellBurnFee = _sellBurnFee;
        }
    }

    function setEcoSystemFeeAddress(uint256 _tierIndex, address _ecoSystem) external onlyOwner checkTierIndex(_tierIndex) {
        require(_ecoSystem != address(0), "DefiSyndicate: Address Zero is not allowed");
        excludeFromReward(_ecoSystem);
        feeTiers[_tierIndex].ecoSystem = _ecoSystem;
        if(_tierIndex == 0) {
            _defaultFees.ecoSystem = _ecoSystem;
        }
    }

    function addTier(
        uint256 _buyReflectFee,
        uint256 _sellReflectFee,
        uint256 _buyBurnFee,
        uint256 _sellBurnFee,
        uint256 _buyEcosystemFee,
        uint256 _sellEcosystem,
        address _ecoSystem
    ) public onlyOwner {
        _addTier(
            _buyReflectFee,
            _sellReflectFee,
            _buyBurnFee,
            _sellBurnFee,
            _buyEcosystemFee,
            _sellEcosystem,
            _ecoSystem
        );
    }

    function _addTier(
        uint256 _buyReflectFee,
        uint256 _sellReflectFee,
        uint256 _buyBurnFee,
        uint256 _sellBurnFee,
        uint256 _buyEcosystemFee,
        uint256 _sellEcosystem,
        address _ecoSystem
    ) internal returns (FeeTier memory) {
        FeeTier memory _newTier = checkFees(FeeTier(
                _buyReflectFee,
                _sellReflectFee,
                _buyBurnFee,
                _sellBurnFee,
                _buyEcosystemFee,
                _sellEcosystem,
                _ecoSystem
            ));
        excludeFromReward(_ecoSystem);
        feeTiers.push(_newTier);

        return _newTier;
    }

    function feeTier(uint256 _tierIndex) public view checkTierIndex(_tierIndex) returns (FeeTier memory) {
        return feeTiers[_tierIndex];
    }

    function blacklistAddress(address account) public onlyOwner {
        _isBlacklisted[account] = true;
        _accountsTier[account] = 0;
    }

    function unBlacklistAddress(address account) public onlyOwner {
        _isBlacklisted[account] = false;
    }

    function updateRouterAndPair(address _uniswapV2Router,address _uniswapV2Pair) public onlyOwner {
        uniswapV2Router = IUniswapV2Router02(_uniswapV2Router);
        uniswapV2Pair = _uniswapV2Pair;
        WAVAX = uniswapV2Router.WAVAX();
    }

    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner {
        _maxTxAmount = _tTotal.mul(maxTxPercent).div(
            10**4
        );
    }

    //to receive AVAX from uniswapV2Router when swapping
    receive() external payable {}

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount, uint256 _tierIndex, uint buySell) private view returns (FeeValues memory) {
        tFeeValues memory tValues = _getTValues(tAmount, _tierIndex, buySell);
        uint256 tTransferFee = tValues.tEcoSystem.add(tValues.tBurn).add(tValues.tAvaxReflect);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rReflectFee) = _getRValues(tAmount, tValues.tReflect, tTransferFee, _getRate());
        return FeeValues(rAmount, rTransferAmount, rReflectFee, tValues.tTransferAmount, tValues.tEcoSystem, tValues.tReflect, tValues.tBurn, tValues.tAvaxReflect);
    }

    function _getTValues(uint256 tAmount, uint256 _tierIndex, uint buySell) private view returns (tFeeValues memory) {
        FeeTier memory tier = feeTiers[_tierIndex];
        tFeeValues memory tValues;
        if(buySell == 0){
            tValues = tFeeValues(
                0,                                              //xfer          tTransferAmount
                calculateFee(tAmount, tier.buyEcosystemFee),    //eco           tEcoSystem
                0,                                              //token reflect tReflect
                calculateFee(tAmount, tier.buyBurnFee),         //burn          tBurn
                calculateFee(tAmount, tier.buyReflectFee)       //avax reflect  tAvaxReflect
            );
        }else{
            tValues = tFeeValues(
                0,                                              //xfer          tTransferAmount
                calculateFee(tAmount, tier.sellEcosystem),      //eco           tEcoSystem
                calculateFee(tAmount, tier.sellReflectFee),     //token reflect tReflect
                calculateFee(tAmount, tier.sellBurnFee),        //burn          tBurn
                0                                               //avax reflect  tAvaxReflect
            );
        }

        tValues.tTransferAmount = tAmount.sub(tValues.tEcoSystem).sub(tValues.tReflect).sub(tValues.tBurn).sub(tValues.tAvaxReflect);
        return tValues;
    }

    function _getRValues(uint256 tAmount, uint256 tReflectFee, uint256 tTransferFee, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tReflectFee.mul(currentRate);
        uint256 rTransferFee = tTransferFee.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rTransferFee);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    // current supply values minus that owned by excluded addresses
    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function calculateFee(uint256 _amount, uint256 _fee) private pure returns (uint256) {
        if(_fee == 0) return 0;
        return _amount.mul(_fee).div(10**4);
    }

    function removeAllFee() private {
        _previousFees = feeTiers[0];
        feeTiers[0] = _emptyFees;
    }

    function restoreAllFee() private {
        feeTiers[0] = _previousFees;
    }

    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }

    function isBlacklisted(address account) public view returns(bool) {
        return _isBlacklisted[account];
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    )
    private
    preventBlacklisted(owner, "DefiSyndicate: Owner address is blacklisted")
    preventBlacklisted(spender, "DefiSyndicate: Spender address is blacklisted")
    {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    )
    private
    preventBlacklisted(_msgSender(), "DefiSyndicate: Address is blacklisted")
    preventBlacklisted(from, "DefiSyndicate: From address is blacklisted")
    preventBlacklisted(to, "DefiSyndicate: To address is blacklisted")
    isRouter(_msgSender())
    {
        require(from != address(0), "WAVAX: transfer from the zero address");
        require(to != address(0), "WAVAX: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(amount + balanceOf(to) < _maxWalletAmount, "Wallets can't hold more than 90k.");

        if(from != owner() && to != owner())
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");

        // is this a buy event or sell event?
        uint buySell;
        if(to == uniswapV2Pair){
            buySell = 1;
        }else if(from == uniswapV2Pair){
            buySell = 0;
        }else {
            buySell = 3;
        }

        // indicates if fee should be deducted from transfer
        bool takeFee = true;
        // if any account belongs to _isExcludedFromFee account then remove the fee
        // peer to peer trades also don't incur a tax.
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to] || buySell == 3){
            takeFee = false;
        }

        uint tierIndex = 0;
        if(takeFee) {
            tierIndex = _accountsTier[from];

            if(_msgSender() != from) {
                tierIndex = _accountsTier[_msgSender()];
            }
        }

        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from, to, amount, tierIndex, takeFee, buySell);
    }

    function swapAndDistributeRewards() private {
        uint256 startingAvaxBalance = address(this).balance;
        swapTokensForAvax(balanceOf(address(this)));
        uint256 tokensRecieved = address(this.balance) - startingAvaxBalance;

        try distributor.deposit{ value: tokensRecieved }() {} catch {}
    }


    function swapTokensForAvax(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> WAVAX
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WAVAX();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapTokensForExactAVAX(
            tokenAmount,
            0, // accept any amount of AVAX
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 avaxAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityAVAX{value: avaxAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount, uint256 tierIndex, bool takeFee, uint buySell) private {
        if(!takeFee)
            removeAllFee();

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount, tierIndex, buySell);
            try distributor.setShare(recipient, _rOwned[recipient]) {} catch {}
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount, tierIndex, buySell);
            try distributor.setShare(sender, _rOwned[sender]) {} catch {}
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount, tierIndex, buySell);
            try distributor.setShare(sender, _rOwned[sender]) {} catch {}
            try distributor.setShare(recipient, _rOwned[recipient]) {} catch {}
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount, tierIndex, buySell);
        } else {
            _transferStandard(sender, recipient, amount, tierIndex, buySell);
            try distributor.setShare(sender, _rOwned[sender]) {} catch {}
            try distributor.setShare(recipient, _rOwned[recipient]) {} catch {}
        }

        if(shouldSwapAndDistributeRewards()){
            swapAndDistributeRewards();
        }

        if(!takeFee)
            restoreAllFee();
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount, uint256 tierIndex, uint buySell) private {
        FeeValues memory _values = _getValues(tAmount, tierIndex, buySell);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(_values.rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(_values.tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(_values.rTransferAmount);
        _takeFees(sender, _values, tierIndex, buySell);
        _reflectFee(_values.rReflectFee, _values.tReflectFee);
        emit Transfer(sender, recipient, _values.tTransferAmount);
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount, uint256 tierIndex, uint buySell) private {
        FeeValues memory _values = _getValues(tAmount, tierIndex, buySell);
        _rOwned[sender] = _rOwned[sender].sub(_values.rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(_values.rTransferAmount);
        _takeFees(sender, _values, tierIndex, buySell);
        _reflectFee(_values.rReflectFee, _values.tReflectFee);
        emit Transfer(sender, recipient, _values.tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount, uint256 tierIndex, uint buySell) private {
        FeeValues memory _values = _getValues(tAmount, tierIndex, buySell);
        _rOwned[sender] = _rOwned[sender].sub(_values.rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(_values.tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(_values.rTransferAmount);
        _takeFees(sender, _values, tierIndex, buySell);
        _reflectFee(_values.rReflectFee, _values.tReflectFee);
        emit Transfer(sender, recipient, _values.tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount, uint256 tierIndex, uint buySell) private {
        FeeValues memory _values = _getValues(tAmount, tierIndex, buySell);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(_values.rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(_values.rTransferAmount);
        _takeFees(sender, _values, tierIndex, buySell);
        _reflectFee(_values.rReflectFee, _values.tReflectFee);
        emit Transfer(sender, recipient, _values.tTransferAmount);
    }

    function _takeFees(address sender, FeeValues memory values, uint256 tierIndex, uint buySell) private {
        _takeFee(sender, values.tEcoSystem, feeTiers[tierIndex].ecoSystem); // send fees to marketing wallet
        _takeFee(sender, values.tAvaxReflect, address(this)); // send avax reflect fees to this contract for batch swap later
        _takeBurn(sender, values.tBurn);
    }

    function _takeFee(address sender, uint256 tAmount, address recipient) private {
        if(recipient == address(0)) return;
        if(tAmount == 0) return;

        uint256 currentRate = _getRate();
        uint256 rAmount = tAmount.mul(currentRate);
        _rOwned[recipient] = _rOwned[recipient].add(rAmount);
        if(_isExcluded[recipient])
            _tOwned[recipient] = _tOwned[recipient].add(tAmount);

        emit Transfer(sender, recipient, tAmount);
    }

    function _takeBurn(address sender, uint256 _amount) private {
        if(_amount == 0) return;
        _tOwned[_burnAddress] = _tOwned[_burnAddress].add(_amount);

        emit Transfer(sender, _burnAddress, _amount);
    }

    function feeTiersLength() public view returns (uint) {
        return feeTiers.length;
    }

    function updateBurnAddress(address _newBurnAddress) external onlyOwner {
        _burnAddress = _newBurnAddress;
        excludeFromReward(_newBurnAddress);
    }
}