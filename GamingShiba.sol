// SPDX-License-Identifier: MIT
pragma solidity =0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract GamingShibaContract is Context, IERC20, Ownable, Initializable {
    using Address for address;

    struct FeeTier {
        uint256 stakingFee;
        uint256 devFee;
        uint256 marketingFee;
        uint256 communityFee;
        uint256 taxFee;
        uint256 betweenWalletsFee;
        address StakingAddress;
        address DevAddress;
        address MarketingAddress;
        address CommunityAddress;
        address betweenWalletsAddress;
    }

    struct FeeValues {
        uint256 rAmount;
        uint256 rTransferAmount;
        uint256 rFee;
        uint256 tTransferAmount;
        uint256 tStaking;
        uint256 tDev;
        uint256 tMarketing;
        uint256 tCommunity;
        uint256 tBetweenWallets;
        uint256 tFee;
    }

    struct tFeeValues {
        uint256 tTransferAmount;
        uint256 tStaking;
        uint256 tDev;
        uint256 tMarketing;
        uint256 tCommunity;
        uint256 tBetweenWallets;
        uint256 tFee;
    }

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcluded;
    mapping(address => uint256) private _accountsTier;

    address[] private _excluded;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal;
    uint256 private _rTotal;
    uint256 private _tFeeTotal;
    uint256 private _maxFee;
    bool public _isFeeBetweenWallets = false;

    string private _name = "GamingShiba";
    string private _symbol = "GamingShiba";
    uint8 private _decimals = 9;

    FeeTier public _defaultFees;
    FeeTier private _previousFees;
    FeeTier private _emptyFees;

    FeeTier[] private feeTiers;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    address public WBNB;
    address private migration;
    address private _initializerAccount;

    bool private inSwapAndLiquify;
    bool public swapAndLiquifyEnabled;

    uint256 public _maxTxAmount;
    uint256 private numTokensSellToAddToLiquidity;

    bool private _upgraded;

    event ExcludedFromFeeUpdated(address _addr, bool excluded);
    event FeeBetweenWalletsUpdated(bool excluded);

    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 bnbReceived,
        uint256 tokensIntoLiquidity
    );

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    modifier checkTierIndex(uint256 _index) {
        require(feeTiers.length > _index, "Invalid tier index");
        _;
    }

    //0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3
    constructor(
        uint256 _supply,
        address _router,
        address _stakingAddr,
        address _devAddr,
        address _marketingAddr,
        address _communityAddr,
        address _betweenWalletsAddr
    ) {
        _tTotal = _supply * 10**6 * 10**_decimals;
        _rTotal = (MAX - (MAX % _tTotal));
        //25%
        _maxFee = 2500;

        _maxTxAmount = ((_tTotal * 5) / 1000) * 10**_decimals;
        numTokensSellToAddToLiquidity = ((_tTotal * 5) / 1000) * 10**_decimals;
        swapAndLiquifyEnabled = true;

        _initializerAccount = _msgSender();
        _rOwned[_initializerAccount] = _rTotal;

        uniswapV2Router = IUniswapV2Router02(_router);
        WBNB = uniswapV2Router.WETH();
        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
                address(this),
                WBNB
            );

        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;

        _tiers_init(
            _stakingAddr,
            _devAddr,
            _marketingAddr,
            _communityAddr,
            _betweenWalletsAddr
        );

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function _tiers_init(
        address _stakingAddr,
        address _devAddr,
        address _marketingAddr,
        address _communityAddr,
        address _betweenWalletsAddr
    ) internal initializer {
        //no fee
        _defaultFees = _addTier(
            0,
            0,
            0,
            0,
            0,
            0,
            address(0),
            address(0),
            address(0),
            address(0),
            address(0)
        );
        //buy
        _addTier(
            200,
            300,
            300,
            0,
            0,
            0,
            _stakingAddr,
            _devAddr,
            _marketingAddr,
            address(0),
            address(0)
        );
        //sell
        _addTier(
            200,
            300,
            300,
            100,
            100,
            0,
            _stakingAddr,
            _devAddr,
            _marketingAddr,
            _communityAddr,
            address(0)
        );
        //betweenWallets
        _addTier(
            0,
            0,
            0,
            0,
            0,
            500,
            address(0),
            address(0),
            address(0),
            address(0),
            _betweenWalletsAddr
        );
    }

    function feeTier(uint256 _tierIndex)
        public
        view
        checkTierIndex(_tierIndex)
        returns (FeeTier memory)
    {
        return feeTiers[_tierIndex];
    }

    function _addTier(
        uint256 _stakingFee,
        uint256 _devFee,
        uint256 _marketingFee,
        uint256 _communityFee,
        uint256 _taxFee,
        uint256 _betweenWalletsFee,
        address _StakingAddress,
        address _DevAddress,
        address _MarketingAddress,
        address _CommunityAddress,
        address _betweenWalletsAddress
    ) internal returns (FeeTier memory) {
        FeeTier memory temp = FeeTier(
            _stakingFee,
            _devFee,
            _marketingFee,
            _communityFee,
            _taxFee,
            _betweenWalletsFee,
            _StakingAddress,
            _DevAddress,
            _MarketingAddress,
            _CommunityAddress,
            _betweenWalletsAddress
        );
        FeeTier memory _newTier = checkFees(temp);
        feeTiers.push(_newTier);

        return _newTier;
    }

    function checkFees(FeeTier memory _tier)
        internal
        view
        returns (FeeTier memory)
    {
        uint256 _fees = _tier.stakingFee +
            _tier.devFee +
            _tier.marketingFee +
            _tier.communityFee +
            _tier.taxFee +
            _tier.betweenWalletsFee;
        require(_fees <= _maxFee, "Fees exceeded max limitation");

        return _tier;
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

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "ERC20: insufficient allowance"
            );
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function reflectionFromTokenInTiers(
        uint256 tAmount,
        uint256 _tierIndex,
        bool deductTransferFee
    ) public view returns (uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            FeeValues memory _values = _getValues(tAmount, _tierIndex);
            return _values.rAmount;
        } else {
            FeeValues memory _values = _getValues(tAmount, _tierIndex);
            return _values.rTransferAmount;
        }
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee)
        public
        view
        returns (uint256)
    {
        return reflectionFromTokenInTiers(tAmount, 0, deductTransferFee);
    }

    function tokenFromReflection(uint256 rAmount)
        public
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        require(currentRate != 0, "Division with 0");
        return rAmount / currentRate;
    }

    function excludeFromReward(address account) public onlyOwner {
        require(!_isExcluded[account], "Account is already excluded");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner {
        require(_isExcluded[account], "Account is already included");
        address[] storage _temp = _excluded;
        uint256 Alength = _temp.length;
        for (uint256 i = 0; i < Alength; i++) {
            if (_temp[i] == account) {
                _temp[i] = _temp[_temp.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _temp.pop();
                break;
            }
        }
        _excluded = _temp;
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
        emit ExcludedFromFeeUpdated(account, true);
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
        emit ExcludedFromFeeUpdated(account, false);
    }

    function SetIsFeeBetweenWallets(bool val) public onlyOwner {
        _isFeeBetweenWallets = val;
        emit FeeBetweenWalletsUpdated(val);
    }

    function whitelistAddress(address _account, uint256 _tierIndex)
        public
        onlyOwner
        checkTierIndex(_tierIndex)
    {
        require(_account != address(0), "Invalid address");
        _accountsTier[_account] = _tierIndex;
    }

    function excludeWhitelistedAddress(address _account) public onlyOwner {
        require(_account != address(0), "Invalid address");
        require(_accountsTier[_account] > 0, "Account is not in whitelist");
        _accountsTier[_account] = 0;
    }

    function accountTier(address _account)
        public
        view
        returns (FeeTier memory)
    {
        return feeTiers[_accountsTier[_account]];
    }

    function isWhitelisted(address _account) public view returns (bool) {
        return _accountsTier[_account] > 0;
    }

    function checkFeesChanged(
        FeeTier memory _tier,
        uint256 _oldFee,
        uint256 _newFee
    ) internal view {
        uint256 _fees = _tier.stakingFee +
            _tier.devFee +
            _tier.marketingFee +
            _tier.communityFee +
            _tier.taxFee +
            _tier.betweenWalletsFee;

        uint256 _feesFinal = (_fees - _oldFee) + _newFee;

        require(_feesFinal <= _maxFee, "Fees exceeded max limitation");
    }

    function setStakingFeePercent(uint256 _tierIndex, uint256 _stakingFee)
        external
        onlyOwner
        checkTierIndex(_tierIndex)
    {
        FeeTier memory tier = feeTiers[_tierIndex];
        checkFeesChanged(tier, tier.stakingFee, _stakingFee);
        feeTiers[_tierIndex].stakingFee = _stakingFee;
        if (_tierIndex == 0) {
            _defaultFees.stakingFee = _stakingFee;
        }
    }

    function setDevFeePercent(uint256 _tierIndex, uint256 _fee)
        external
        onlyOwner
        checkTierIndex(_tierIndex)
    {
        FeeTier memory tier = feeTiers[_tierIndex];
        checkFeesChanged(tier, tier.devFee, _fee);
        feeTiers[_tierIndex].devFee = _fee;
        if (_tierIndex == 0) {
            _defaultFees.devFee = _fee;
        }
    }

    function setMarketingFeePercent(uint256 _tierIndex, uint256 _fee)
        external
        onlyOwner
        checkTierIndex(_tierIndex)
    {
        FeeTier memory tier = feeTiers[_tierIndex];
        checkFeesChanged(tier, tier.marketingFee, _fee);
        feeTiers[_tierIndex].marketingFee = _fee;
        if (_tierIndex == 0) {
            _defaultFees.marketingFee = _fee;
        }
    }

    function setCommunityFeePercent(uint256 _tierIndex, uint256 _fee)
        external
        onlyOwner
        checkTierIndex(_tierIndex)
    {
        FeeTier memory tier = feeTiers[_tierIndex];
        checkFeesChanged(tier, tier.communityFee, _fee);
        feeTiers[_tierIndex].communityFee = _fee;
        if (_tierIndex == 0) {
            _defaultFees.communityFee = _fee;
        }
    }

    function setBetweenWalletsFeePercent(uint256 _tierIndex, uint256 _fee)
        external
        onlyOwner
        checkTierIndex(_tierIndex)
    {
        FeeTier memory tier = feeTiers[_tierIndex];
        checkFeesChanged(tier, tier.betweenWalletsFee, _fee);
        feeTiers[_tierIndex].betweenWalletsFee = _fee;
        if (_tierIndex == 0) {
            _defaultFees.betweenWalletsFee = _fee;
        }
    }

    function setTaxFeePercent(uint256 _tierIndex, uint256 _taxFee)
        external
        onlyOwner
        checkTierIndex(_tierIndex)
    {
        FeeTier memory tier = feeTiers[_tierIndex];
        checkFeesChanged(tier, tier.taxFee, _taxFee);
        feeTiers[_tierIndex].taxFee = _taxFee;
        if (_tierIndex == 0) {
            _defaultFees.taxFee = _taxFee;
        }
    }

    function setStakingFeeAddress(uint256 _tierIndex, address _address)
        external
        onlyOwner
        checkTierIndex(_tierIndex)
    {
        require(_address != address(0), "Address Zero is not allowed");
        feeTiers[_tierIndex].StakingAddress = _address;
        if (_tierIndex == 0) {
            _defaultFees.StakingAddress = _address;
        }
    }

    function setDevFeeAddress(uint256 _tierIndex, address _address)
        external
        onlyOwner
        checkTierIndex(_tierIndex)
    {
        require(_address != address(0), "Address Zero is not allowed");
        feeTiers[_tierIndex].DevAddress = _address;
        if (_tierIndex == 0) {
            _defaultFees.DevAddress = _address;
        }
    }

    function setMarketingFeeAddress(uint256 _tierIndex, address _address)
        external
        onlyOwner
        checkTierIndex(_tierIndex)
    {
        require(_address != address(0), "Address Zero is not allowed");
        feeTiers[_tierIndex].MarketingAddress = _address;
        if (_tierIndex == 0) {
            _defaultFees.MarketingAddress = _address;
        }
    }

    function setCommunityFeeAddress(uint256 _tierIndex, address _address)
        external
        onlyOwner
        checkTierIndex(_tierIndex)
    {
        require(_address != address(0), "Address Zero is not allowed");
        feeTiers[_tierIndex].CommunityAddress = _address;
        if (_tierIndex == 0) {
            _defaultFees.CommunityAddress = _address;
        }
    }

    function setBetweenWalletsFeeAddress(uint256 _tierIndex, address _address)
        external
        onlyOwner
        checkTierIndex(_tierIndex)
    {
        require(_address != address(0), "Address Zero is not allowed");
        feeTiers[_tierIndex].betweenWalletsAddress = _address;
        if (_tierIndex == 0) {
            _defaultFees.betweenWalletsAddress = _address;
        }
    }

    function addTier(
        uint256 _stakingFee,
        uint256 _devFee,
        uint256 _marketingFee,
        uint256 _communityFee,
        uint256 _taxFee,
        uint256 _betweenWalletsFee,
        address _StakingAddress,
        address _DevAddress,
        address _MarketingAddress,
        address _CommunityAddress,
        address _betweenWalletsAddress
    ) public onlyOwner {
        _addTier(
            _stakingFee,
            _devFee,
            _marketingFee,
            _communityFee,
            _taxFee,
            _betweenWalletsFee,
            _StakingAddress,
            _DevAddress,
            _MarketingAddress,
            _CommunityAddress,
            _betweenWalletsAddress
        );
    }

    function updateRouterAndPair(
        address _uniswapV2Router,
        address _uniswapV2Pair
    ) public onlyOwner {
        uniswapV2Router = IUniswapV2Router02(_uniswapV2Router);
        uniswapV2Pair = _uniswapV2Pair;
        WBNB = uniswapV2Router.WETH();
    }

    function setDefaultSettings() external onlyOwner {
        swapAndLiquifyEnabled = true;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    //to receive BNB from uniswapV2Router when swapping
    receive() external payable {}

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal - rFee;
        _tFeeTotal = _tFeeTotal + tFee;
    }

    function _getValues(uint256 tAmount, uint256 _tierIndex)
        private
        view
        returns (FeeValues memory)
    {
        tFeeValues memory tValues = _getTValues(tAmount, _tierIndex);
        uint256 tTransferFee = tValues.tStaking +
            tValues.tDev +
            tValues.tMarketing +
            tValues.tCommunity +
            tValues.tBetweenWallets;
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tValues.tFee,
            tTransferFee,
            _getRate()
        );
        return
            FeeValues(
                rAmount,
                rTransferAmount,
                rFee,
                tValues.tTransferAmount,
                tValues.tStaking,
                tValues.tDev,
                tValues.tMarketing,
                tValues.tCommunity,
                tValues.tBetweenWallets,
                tValues.tFee
            );
    }

    function _getTValues(uint256 tAmount, uint256 _tierIndex)
        private
        view
        returns (tFeeValues memory)
    {
        FeeTier memory tier = feeTiers[_tierIndex];
        tFeeValues memory tValues = tFeeValues(
            0,
            calculateFee(tAmount, tier.stakingFee),
            calculateFee(tAmount, tier.devFee),
            calculateFee(tAmount, tier.marketingFee),
            calculateFee(tAmount, tier.communityFee),
            calculateFee(tAmount, tier.betweenWalletsFee),
            calculateFee(tAmount, tier.taxFee)
        );

        uint256 temp = tAmount -
            tValues.tStaking -
            tValues.tDev -
            tValues.tMarketing;
        tValues.tTransferAmount =
            temp -
            tValues.tCommunity -
            tValues.tBetweenWallets -
            tValues.tFee;
        return tValues;
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tTransferFee,
        uint256 currentRate
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 rAmount = tAmount * currentRate;
        uint256 rFee = tFee * currentRate;
        uint256 rTransferFee = tTransferFee * currentRate;
        uint256 rTransferAmount = rAmount - rFee - rTransferFee;
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        require(tSupply != 0, "Division with 0");
        return rSupply / tSupply;
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);
            rSupply = rSupply - _rOwned[_excluded[i]];
            tSupply = tSupply - _tOwned[_excluded[i]];
        }
        require(_tTotal != 0, "Division with 0");
        if (rSupply < _rTotal / _tTotal) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function calculateFee(uint256 _amount, uint256 _fee)
        private
        pure
        returns (uint256)
    {
        if (_fee == 0) return 0;
        return (_amount * _fee) / (10**4);
    }

    function removeAllFee() private {
        _previousFees = feeTiers[0];
        feeTiers[0] = _emptyFees;
    }

    function restoreAllFee() private {
        feeTiers[0] = _previousFees;
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _isContract(address _addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "BEP20: transfer from the zero address");
        require(to != address(0), "BEP20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        if (from != owner() && to != owner())
            require(
                amount <= _maxTxAmount,
                "Transfer amount exceeds the maxTxAmount."
            );

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));

        if (contractTokenBalance >= _maxTxAmount) {
            contractTokenBalance = _maxTxAmount;
        }

        bool overMinTokenBalance = contractTokenBalance >=
            numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        }

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        uint256 tierIndex = 0;

        if (takeFee) {
            //buy
            if (uniswapV2Pair == from || address(uniswapV2Router) == from) {
                tierIndex = 1;
            }
            //sell
            else if (uniswapV2Pair == to || address(uniswapV2Router) == to) {
                tierIndex = 2;
            }
            //between wallets
            else if (!_isContract(from) && !_isContract(to)) {
                //check if between wallets transfer
                if (_isFeeBetweenWallets) {
                    tierIndex = 3;
                }
            } else {
                tierIndex = _accountsTier[from];

                if (_msgSender() != from) {
                    tierIndex = _accountsTier[_msgSender()];
                }
            }
        }

        _tokenTransfer(from, to, amount, tierIndex, takeFee);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance / 2;
        uint256 otherHalf = contractTokenBalance - half;

        // capture the contract's current BNB balance.
        // this is so that we can capture exactly the amount of BNB that the
        // swap creates, and not make the liquidity event include any BNB that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for BNB
        swapTokensForBnb(half);

        // how much BNB did we just swap into?
        uint256 newBalance = address(this).balance - initialBalance;

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForBnb(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> wbnb
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of BNB
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        uint256 tierIndex,
        bool takeFee
    ) private {
        if (!takeFee) removeAllFee();

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount, tierIndex);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount, tierIndex);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount, tierIndex);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount, tierIndex);
        } else {
            _transferStandard(sender, recipient, amount, tierIndex);
        }

        if (!takeFee) restoreAllFee();
    }

    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount,
        uint256 tierIndex
    ) private {
        FeeValues memory _values = _getValues(tAmount, tierIndex);
        _tOwned[sender] = _tOwned[sender] - tAmount;
        _rOwned[sender] = _rOwned[sender] - _values.rAmount;
        _tOwned[recipient] = _tOwned[recipient] + _values.tTransferAmount;
        _rOwned[recipient] = _rOwned[recipient] + _values.rTransferAmount;
        _takeFees(_values, tierIndex);
        _reflectFee(_values.rFee, _values.tFee);
        emit Transfer(sender, recipient, _values.tTransferAmount);
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount,
        uint256 tierIndex
    ) private {
        FeeValues memory _values = _getValues(tAmount, tierIndex);
        _rOwned[sender] = _rOwned[sender] - _values.rAmount;
        _rOwned[recipient] = _rOwned[recipient] + _values.rTransferAmount;
        _takeFees(_values, tierIndex);
        _reflectFee(_values.rFee, _values.tFee);
        emit Transfer(sender, recipient, _values.tTransferAmount);
    }

    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount,
        uint256 tierIndex
    ) private {
        FeeValues memory _values = _getValues(tAmount, tierIndex);
        _rOwned[sender] = _rOwned[sender] - _values.rAmount;
        _tOwned[recipient] = _tOwned[recipient] + _values.tTransferAmount;
        _rOwned[recipient] = _rOwned[recipient] + _values.rTransferAmount;
        _takeFees(_values, tierIndex);
        _reflectFee(_values.rFee, _values.tFee);
        emit Transfer(sender, recipient, _values.tTransferAmount);
    }

    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount,
        uint256 tierIndex
    ) private {
        FeeValues memory _values = _getValues(tAmount, tierIndex);
        _tOwned[sender] = _tOwned[sender] - tAmount;
        _rOwned[sender] = _rOwned[sender] - _values.rAmount;
        _rOwned[recipient] = _rOwned[recipient] + _values.rTransferAmount;
        _takeFees(_values, tierIndex);
        _reflectFee(_values.rFee, _values.tFee);
        emit Transfer(sender, recipient, _values.tTransferAmount);
    }

    function _takeFees(FeeValues memory values, uint256 tierIndex) private {
        _takeFee(values.tStaking, feeTiers[tierIndex].StakingAddress);
        _takeFee(values.tDev, feeTiers[tierIndex].DevAddress);
        _takeFee(values.tMarketing, feeTiers[tierIndex].MarketingAddress);
        _takeFee(values.tCommunity, feeTiers[tierIndex].CommunityAddress);
        _takeFee(
            values.tBetweenWallets,
            feeTiers[tierIndex].betweenWalletsAddress
        );
    }

    function _takeFee(uint256 tAmount, address recipient) private {
        if (recipient == address(0)) return;
        if (tAmount == 0) return;

        uint256 currentRate = _getRate();
        uint256 rAmount = tAmount * currentRate;
        _rOwned[recipient] = _rOwned[recipient] + rAmount;
        if (_isExcluded[recipient])
            _tOwned[recipient] = _tOwned[recipient] + tAmount;
    }

    function feeTiersLength() public view returns (uint256) {
        return feeTiers.length;
    }
}
