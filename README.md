Changes

1. Floating Pragma
Changed from 
pragma solidity ^0.8.4;  
to 
pragma solidity =0.8.18;

2.State Variable Default Visibility
Changed from 
bool inSwapAndLiquify;
to
bool private inSwapAndLiquify;

3. Missing events arithmetic

    event ExcludedFromFeeUpdated(address _addr, bool excluded);
    event FeeBetweenWalletsUpdated(bool excluded);

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

4. Costly operations inside a loop

Added local valirables _temp and Alength

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

5. Using SafeMath in Solidity 0.8.0+

Removing SafeMath
5.1 transferFrom changed
    
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
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
    
5.2 decreaseAllowence changed

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

5.3
add() changed to +
div() changed to /
mul() changed to *
sub() changed to -

6. Inital Supply //

7.Reliance on third-parties

Third-parties can be modified by the Owner in intentions to keep the token safe.

