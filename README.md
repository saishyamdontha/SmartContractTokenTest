# Token Contract — Technical Assessment

A mintable ERC-20-style token backed 1:1 by deposited ETH, with dividend
distribution proportional to token holdings.

## Setup

```bash
npm install
npm run test
```

## Design notes

- **Holder tracking**: `_holders` is a dynamic array of addresses with a
  non-zero balance; `_holderIndex` maps each address to its 1-based
  position in that array, so adding/removing a holder is O(1) via
  swap-and-pop instead of a linear scan.
- **Dividend accounting**: `recordDividend()` computes each current
  holder's proportional share once, at call time, and credits it to a
  separate `_withdrawableDividend` mapping. This mapping is never
  touched by `transfer`/`burn`, so a holder keeps whatever they were
  already credited even after giving up their tokens later — matching
  the spec's requirement that dividends stay tied to the holder's
  balance *at the time the dividend was recorded*.
- **Gas**: iterating `_holders` in `recordDividend()` is unavoidable
  given the spec's "loop through holders" requirement, but holder
  add/remove itself avoids any array scanning.
# SmartContractTokenTest
