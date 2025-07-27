# Fork Test Gas Analysis

**Network:** Arbitrum One (Chain ID: 42161)  
**Purpose:** Empirical gas measurement for sequencer operations

## Latest Results (2025-01-25)

### Mirror Operations

| Puppets | Gas Used | 
|---------|----------|
| 1 | 1,291,391 |
| 2 | 1,121,433 |
| 3 | 1,113,345 |

### Settle Operations

| Puppets | Gas Used |
|---------|----------|
| 1 | 96,842 |
| 2 | 55,736 |
| 3 | 59,028 |

## Deployed Configuration

| Operation | Base Gas | Per-Puppet Gas |
|-----------|----------|----------------|
| Mirror | 1,283,731 | 30,000 |
| Adjust | 910,663 | 3,412 |
| Settle | 90,847 | 15,000 |


## Notes

- Gas usage decreases with more puppets due to batch efficiency
- Settle operations show significant optimization with multiple puppets
- Current deployment values provide adequate safety margins
- Adjust operations require empirical measurement

## Run Tests

```bash
RPC_URL=<arbitrum-rpc> forge test --match-path "test/integration/Trading.fork.t.sol" -vv
```

**Last Updated:** 2025-01-25
