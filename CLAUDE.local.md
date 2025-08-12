# Contracts Package - Contextual Memory

## Key Design Decisions

**Separation of Concerns**: Logic contracts (MirrorPosition) separate from storage (AllocationStore) for security

**Proxy Pattern**: AllocationAccount uses Clones for gas-efficient deployment with deterministic CREATE2 addresses

**GMX Integration**: Asynchronous order execution via callbacks - must handle callback validation and state consistency

## Documentation Practice

**NatSpec Philosophy**: Clear code > verbose docs. Avoid abstract parameter names.
- @notice: Objectively explain core functionality
- @dev: Only for non-obvious behavior, gotchas, or important warnings
- Skip @param - improve parameter names instead of documenting unclear ones
- Skip @return if return variable names are descriptive

**Example**:
```solidity
/**
 * @notice Opens a new mirrored position by allocating puppet funds to copy a trader's position
 * @dev Validates trader position exists, calculates puppet allocations based on rules, submits GMX order
 */
function requestOpen(...) // NOT: @param _account The account contract, @param _puppetList List of puppets...
```

## Security Practice

**Reentrancy Protection**: Built into `auth` modifier - no need for separate `nonReentrant`
- Both Permission and Access contracts include reentrancy guards in their `auth` modifiers
- Uses transient storage (EIP-1153) for gas efficiency
- Functions with `auth` modifier automatically get reentrancy protection

## Audit Practice

**Solidity 0.8+ Overflow Protection**: No need for explicit overflow/underflow checks
- Arithmetic operations automatically revert on overflow/underflow
- Avoid redundant `require` statements for arithmetic safety
