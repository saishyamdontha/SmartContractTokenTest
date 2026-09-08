// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {

  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;

  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";

  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //
  // ------------------------------------------ //

  mapping (address => mapping (address => uint256)) private _allowances;

  // Holder bookkeeping: `_holders` is the list of addresses with a
  // non-zero balance. `_holderIndex` stores each holder's 1-based
  // position in `_holders` (0 means "not currently a holder"), so we
  // can add/remove a holder in O(1) via swap-and-pop instead of
  // scanning the whole array.
  address[] private _holders;
  mapping (address => uint256) private _holderIndex;

  // Dividend amounts a holder is entitled to withdraw. This is
  // intentionally decoupled from balanceOf: recordDividend() credits
  // this mapping once, at the moment it's called, based on each
  // holder's balance *at that moment*. A later transfer or burn never
  // touches this mapping, so a holder keeps what they were already
  // credited even after giving up their tokens.
  mapping (address => uint256) private _withdrawableDividend;

  // --- internal holder-list helpers ---

  function _addHolder(address who) private {
    if (_holderIndex[who] == 0) {
      _holders.push(who);
      _holderIndex[who] = _holders.length;
    }
  }

  function _removeHolder(address who) private {
    uint256 idx = _holderIndex[who];
    if (idx == 0) {
      return;
    }
    uint256 lastIdx = _holders.length;
    address lastHolder = _holders[lastIdx - 1];
    _holders[idx - 1] = lastHolder;
    _holderIndex[lastHolder] = idx;
    _holders.pop();
    _holderIndex[who] = 0;
  }

  function _syncHolder(address who) private {
    if (balanceOf[who] > 0) {
      _addHolder(who);
    } else {
      _removeHolder(who);
    }
  }

  function _transferTokens(address from, address to, uint256 value) private {
    require(balanceOf[from] >= value, "Token: insufficient balance");
    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);
    _syncHolder(from);
    _syncHolder(to);
  }

  // --- IERC20 ---

  function allowance(address owner, address spender) external view override returns (uint256) {
    return _allowances[owner][spender];
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    _transferTokens(msg.sender, to, value);
    return true;
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    _allowances[msg.sender][spender] = value;
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    require(_allowances[from][msg.sender] >= value, "Token: allowance exceeded");
    _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value);
    _transferTokens(from, to, value);
    return true;
  }

  // --- IMintableToken ---

  function mint() external payable override {
    require(msg.value > 0, "Token: no ETH sent");
    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);
    _syncHolder(msg.sender);
  }

  function burn(address payable dest) external override {
    uint256 bal = balanceOf[msg.sender];
    require(bal > 0, "Token: nothing to burn");
    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(bal);
    _syncHolder(msg.sender);
    dest.transfer(bal);
  }

  // --- IDividends ---

  function getNumTokenHolders() external view override returns (uint256) {
    return _holders.length;
  }

  function getTokenHolder(uint256 index) external view override returns (address) {
    if (index == 0 || index > _holders.length) {
      return address(0);
    }
    return _holders[index - 1];
  }

  function recordDividend() external payable override {
    require(msg.value > 0, "Token: no dividend sent");
    require(totalSupply > 0, "Token: no token holders");
    for (uint256 i = 0; i < _holders.length; i += 1) {
      address holder = _holders[i];
      uint256 share = msg.value.mul(balanceOf[holder]).div(totalSupply);
      _withdrawableDividend[holder] = _withdrawableDividend[holder].add(share);
    }
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return _withdrawableDividend[payee];
  }

  function withdrawDividend(address payable dest) external override {
    uint256 amount = _withdrawableDividend[msg.sender];
    _withdrawableDividend[msg.sender] = 0;
    dest.transfer(amount);
  }
}
