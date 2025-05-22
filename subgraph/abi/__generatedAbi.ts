//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Access
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const accessAbi = [
  {
    type: 'function',
    inputs: [],
    name: 'authority',
    outputs: [{ name: '', internalType: 'contract IAuthority', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'user', internalType: 'address', type: 'address' }],
    name: 'canCall',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'isEnabled', internalType: 'bool', type: 'bool' }
    ],
    name: 'setAccess',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  { type: 'error', inputs: [], name: 'Access__CallerNotAuthority' }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Address
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const addressAbi = [
  {
    type: 'error',
    inputs: [{ name: 'target', internalType: 'address', type: 'address' }],
    name: 'AddressEmptyCode'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// AllocationAccount
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const allocationAccountAbi = [
  {
    type: 'constructor',
    inputs: [{ name: '_store', internalType: 'contract Access', type: 'address' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: '_contract', internalType: 'address', type: 'address' },
      { name: '_data', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'execute',
    outputs: [
      { name: '_success', internalType: 'bool', type: 'bool' },
      { name: '_returnData', internalType: 'bytes', type: 'bytes' }
    ],
    stateMutability: 'payable'
  },
  { type: 'error', inputs: [], name: 'Subaccount__UnauthorizedOperator' }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// AllocationStore
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const allocationStoreAbi = [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_authority',
        internalType: 'contract IAuthority',
        type: 'address'
      },
      {
        name: '_router',
        internalType: 'contract TokenRouter',
        type: 'address'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'authority',
    outputs: [{ name: '', internalType: 'contract IAuthority', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'user', internalType: 'address', type: 'address' }],
    name: 'canCall',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: '_token', internalType: 'contract IERC20', type: 'address' },
      { name: '_userList', internalType: 'address[]', type: 'address[]' }
    ],
    name: 'getBalanceList',
    outputs: [{ name: '', internalType: 'uint256[]', type: 'uint256[]' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: '_token', internalType: 'contract IERC20', type: 'address' }],
    name: 'getTokenBalance',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: '_token', internalType: 'contract IERC20', type: 'address' },
      { name: '_bank', internalType: 'contract BankStore', type: 'address' },
      { name: '_value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'interTransferIn',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '_token', internalType: 'contract IERC20', type: 'address' }],
    name: 'recordTransferIn',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'isEnabled', internalType: 'bool', type: 'bool' }
    ],
    name: 'setAccess',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: '_token', internalType: 'contract IERC20', type: 'address' },
      { name: '_accountList', internalType: 'address[]', type: 'address[]' },
      { name: '_balanceList', internalType: 'uint256[]', type: 'uint256[]' }
    ],
    name: 'setBalanceList',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: '_token', internalType: 'contract IERC20', type: 'address' },
      { name: '_account', internalType: 'address', type: 'address' },
      { name: '_value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'setUserBalance',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '_token', internalType: 'contract IERC20', type: 'address' }],
    name: 'syncTokenBalance',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'contract IERC20', type: 'address' }],
    name: 'tokenBalanceMap',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: '_token', internalType: 'contract IERC20', type: 'address' },
      { name: '_depositor', internalType: 'address', type: 'address' },
      { name: '_value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transferIn',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: '_token', internalType: 'contract IERC20', type: 'address' },
      { name: '_receiver', internalType: 'address', type: 'address' },
      { name: '_value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transferOut',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'token', internalType: 'contract IERC20', type: 'address' },
      { name: 'user', internalType: 'address', type: 'address' }
    ],
    name: 'userBalanceMap',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  { type: 'error', inputs: [], name: 'Access__CallerNotAuthority' },
  { type: 'error', inputs: [], name: 'Access__Unauthorized' },
  { type: 'error', inputs: [], name: 'BankStore__InsufficientBalance' }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BankStore
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const bankStoreAbi = [
  {
    type: 'function',
    inputs: [],
    name: 'authority',
    outputs: [{ name: '', internalType: 'contract IAuthority', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'user', internalType: 'address', type: 'address' }],
    name: 'canCall',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: '_token', internalType: 'contract IERC20', type: 'address' }],
    name: 'getTokenBalance',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: '_token', internalType: 'contract IERC20', type: 'address' },
      { name: '_bank', internalType: 'contract BankStore', type: 'address' },
      { name: '_value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'interTransferIn',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '_token', internalType: 'contract IERC20', type: 'address' }],
    name: 'recordTransferIn',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'isEnabled', internalType: 'bool', type: 'bool' }
    ],
    name: 'setAccess',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '_token', internalType: 'contract IERC20', type: 'address' }],
    name: 'syncTokenBalance',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'contract IERC20', type: 'address' }],
    name: 'tokenBalanceMap',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: '_token', internalType: 'contract IERC20', type: 'address' },
      { name: '_depositor', internalType: 'address', type: 'address' },
      { name: '_value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transferIn',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: '_token', internalType: 'contract IERC20', type: 'address' },
      { name: '_receiver', internalType: 'address', type: 'address' },
      { name: '_value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transferOut',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  { type: 'error', inputs: [], name: 'Access__CallerNotAuthority' },
  { type: 'error', inputs: [], name: 'Access__Unauthorized' },
  { type: 'error', inputs: [], name: 'BankStore__InsufficientBalance' }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Checkpoints
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const checkpointsAbi = [{ type: 'error', inputs: [], name: 'CheckpointUnorderedInsertion' }] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// CoreContract
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const coreContractAbi = [
  {
    type: 'function',
    inputs: [],
    name: 'authority',
    outputs: [{ name: '', internalType: 'contract IAuthority', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'signatureHash', internalType: 'bytes4', type: 'bytes4' },
      { name: 'user', internalType: 'address', type: 'address' }
    ],
    name: 'canCall',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'data', internalType: 'bytes', type: 'bytes' }],
    name: 'setConfig',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'functionSig', internalType: 'bytes4', type: 'bytes4' },
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'isEnabled', internalType: 'bool', type: 'bool' }
    ],
    name: 'setPermission',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  { type: 'error', inputs: [], name: 'Permission__CallerNotAuthority' }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Dictatorship
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const dictatorshipAbi = [
  {
    type: 'constructor',
    inputs: [{ name: 'initialOwner', internalType: 'address', type: 'address' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'address', type: 'address' }],
    name: 'contractAccessRegistry',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'target', internalType: 'contract Access', type: 'address' },
      { name: 'user', internalType: 'address', type: 'address' }
    ],
    name: 'hasAccess',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'target', internalType: 'contract Permission', type: 'address' },
      { name: 'functionSig', internalType: 'bytes4', type: 'bytes4' },
      { name: 'user', internalType: 'address', type: 'address' }
    ],
    name: 'hasPermission',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'target',
        internalType: 'contract CoreContract',
        type: 'address'
      },
      { name: 'config', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'initContract',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'method', internalType: 'string', type: 'string' },
      { name: 'data', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'logEvent',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'owner',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'target', internalType: 'contract Access', type: 'address' },
      { name: 'user', internalType: 'address', type: 'address' }
    ],
    name: 'removeAccess',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'target',
        internalType: 'contract CoreContract',
        type: 'address'
      }
    ],
    name: 'removeContract',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'target', internalType: 'contract Permission', type: 'address' },
      { name: 'functionSig', internalType: 'bytes4', type: 'bytes4' },
      { name: 'user', internalType: 'address', type: 'address' }
    ],
    name: 'removePermission',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'renounceOwnership',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'target', internalType: 'contract Access', type: 'address' },
      { name: 'user', internalType: 'address', type: 'address' }
    ],
    name: 'setAccess',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'target',
        internalType: 'contract CoreContract',
        type: 'address'
      },
      { name: 'config', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'setConfig',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'target', internalType: 'contract Permission', type: 'address' },
      { name: 'functionSig', internalType: 'bytes4', type: 'bytes4' },
      { name: 'user', internalType: 'address', type: 'address' }
    ],
    name: 'setPermission',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'newOwner', internalType: 'address', type: 'address' }],
    name: 'transferOwnership',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'target',
        internalType: 'address',
        type: 'address',
        indexed: true
      }
    ],
    name: 'AddContractAccess'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'operator',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      { name: 'method', internalType: 'string', type: 'string', indexed: true },
      { name: 'data', internalType: 'bytes', type: 'bytes', indexed: false }
    ],
    name: 'LogEvent'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'previousOwner',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'newOwner',
        internalType: 'address',
        type: 'address',
        indexed: true
      }
    ],
    name: 'OwnershipTransferred'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'target',
        internalType: 'address',
        type: 'address',
        indexed: true
      }
    ],
    name: 'RemoveContractAccess'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'target',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      { name: 'config', internalType: 'bytes', type: 'bytes', indexed: false }
    ],
    name: 'SetConfig'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'target',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      { name: 'user', internalType: 'address', type: 'address', indexed: true },
      { name: 'enabled', internalType: 'bool', type: 'bool', indexed: false }
    ],
    name: 'UpdateAccess'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'target',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      { name: 'user', internalType: 'address', type: 'address', indexed: true },
      {
        name: 'functionSig',
        internalType: 'bytes4',
        type: 'bytes4',
        indexed: true
      },
      { name: 'enabled', internalType: 'bool', type: 'bool', indexed: false }
    ],
    name: 'UpdatePermission'
  },
  {
    type: 'error',
    inputs: [],
    name: 'Dictatorship__ConfigurationUpdateFailed'
  },
  {
    type: 'error',
    inputs: [],
    name: 'Dictatorship__ContractAlreadyInitialized'
  },
  { type: 'error', inputs: [], name: 'Dictatorship__ContractNotInitialized' },
  {
    type: 'error',
    inputs: [{ name: 'owner', internalType: 'address', type: 'address' }],
    name: 'OwnableInvalidOwner'
  },
  {
    type: 'error',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'OwnableUnauthorizedAccount'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ECDSA
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const ecdsaAbi = [
  { type: 'error', inputs: [], name: 'ECDSAInvalidSignature' },
  {
    type: 'error',
    inputs: [{ name: 'length', internalType: 'uint256', type: 'uint256' }],
    name: 'ECDSAInvalidSignatureLength'
  },
  {
    type: 'error',
    inputs: [{ name: 's', internalType: 'bytes32', type: 'bytes32' }],
    name: 'ECDSAInvalidSignatureS'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// EIP712
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const eip712Abi = [
  {
    type: 'function',
    inputs: [],
    name: 'eip712Domain',
    outputs: [
      { name: 'fields', internalType: 'bytes1', type: 'bytes1' },
      { name: 'name', internalType: 'string', type: 'string' },
      { name: 'version', internalType: 'string', type: 'string' },
      { name: 'chainId', internalType: 'uint256', type: 'uint256' },
      { name: 'verifyingContract', internalType: 'address', type: 'address' },
      { name: 'salt', internalType: 'bytes32', type: 'bytes32' },
      { name: 'extensions', internalType: 'uint256[]', type: 'uint256[]' }
    ],
    stateMutability: 'view'
  },
  { type: 'event', anonymous: false, inputs: [], name: 'EIP712DomainChanged' },
  { type: 'error', inputs: [], name: 'InvalidShortString' },
  {
    type: 'error',
    inputs: [{ name: 'str', internalType: 'string', type: 'string' }],
    name: 'StringTooLong'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ERC165
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const erc165Abi = [
  {
    type: 'function',
    inputs: [{ name: 'interfaceId', internalType: 'bytes4', type: 'bytes4' }],
    name: 'supportsInterface',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ERC1967Utils
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const erc1967UtilsAbi = [
  {
    type: 'error',
    inputs: [{ name: 'admin', internalType: 'address', type: 'address' }],
    name: 'ERC1967InvalidAdmin'
  },
  {
    type: 'error',
    inputs: [{ name: 'beacon', internalType: 'address', type: 'address' }],
    name: 'ERC1967InvalidBeacon'
  },
  {
    type: 'error',
    inputs: [{ name: 'implementation', internalType: 'address', type: 'address' }],
    name: 'ERC1967InvalidImplementation'
  },
  { type: 'error', inputs: [], name: 'ERC1967NonPayable' }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ERC20
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const erc20Abi = [
  {
    type: 'function',
    inputs: [
      { name: 'owner', internalType: 'address', type: 'address' },
      { name: 'spender', internalType: 'address', type: 'address' }
    ],
    name: 'allowance',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'spender', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'approve',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'decimals',
    outputs: [{ name: '', internalType: 'uint8', type: 'uint8' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'name',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'symbol',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'totalSupply',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transfer',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'from', internalType: 'address', type: 'address' },
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transferFrom',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'owner',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'spender',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'value',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Approval'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'from', internalType: 'address', type: 'address', indexed: true },
      { name: 'to', internalType: 'address', type: 'address', indexed: true },
      {
        name: 'value',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Transfer'
  },
  {
    type: 'error',
    inputs: [
      { name: 'spender', internalType: 'address', type: 'address' },
      { name: 'allowance', internalType: 'uint256', type: 'uint256' },
      { name: 'needed', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'ERC20InsufficientAllowance'
  },
  {
    type: 'error',
    inputs: [
      { name: 'sender', internalType: 'address', type: 'address' },
      { name: 'balance', internalType: 'uint256', type: 'uint256' },
      { name: 'needed', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'ERC20InsufficientBalance'
  },
  {
    type: 'error',
    inputs: [{ name: 'approver', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidApprover'
  },
  {
    type: 'error',
    inputs: [{ name: 'receiver', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidReceiver'
  },
  {
    type: 'error',
    inputs: [{ name: 'sender', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidSender'
  },
  {
    type: 'error',
    inputs: [{ name: 'spender', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidSpender'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ERC20Burnable
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const erc20BurnableAbi = [
  {
    type: 'function',
    inputs: [
      { name: 'owner', internalType: 'address', type: 'address' },
      { name: 'spender', internalType: 'address', type: 'address' }
    ],
    name: 'allowance',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'spender', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'approve',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'value', internalType: 'uint256', type: 'uint256' }],
    name: 'burn',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'burnFrom',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'decimals',
    outputs: [{ name: '', internalType: 'uint8', type: 'uint8' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'name',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'symbol',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'totalSupply',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transfer',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'from', internalType: 'address', type: 'address' },
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transferFrom',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'owner',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'spender',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'value',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Approval'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'from', internalType: 'address', type: 'address', indexed: true },
      { name: 'to', internalType: 'address', type: 'address', indexed: true },
      {
        name: 'value',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Transfer'
  },
  {
    type: 'error',
    inputs: [
      { name: 'spender', internalType: 'address', type: 'address' },
      { name: 'allowance', internalType: 'uint256', type: 'uint256' },
      { name: 'needed', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'ERC20InsufficientAllowance'
  },
  {
    type: 'error',
    inputs: [
      { name: 'sender', internalType: 'address', type: 'address' },
      { name: 'balance', internalType: 'uint256', type: 'uint256' },
      { name: 'needed', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'ERC20InsufficientBalance'
  },
  {
    type: 'error',
    inputs: [{ name: 'approver', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidApprover'
  },
  {
    type: 'error',
    inputs: [{ name: 'receiver', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidReceiver'
  },
  {
    type: 'error',
    inputs: [{ name: 'sender', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidSender'
  },
  {
    type: 'error',
    inputs: [{ name: 'spender', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidSpender'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ERC20Votes
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const erc20VotesAbi = [
  {
    type: 'function',
    inputs: [],
    name: 'CLOCK_MODE',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'owner', internalType: 'address', type: 'address' },
      { name: 'spender', internalType: 'address', type: 'address' }
    ],
    name: 'allowance',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'spender', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'approve',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'pos', internalType: 'uint32', type: 'uint32' }
    ],
    name: 'checkpoints',
    outputs: [
      {
        name: '',
        internalType: 'struct Checkpoints.Checkpoint208',
        type: 'tuple',
        components: [
          { name: '_key', internalType: 'uint48', type: 'uint48' },
          { name: '_value', internalType: 'uint208', type: 'uint208' }
        ]
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'clock',
    outputs: [{ name: '', internalType: 'uint48', type: 'uint48' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'decimals',
    outputs: [{ name: '', internalType: 'uint8', type: 'uint8' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'delegatee', internalType: 'address', type: 'address' }],
    name: 'delegate',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'delegatee', internalType: 'address', type: 'address' },
      { name: 'nonce', internalType: 'uint256', type: 'uint256' },
      { name: 'expiry', internalType: 'uint256', type: 'uint256' },
      { name: 'v', internalType: 'uint8', type: 'uint8' },
      { name: 'r', internalType: 'bytes32', type: 'bytes32' },
      { name: 's', internalType: 'bytes32', type: 'bytes32' }
    ],
    name: 'delegateBySig',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'delegates',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'eip712Domain',
    outputs: [
      { name: 'fields', internalType: 'bytes1', type: 'bytes1' },
      { name: 'name', internalType: 'string', type: 'string' },
      { name: 'version', internalType: 'string', type: 'string' },
      { name: 'chainId', internalType: 'uint256', type: 'uint256' },
      { name: 'verifyingContract', internalType: 'address', type: 'address' },
      { name: 'salt', internalType: 'bytes32', type: 'bytes32' },
      { name: 'extensions', internalType: 'uint256[]', type: 'uint256[]' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'timepoint', internalType: 'uint256', type: 'uint256' }],
    name: 'getPastTotalSupply',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'timepoint', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'getPastVotes',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'getVotes',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'name',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'owner', internalType: 'address', type: 'address' }],
    name: 'nonces',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'numCheckpoints',
    outputs: [{ name: '', internalType: 'uint32', type: 'uint32' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'symbol',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'totalSupply',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transfer',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'from', internalType: 'address', type: 'address' },
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transferFrom',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'owner',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'spender',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'value',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Approval'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'delegator',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'fromDelegate',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'toDelegate',
        internalType: 'address',
        type: 'address',
        indexed: true
      }
    ],
    name: 'DelegateChanged'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'delegate',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'previousVotes',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'newVotes',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'DelegateVotesChanged'
  },
  { type: 'event', anonymous: false, inputs: [], name: 'EIP712DomainChanged' },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'from', internalType: 'address', type: 'address', indexed: true },
      { name: 'to', internalType: 'address', type: 'address', indexed: true },
      {
        name: 'value',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Transfer'
  },
  { type: 'error', inputs: [], name: 'CheckpointUnorderedInsertion' },
  { type: 'error', inputs: [], name: 'ECDSAInvalidSignature' },
  {
    type: 'error',
    inputs: [{ name: 'length', internalType: 'uint256', type: 'uint256' }],
    name: 'ECDSAInvalidSignatureLength'
  },
  {
    type: 'error',
    inputs: [{ name: 's', internalType: 'bytes32', type: 'bytes32' }],
    name: 'ECDSAInvalidSignatureS'
  },
  {
    type: 'error',
    inputs: [
      { name: 'increasedSupply', internalType: 'uint256', type: 'uint256' },
      { name: 'cap', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'ERC20ExceededSafeSupply'
  },
  {
    type: 'error',
    inputs: [
      { name: 'spender', internalType: 'address', type: 'address' },
      { name: 'allowance', internalType: 'uint256', type: 'uint256' },
      { name: 'needed', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'ERC20InsufficientAllowance'
  },
  {
    type: 'error',
    inputs: [
      { name: 'sender', internalType: 'address', type: 'address' },
      { name: 'balance', internalType: 'uint256', type: 'uint256' },
      { name: 'needed', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'ERC20InsufficientBalance'
  },
  {
    type: 'error',
    inputs: [{ name: 'approver', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidApprover'
  },
  {
    type: 'error',
    inputs: [{ name: 'receiver', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidReceiver'
  },
  {
    type: 'error',
    inputs: [{ name: 'sender', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidSender'
  },
  {
    type: 'error',
    inputs: [{ name: 'spender', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidSpender'
  },
  {
    type: 'error',
    inputs: [
      { name: 'timepoint', internalType: 'uint256', type: 'uint256' },
      { name: 'clock', internalType: 'uint48', type: 'uint48' }
    ],
    name: 'ERC5805FutureLookup'
  },
  { type: 'error', inputs: [], name: 'ERC6372InconsistentClock' },
  {
    type: 'error',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'currentNonce', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'InvalidAccountNonce'
  },
  { type: 'error', inputs: [], name: 'InvalidShortString' },
  {
    type: 'error',
    inputs: [
      { name: 'bits', internalType: 'uint8', type: 'uint8' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'SafeCastOverflowedUintDowncast'
  },
  {
    type: 'error',
    inputs: [{ name: 'str', internalType: 'string', type: 'string' }],
    name: 'StringTooLong'
  },
  {
    type: 'error',
    inputs: [{ name: 'expiry', internalType: 'uint256', type: 'uint256' }],
    name: 'VotesExpiredSignature'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Error
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const errorAbi = [
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'reason',
        internalType: 'string',
        type: 'string',
        indexed: false
      },
      {
        name: 'returndata',
        internalType: 'bytes',
        type: 'bytes',
        indexed: false
      }
    ],
    name: 'TransferUtils__TokenTransferReverted'
  },
  { type: 'error', inputs: [], name: 'Access__CallerNotAuthority' },
  { type: 'error', inputs: [], name: 'Access__Unauthorized' },
  { type: 'error', inputs: [], name: 'BankStore__InsufficientBalance' },
  {
    type: 'error',
    inputs: [{ name: 'target', internalType: 'address', type: 'address' }],
    name: 'CallUtils__AddressEmptyCode'
  },
  { type: 'error', inputs: [], name: 'CallUtils__EmptyReceiver' },
  { type: 'error', inputs: [], name: 'CallUtils__FailedInnerCall' },
  {
    type: 'error',
    inputs: [{ name: 'token', internalType: 'address', type: 'address' }],
    name: 'CallUtils__SafeERC20FailedOperation'
  },
  {
    type: 'error',
    inputs: [
      { name: 'contractName', internalType: 'string', type: 'string' },
      { name: 'version', internalType: 'string', type: 'string' }
    ],
    name: 'CoreContract__Unauthorized'
  },
  {
    type: 'error',
    inputs: [],
    name: 'Dictatorship__ConfigurationUpdateFailed'
  },
  {
    type: 'error',
    inputs: [],
    name: 'Dictatorship__ContractAlreadyInitialized'
  },
  { type: 'error', inputs: [], name: 'Dictatorship__ContractNotInitialized' },
  {
    type: 'error',
    inputs: [{ name: 'accruedReward', internalType: 'uint256', type: 'uint256' }],
    name: 'FeeMarketplace__InsufficientUnlockedBalance'
  },
  { type: 'error', inputs: [], name: 'FeeMarketplace__NotAuctionableToken' },
  { type: 'error', inputs: [], name: 'FeeMarketplace__ZeroDeposit' },
  {
    type: 'error',
    inputs: [
      {
        name: 'orderType',
        internalType: 'enum GmxPositionUtils.OrderType',
        type: 'uint8'
      }
    ],
    name: 'GmxExecutionCallback__InvalidOrderType'
  },
  {
    type: 'error',
    inputs: [{ name: 'allowanceCap', internalType: 'uint256', type: 'uint256' }],
    name: 'MatchingRule__AllowanceAboveLimit'
  },
  { type: 'error', inputs: [], name: 'MatchingRule__InsufficientBalance' },
  {
    type: 'error',
    inputs: [
      {
        name: 'minAllocationActivity',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'maxAllocationActivity',
        internalType: 'uint256',
        type: 'uint256'
      }
    ],
    name: 'MatchingRule__InvalidActivityThrottle'
  },
  {
    type: 'error',
    inputs: [
      { name: 'min', internalType: 'uint256', type: 'uint256' },
      { name: 'max', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'MatchingRule__InvalidAllowanceRate'
  },
  { type: 'error', inputs: [], name: 'MatchingRule__InvalidAmount' },
  {
    type: 'error',
    inputs: [{ name: 'minExpiryDuration', internalType: 'uint256', type: 'uint256' }],
    name: 'MatchingRule__InvalidExpiryDuration'
  },
  { type: 'error', inputs: [], name: 'MatchingRule__TokenNotAllowed' },
  {
    type: 'error',
    inputs: [],
    name: 'MirrorPosition__AllocationAccountNotFound'
  },
  {
    type: 'error',
    inputs: [],
    name: 'MirrorPosition__AmountExceedsDustThreshold'
  },
  { type: 'error', inputs: [], name: 'MirrorPosition__DustThresholdNotSet' },
  { type: 'error', inputs: [], name: 'MirrorPosition__DustTransferFailed' },
  {
    type: 'error',
    inputs: [],
    name: 'MirrorPosition__ExecuteOnZeroCollateralPosition'
  },
  {
    type: 'error',
    inputs: [],
    name: 'MirrorPosition__ExecutionRequestMissing'
  },
  { type: 'error', inputs: [], name: 'MirrorPosition__InitialMustBeIncrease' },
  {
    type: 'error',
    inputs: [],
    name: 'MirrorPosition__InsufficientGmxExecutionFee'
  },
  {
    type: 'error',
    inputs: [],
    name: 'MirrorPosition__InsufficientSettledBalanceForKeeperFee'
  },
  { type: 'error', inputs: [], name: 'MirrorPosition__InvalidAllocation' },
  {
    type: 'error',
    inputs: [],
    name: 'MirrorPosition__InvalidAllocationOrFullyReduced'
  },
  { type: 'error', inputs: [], name: 'MirrorPosition__InvalidCollateralDelta' },
  { type: 'error', inputs: [], name: 'MirrorPosition__InvalidCurrentLeverage' },
  {
    type: 'error',
    inputs: [],
    name: 'MirrorPosition__InvalidKeeperExeuctionFeeAmount'
  },
  {
    type: 'error',
    inputs: [],
    name: 'MirrorPosition__InvalidKeeperExeuctionFeeReceiver'
  },
  { type: 'error', inputs: [], name: 'MirrorPosition__InvalidReceiver' },
  { type: 'error', inputs: [], name: 'MirrorPosition__InvalidSizeDelta' },
  {
    type: 'error',
    inputs: [],
    name: 'MirrorPosition__KeeperAdjustmentExecutionFeeExceedsAllocatedAmount'
  },
  {
    type: 'error',
    inputs: [],
    name: 'MirrorPosition__KeeperFeeExceedsCostFactor'
  },
  { type: 'error', inputs: [], name: 'MirrorPosition__MaxPuppetList' },
  { type: 'error', inputs: [], name: 'MirrorPosition__NoAdjustmentRequired' },
  { type: 'error', inputs: [], name: 'MirrorPosition__NoDustToCollect' },
  { type: 'error', inputs: [], name: 'MirrorPosition__NoNetFundsAllocated' },
  { type: 'error', inputs: [], name: 'MirrorPosition__OrderCreationFailed' },
  { type: 'error', inputs: [], name: 'MirrorPosition__PositionNotFound' },
  { type: 'error', inputs: [], name: 'MirrorPosition__PuppetListEmpty' },
  {
    type: 'error',
    inputs: [],
    name: 'MirrorPosition__SettlementTransferFailed'
  },
  { type: 'error', inputs: [], name: 'MirrorPosition__TraderCollateralZero' },
  {
    type: 'error',
    inputs: [],
    name: 'MirrorPosition__ZeroCollateralOnIncrease'
  },
  { type: 'error', inputs: [], name: 'Permission__CallerNotAuthority' },
  { type: 'error', inputs: [], name: 'Permission__Unauthorized' },
  { type: 'error', inputs: [], name: 'PuppetStore__OverwriteAllocation' },
  { type: 'error', inputs: [], name: 'PuppetToken__CoreShareExceedsMining' },
  {
    type: 'error',
    inputs: [
      { name: 'rateLimit', internalType: 'uint256', type: 'uint256' },
      { name: 'emissionRate', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'PuppetToken__ExceededRateLimit'
  },
  { type: 'error', inputs: [], name: 'PuppetToken__InvalidRate' },
  {
    type: 'error',
    inputs: [{ name: 'accured', internalType: 'uint256', type: 'uint256' }],
    name: 'RewardDistributor__InsufficientRewards'
  },
  { type: 'error', inputs: [], name: 'RewardDistributor__InvalidAmount' },
  { type: 'error', inputs: [], name: 'Store__InvalidLength' },
  { type: 'error', inputs: [], name: 'Subaccount__AlreadyInitialized' },
  { type: 'error', inputs: [], name: 'Subaccount__OnlyFactory' },
  { type: 'error', inputs: [], name: 'Subaccount__UnauthorizedCreator' },
  { type: 'error', inputs: [], name: 'Subaccount__UnauthorizedOperator' },
  { type: 'error', inputs: [], name: 'TransferUtils__EmptyHoldingAddress' },
  {
    type: 'error',
    inputs: [{ name: 'token', internalType: 'contract IERC20', type: 'address' }],
    name: 'TransferUtils__EmptyTokenTranferGasLimit'
  },
  {
    type: 'error',
    inputs: [
      { name: 'token', internalType: 'contract IERC20', type: 'address' },
      { name: 'receiver', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'TransferUtils__TokenTransferError'
  },
  { type: 'error', inputs: [], name: 'VotingEscrowLogic__ExceedMaxTime' },
  {
    type: 'error',
    inputs: [{ name: 'accured', internalType: 'uint256', type: 'uint256' }],
    name: 'VotingEscrowLogic__ExceedingAccruedAmount'
  },
  { type: 'error', inputs: [], name: 'VotingEscrowLogic__ZeroAmount' },
  { type: 'error', inputs: [], name: 'VotingEscrow__Unsupported' }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Errors
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const errorsAbi = [
  { type: 'error', inputs: [], name: 'FailedCall' },
  { type: 'error', inputs: [], name: 'FailedDeployment' },
  {
    type: 'error',
    inputs: [
      { name: 'balance', internalType: 'uint256', type: 'uint256' },
      { name: 'needed', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'InsufficientBalance'
  },
  {
    type: 'error',
    inputs: [{ name: '', internalType: 'address', type: 'address' }],
    name: 'MissingPrecompile'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// FeeMarketplace
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const feeMarketplaceAbi = [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_authority',
        internalType: 'contract IAuthority',
        type: 'address'
      },
      {
        name: '_tokenRouter',
        internalType: 'contract TokenRouter',
        type: 'address'
      },
      {
        name: '_store',
        internalType: 'contract FeeMarketplaceStore',
        type: 'address'
      },
      {
        name: '_protocolToken',
        internalType: 'contract PuppetToken',
        type: 'address'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: '_feeToken', internalType: 'contract IERC20', type: 'address' },
      { name: '_depositor', internalType: 'address', type: 'address' },
      { name: '_receiver', internalType: 'address', type: 'address' },
      { name: '_purchaseAmount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'acceptOffer',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'contract IERC20', type: 'address' }],
    name: 'accruedFee',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'contract IERC20', type: 'address' }],
    name: 'askAmount',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'authority',
    outputs: [{ name: '', internalType: 'contract IAuthority', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'signatureHash', internalType: 'bytes4', type: 'bytes4' },
      { name: 'user', internalType: 'address', type: 'address' }
    ],
    name: 'canCall',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'config',
    outputs: [
      {
        name: 'feeDistributor',
        internalType: 'contract BankStore',
        type: 'address'
      },
      {
        name: 'distributionTimeframe',
        internalType: 'uint256',
        type: 'uint256'
      },
      { name: 'burnBasisPoints', internalType: 'uint256', type: 'uint256' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: '_feeToken', internalType: 'contract IERC20', type: 'address' },
      { name: '_bank', internalType: 'contract BankStore', type: 'address' },
      { name: '_amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'deposit',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'feeToken', internalType: 'contract IERC20', type: 'address' }],
    name: 'getPendingUnlock',
    outputs: [{ name: 'pending', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'feeToken', internalType: 'contract IERC20', type: 'address' }],
    name: 'getTotalUnlocked',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'contract IERC20', type: 'address' }],
    name: 'lastDistributionTimestamp',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'protocolToken',
    outputs: [{ name: '', internalType: 'contract PuppetToken', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: '_feeToken', internalType: 'contract IERC20', type: 'address' },
      { name: '_amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'setAskPrice',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'data', internalType: 'bytes', type: 'bytes' }],
    name: 'setConfig',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'functionSig', internalType: 'bytes4', type: 'bytes4' },
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'isEnabled', internalType: 'bool', type: 'bool' }
    ],
    name: 'setPermission',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'store',
    outputs: [
      {
        name: '',
        internalType: 'contract FeeMarketplaceStore',
        type: 'address'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'tokenRouter',
    outputs: [{ name: '', internalType: 'contract TokenRouter', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'error',
    inputs: [{ name: 'accruedReward', internalType: 'uint256', type: 'uint256' }],
    name: 'FeeMarketplace__InsufficientUnlockedBalance'
  },
  { type: 'error', inputs: [], name: 'FeeMarketplace__NotAuctionableToken' },
  { type: 'error', inputs: [], name: 'FeeMarketplace__ZeroDeposit' },
  { type: 'error', inputs: [], name: 'Permission__CallerNotAuthority' },
  { type: 'error', inputs: [], name: 'Permission__Unauthorized' }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// FeeMarketplaceStore
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const feeMarketplaceStoreAbi = [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_authority',
        internalType: 'contract IAuthority',
        type: 'address'
      },
      {
        name: '_router',
        internalType: 'contract TokenRouter',
        type: 'address'
      },
      {
        name: '_protocolToken',
        internalType: 'contract PuppetToken',
        type: 'address'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'authority',
    outputs: [{ name: '', internalType: 'contract IAuthority', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: '_amount', internalType: 'uint256', type: 'uint256' }],
    name: 'burn',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'user', internalType: 'address', type: 'address' }],
    name: 'canCall',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: '_token', internalType: 'contract IERC20', type: 'address' }],
    name: 'getTokenBalance',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: '_token', internalType: 'contract IERC20', type: 'address' },
      { name: '_bank', internalType: 'contract BankStore', type: 'address' },
      { name: '_value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'interTransferIn',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'protocolToken',
    outputs: [{ name: '', internalType: 'contract PuppetToken', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: '_token', internalType: 'contract IERC20', type: 'address' }],
    name: 'recordTransferIn',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'isEnabled', internalType: 'bool', type: 'bool' }
    ],
    name: 'setAccess',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '_token', internalType: 'contract IERC20', type: 'address' }],
    name: 'syncTokenBalance',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'contract IERC20', type: 'address' }],
    name: 'tokenBalanceMap',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: '_token', internalType: 'contract IERC20', type: 'address' },
      { name: '_depositor', internalType: 'address', type: 'address' },
      { name: '_value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transferIn',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: '_token', internalType: 'contract IERC20', type: 'address' },
      { name: '_receiver', internalType: 'address', type: 'address' },
      { name: '_value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transferOut',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  { type: 'error', inputs: [], name: 'Access__CallerNotAuthority' },
  { type: 'error', inputs: [], name: 'Access__Unauthorized' },
  { type: 'error', inputs: [], name: 'BankStore__InsufficientBalance' }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// GmxExecutionCallback
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const gmxExecutionCallbackAbi = [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_authority',
        internalType: 'contract IAuthority',
        type: 'address'
      },
      {
        name: '_position',
        internalType: 'contract MirrorPosition',
        type: 'address'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'key', internalType: 'bytes32', type: 'bytes32' },
      {
        name: '',
        internalType: 'struct GmxPositionUtils.Props',
        type: 'tuple',
        components: [
          {
            name: 'addresses',
            internalType: 'struct GmxPositionUtils.Addresses',
            type: 'tuple',
            components: [
              { name: 'account', internalType: 'address', type: 'address' },
              { name: 'receiver', internalType: 'address', type: 'address' },
              {
                name: 'callbackContract',
                internalType: 'address',
                type: 'address'
              },
              {
                name: 'uiFeeReceiver',
                internalType: 'address',
                type: 'address'
              },
              { name: 'market', internalType: 'address', type: 'address' },
              {
                name: 'initialCollateralToken',
                internalType: 'contract IERC20',
                type: 'address'
              },
              {
                name: 'swapPath',
                internalType: 'address[]',
                type: 'address[]'
              }
            ]
          },
          {
            name: 'numbers',
            internalType: 'struct GmxPositionUtils.Numbers',
            type: 'tuple',
            components: [
              {
                name: 'orderType',
                internalType: 'enum GmxPositionUtils.OrderType',
                type: 'uint8'
              },
              {
                name: 'decreasePositionSwapType',
                internalType: 'enum GmxPositionUtils.DecreasePositionSwapType',
                type: 'uint8'
              },
              {
                name: 'initialCollateralDeltaAmount',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'sizeDeltaUsd',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'triggerPrice',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'acceptablePrice',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'executionFee',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'callbackGasLimit',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'minOutputAmount',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'updatedAtBlock',
                internalType: 'uint256',
                type: 'uint256'
              }
            ]
          },
          {
            name: 'flags',
            internalType: 'struct GmxPositionUtils.Flags',
            type: 'tuple',
            components: [
              { name: 'isLong', internalType: 'bool', type: 'bool' },
              {
                name: 'shouldUnwrapNativeToken',
                internalType: 'bool',
                type: 'bool'
              },
              { name: 'isFrozen', internalType: 'bool', type: 'bool' }
            ]
          }
        ]
      },
      { name: '', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'afterOrderCancellation',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'key', internalType: 'bytes32', type: 'bytes32' },
      {
        name: 'order',
        internalType: 'struct GmxPositionUtils.Props',
        type: 'tuple',
        components: [
          {
            name: 'addresses',
            internalType: 'struct GmxPositionUtils.Addresses',
            type: 'tuple',
            components: [
              { name: 'account', internalType: 'address', type: 'address' },
              { name: 'receiver', internalType: 'address', type: 'address' },
              {
                name: 'callbackContract',
                internalType: 'address',
                type: 'address'
              },
              {
                name: 'uiFeeReceiver',
                internalType: 'address',
                type: 'address'
              },
              { name: 'market', internalType: 'address', type: 'address' },
              {
                name: 'initialCollateralToken',
                internalType: 'contract IERC20',
                type: 'address'
              },
              {
                name: 'swapPath',
                internalType: 'address[]',
                type: 'address[]'
              }
            ]
          },
          {
            name: 'numbers',
            internalType: 'struct GmxPositionUtils.Numbers',
            type: 'tuple',
            components: [
              {
                name: 'orderType',
                internalType: 'enum GmxPositionUtils.OrderType',
                type: 'uint8'
              },
              {
                name: 'decreasePositionSwapType',
                internalType: 'enum GmxPositionUtils.DecreasePositionSwapType',
                type: 'uint8'
              },
              {
                name: 'initialCollateralDeltaAmount',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'sizeDeltaUsd',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'triggerPrice',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'acceptablePrice',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'executionFee',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'callbackGasLimit',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'minOutputAmount',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'updatedAtBlock',
                internalType: 'uint256',
                type: 'uint256'
              }
            ]
          },
          {
            name: 'flags',
            internalType: 'struct GmxPositionUtils.Flags',
            type: 'tuple',
            components: [
              { name: 'isLong', internalType: 'bool', type: 'bool' },
              {
                name: 'shouldUnwrapNativeToken',
                internalType: 'bool',
                type: 'bool'
              },
              { name: 'isFrozen', internalType: 'bool', type: 'bool' }
            ]
          }
        ]
      },
      { name: '', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'afterOrderExecution',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'key', internalType: 'bytes32', type: 'bytes32' },
      {
        name: '',
        internalType: 'struct GmxPositionUtils.Props',
        type: 'tuple',
        components: [
          {
            name: 'addresses',
            internalType: 'struct GmxPositionUtils.Addresses',
            type: 'tuple',
            components: [
              { name: 'account', internalType: 'address', type: 'address' },
              { name: 'receiver', internalType: 'address', type: 'address' },
              {
                name: 'callbackContract',
                internalType: 'address',
                type: 'address'
              },
              {
                name: 'uiFeeReceiver',
                internalType: 'address',
                type: 'address'
              },
              { name: 'market', internalType: 'address', type: 'address' },
              {
                name: 'initialCollateralToken',
                internalType: 'contract IERC20',
                type: 'address'
              },
              {
                name: 'swapPath',
                internalType: 'address[]',
                type: 'address[]'
              }
            ]
          },
          {
            name: 'numbers',
            internalType: 'struct GmxPositionUtils.Numbers',
            type: 'tuple',
            components: [
              {
                name: 'orderType',
                internalType: 'enum GmxPositionUtils.OrderType',
                type: 'uint8'
              },
              {
                name: 'decreasePositionSwapType',
                internalType: 'enum GmxPositionUtils.DecreasePositionSwapType',
                type: 'uint8'
              },
              {
                name: 'initialCollateralDeltaAmount',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'sizeDeltaUsd',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'triggerPrice',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'acceptablePrice',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'executionFee',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'callbackGasLimit',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'minOutputAmount',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'updatedAtBlock',
                internalType: 'uint256',
                type: 'uint256'
              }
            ]
          },
          {
            name: 'flags',
            internalType: 'struct GmxPositionUtils.Flags',
            type: 'tuple',
            components: [
              { name: 'isLong', internalType: 'bool', type: 'bool' },
              {
                name: 'shouldUnwrapNativeToken',
                internalType: 'bool',
                type: 'bool'
              },
              { name: 'isFrozen', internalType: 'bool', type: 'bool' }
            ]
          }
        ]
      },
      { name: '', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'afterOrderFrozen',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'authority',
    outputs: [{ name: '', internalType: 'contract IAuthority', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'signatureHash', internalType: 'bytes4', type: 'bytes4' },
      { name: 'user', internalType: 'address', type: 'address' }
    ],
    name: 'canCall',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'data', internalType: 'bytes', type: 'bytes' }],
    name: 'setConfig',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'functionSig', internalType: 'bytes4', type: 'bytes4' },
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'isEnabled', internalType: 'bool', type: 'bool' }
    ],
    name: 'setPermission',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'unhandledCallbackListId',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'unhandledCallbackListSequenceId',
        internalType: 'uint256',
        type: 'uint256'
      }
    ],
    name: 'unhandledCallbackMap',
    outputs: [
      { name: 'operator', internalType: 'address', type: 'address' },
      { name: 'key', internalType: 'bytes32', type: 'bytes32' },
      { name: 'error', internalType: 'bytes', type: 'bytes' }
    ],
    stateMutability: 'view'
  },
  { type: 'error', inputs: [], name: 'Permission__CallerNotAuthority' },
  { type: 'error', inputs: [], name: 'Permission__Unauthorized' }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IAuthentication
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iAuthenticationAbi = [
  {
    type: 'function',
    inputs: [{ name: 'selector', internalType: 'bytes4', type: 'bytes4' }],
    name: 'getActionId',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IAuthority
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iAuthorityAbi = [
  {
    type: 'function',
    inputs: [
      { name: 'method', internalType: 'string', type: 'string' },
      { name: 'data', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'logEvent',
    outputs: [],
    stateMutability: 'nonpayable'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IAuthorizer
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iAuthorizerAbi = [
  {
    type: 'function',
    inputs: [
      { name: 'actionId', internalType: 'bytes32', type: 'bytes32' },
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'where', internalType: 'address', type: 'address' }
    ],
    name: 'canPerform',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IBasePool
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iBasePoolAbi = [
  {
    type: 'function',
    inputs: [],
    name: 'getPoolId',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'getScalingFactors',
    outputs: [{ name: '', internalType: 'uint256[]', type: 'uint256[]' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'getSwapFeePercentage',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'poolId', internalType: 'bytes32', type: 'bytes32' },
      { name: 'sender', internalType: 'address', type: 'address' },
      { name: 'recipient', internalType: 'address', type: 'address' },
      { name: 'balances', internalType: 'uint256[]', type: 'uint256[]' },
      { name: 'lastChangeBlock', internalType: 'uint256', type: 'uint256' },
      {
        name: 'protocolSwapFeePercentage',
        internalType: 'uint256',
        type: 'uint256'
      },
      { name: 'userData', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'onExitPool',
    outputs: [
      { name: 'amountsOut', internalType: 'uint256[]', type: 'uint256[]' },
      {
        name: 'dueProtocolFeeAmounts',
        internalType: 'uint256[]',
        type: 'uint256[]'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'poolId', internalType: 'bytes32', type: 'bytes32' },
      { name: 'sender', internalType: 'address', type: 'address' },
      { name: 'recipient', internalType: 'address', type: 'address' },
      { name: 'balances', internalType: 'uint256[]', type: 'uint256[]' },
      { name: 'lastChangeBlock', internalType: 'uint256', type: 'uint256' },
      {
        name: 'protocolSwapFeePercentage',
        internalType: 'uint256',
        type: 'uint256'
      },
      { name: 'userData', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'onJoinPool',
    outputs: [
      { name: 'amountsIn', internalType: 'uint256[]', type: 'uint256[]' },
      {
        name: 'dueProtocolFeeAmounts',
        internalType: 'uint256[]',
        type: 'uint256[]'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'poolId', internalType: 'bytes32', type: 'bytes32' },
      { name: 'sender', internalType: 'address', type: 'address' },
      { name: 'recipient', internalType: 'address', type: 'address' },
      { name: 'balances', internalType: 'uint256[]', type: 'uint256[]' },
      { name: 'lastChangeBlock', internalType: 'uint256', type: 'uint256' },
      {
        name: 'protocolSwapFeePercentage',
        internalType: 'uint256',
        type: 'uint256'
      },
      { name: 'userData', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'queryExit',
    outputs: [
      { name: 'bptIn', internalType: 'uint256', type: 'uint256' },
      { name: 'amountsOut', internalType: 'uint256[]', type: 'uint256[]' }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'poolId', internalType: 'bytes32', type: 'bytes32' },
      { name: 'sender', internalType: 'address', type: 'address' },
      { name: 'recipient', internalType: 'address', type: 'address' },
      { name: 'balances', internalType: 'uint256[]', type: 'uint256[]' },
      { name: 'lastChangeBlock', internalType: 'uint256', type: 'uint256' },
      {
        name: 'protocolSwapFeePercentage',
        internalType: 'uint256',
        type: 'uint256'
      },
      { name: 'userData', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'queryJoin',
    outputs: [
      { name: 'bptOut', internalType: 'uint256', type: 'uint256' },
      { name: 'amountsIn', internalType: 'uint256[]', type: 'uint256[]' }
    ],
    stateMutability: 'nonpayable'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IBeacon
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iBeaconAbi = [
  {
    type: 'function',
    inputs: [],
    name: 'implementation',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IERC1155Errors
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const ierc1155ErrorsAbi = [
  {
    type: 'error',
    inputs: [
      { name: 'sender', internalType: 'address', type: 'address' },
      { name: 'balance', internalType: 'uint256', type: 'uint256' },
      { name: 'needed', internalType: 'uint256', type: 'uint256' },
      { name: 'tokenId', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'ERC1155InsufficientBalance'
  },
  {
    type: 'error',
    inputs: [{ name: 'approver', internalType: 'address', type: 'address' }],
    name: 'ERC1155InvalidApprover'
  },
  {
    type: 'error',
    inputs: [
      { name: 'idsLength', internalType: 'uint256', type: 'uint256' },
      { name: 'valuesLength', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'ERC1155InvalidArrayLength'
  },
  {
    type: 'error',
    inputs: [{ name: 'operator', internalType: 'address', type: 'address' }],
    name: 'ERC1155InvalidOperator'
  },
  {
    type: 'error',
    inputs: [{ name: 'receiver', internalType: 'address', type: 'address' }],
    name: 'ERC1155InvalidReceiver'
  },
  {
    type: 'error',
    inputs: [{ name: 'sender', internalType: 'address', type: 'address' }],
    name: 'ERC1155InvalidSender'
  },
  {
    type: 'error',
    inputs: [
      { name: 'operator', internalType: 'address', type: 'address' },
      { name: 'owner', internalType: 'address', type: 'address' }
    ],
    name: 'ERC1155MissingApprovalForAll'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IERC1363
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const ierc1363Abi = [
  {
    type: 'function',
    inputs: [
      { name: 'owner', internalType: 'address', type: 'address' },
      { name: 'spender', internalType: 'address', type: 'address' }
    ],
    name: 'allowance',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'spender', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'approve',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'spender', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'approveAndCall',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'spender', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' },
      { name: 'data', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'approveAndCall',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'interfaceId', internalType: 'bytes4', type: 'bytes4' }],
    name: 'supportsInterface',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'totalSupply',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transfer',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transferAndCall',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' },
      { name: 'data', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'transferAndCall',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'from', internalType: 'address', type: 'address' },
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transferFrom',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'from', internalType: 'address', type: 'address' },
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' },
      { name: 'data', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'transferFromAndCall',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'from', internalType: 'address', type: 'address' },
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transferFromAndCall',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'owner',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'spender',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'value',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Approval'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'from', internalType: 'address', type: 'address', indexed: true },
      { name: 'to', internalType: 'address', type: 'address', indexed: true },
      {
        name: 'value',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Transfer'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IERC1967
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const ierc1967Abi = [
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'previousAdmin',
        internalType: 'address',
        type: 'address',
        indexed: false
      },
      {
        name: 'newAdmin',
        internalType: 'address',
        type: 'address',
        indexed: false
      }
    ],
    name: 'AdminChanged'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'beacon',
        internalType: 'address',
        type: 'address',
        indexed: true
      }
    ],
    name: 'BeaconUpgraded'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'implementation',
        internalType: 'address',
        type: 'address',
        indexed: true
      }
    ],
    name: 'Upgraded'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IERC20Errors
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const ierc20ErrorsAbi = [
  {
    type: 'error',
    inputs: [
      { name: 'spender', internalType: 'address', type: 'address' },
      { name: 'allowance', internalType: 'uint256', type: 'uint256' },
      { name: 'needed', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'ERC20InsufficientAllowance'
  },
  {
    type: 'error',
    inputs: [
      { name: 'sender', internalType: 'address', type: 'address' },
      { name: 'balance', internalType: 'uint256', type: 'uint256' },
      { name: 'needed', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'ERC20InsufficientBalance'
  },
  {
    type: 'error',
    inputs: [{ name: 'approver', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidApprover'
  },
  {
    type: 'error',
    inputs: [{ name: 'receiver', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidReceiver'
  },
  {
    type: 'error',
    inputs: [{ name: 'sender', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidSender'
  },
  {
    type: 'error',
    inputs: [{ name: 'spender', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidSpender'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IERC20Metadata
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const ierc20MetadataAbi = [
  {
    type: 'function',
    inputs: [
      { name: 'owner', internalType: 'address', type: 'address' },
      { name: 'spender', internalType: 'address', type: 'address' }
    ],
    name: 'allowance',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'spender', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'approve',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'decimals',
    outputs: [{ name: '', internalType: 'uint8', type: 'uint8' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'name',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'symbol',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'totalSupply',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transfer',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'from', internalType: 'address', type: 'address' },
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transferFrom',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'owner',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'spender',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'value',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Approval'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'from', internalType: 'address', type: 'address', indexed: true },
      { name: 'to', internalType: 'address', type: 'address', indexed: true },
      {
        name: 'value',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Transfer'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IERC20Mintable
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const ierc20MintableAbi = [
  {
    type: 'function',
    inputs: [
      { name: 'owner', internalType: 'address', type: 'address' },
      { name: 'spender', internalType: 'address', type: 'address' }
    ],
    name: 'allowance',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'spender', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'approve',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: '_receiver', internalType: 'address', type: 'address' },
      { name: '_amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'mint',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'totalSupply',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transfer',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'from', internalType: 'address', type: 'address' },
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transferFrom',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'owner',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'spender',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'value',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Approval'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'from', internalType: 'address', type: 'address', indexed: true },
      { name: 'to', internalType: 'address', type: 'address', indexed: true },
      {
        name: 'value',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Transfer'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IERC5267
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const ierc5267Abi = [
  {
    type: 'function',
    inputs: [],
    name: 'eip712Domain',
    outputs: [
      { name: 'fields', internalType: 'bytes1', type: 'bytes1' },
      { name: 'name', internalType: 'string', type: 'string' },
      { name: 'version', internalType: 'string', type: 'string' },
      { name: 'chainId', internalType: 'uint256', type: 'uint256' },
      { name: 'verifyingContract', internalType: 'address', type: 'address' },
      { name: 'salt', internalType: 'bytes32', type: 'bytes32' },
      { name: 'extensions', internalType: 'uint256[]', type: 'uint256[]' }
    ],
    stateMutability: 'view'
  },
  { type: 'event', anonymous: false, inputs: [], name: 'EIP712DomainChanged' }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IERC5805
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const ierc5805Abi = [
  {
    type: 'function',
    inputs: [],
    name: 'CLOCK_MODE',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'clock',
    outputs: [{ name: '', internalType: 'uint48', type: 'uint48' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'delegatee', internalType: 'address', type: 'address' }],
    name: 'delegate',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'delegatee', internalType: 'address', type: 'address' },
      { name: 'nonce', internalType: 'uint256', type: 'uint256' },
      { name: 'expiry', internalType: 'uint256', type: 'uint256' },
      { name: 'v', internalType: 'uint8', type: 'uint8' },
      { name: 'r', internalType: 'bytes32', type: 'bytes32' },
      { name: 's', internalType: 'bytes32', type: 'bytes32' }
    ],
    name: 'delegateBySig',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'delegates',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'timepoint', internalType: 'uint256', type: 'uint256' }],
    name: 'getPastTotalSupply',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'timepoint', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'getPastVotes',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'getVotes',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'delegator',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'fromDelegate',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'toDelegate',
        internalType: 'address',
        type: 'address',
        indexed: true
      }
    ],
    name: 'DelegateChanged'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'delegate',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'previousVotes',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'newVotes',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'DelegateVotesChanged'
  },
  {
    type: 'error',
    inputs: [{ name: 'expiry', internalType: 'uint256', type: 'uint256' }],
    name: 'VotesExpiredSignature'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IERC6372
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const ierc6372Abi = [
  {
    type: 'function',
    inputs: [],
    name: 'CLOCK_MODE',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'clock',
    outputs: [{ name: '', internalType: 'uint48', type: 'uint48' }],
    stateMutability: 'view'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IERC721Errors
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const ierc721ErrorsAbi = [
  {
    type: 'error',
    inputs: [
      { name: 'sender', internalType: 'address', type: 'address' },
      { name: 'tokenId', internalType: 'uint256', type: 'uint256' },
      { name: 'owner', internalType: 'address', type: 'address' }
    ],
    name: 'ERC721IncorrectOwner'
  },
  {
    type: 'error',
    inputs: [
      { name: 'operator', internalType: 'address', type: 'address' },
      { name: 'tokenId', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'ERC721InsufficientApproval'
  },
  {
    type: 'error',
    inputs: [{ name: 'approver', internalType: 'address', type: 'address' }],
    name: 'ERC721InvalidApprover'
  },
  {
    type: 'error',
    inputs: [{ name: 'operator', internalType: 'address', type: 'address' }],
    name: 'ERC721InvalidOperator'
  },
  {
    type: 'error',
    inputs: [{ name: 'owner', internalType: 'address', type: 'address' }],
    name: 'ERC721InvalidOwner'
  },
  {
    type: 'error',
    inputs: [{ name: 'receiver', internalType: 'address', type: 'address' }],
    name: 'ERC721InvalidReceiver'
  },
  {
    type: 'error',
    inputs: [{ name: 'sender', internalType: 'address', type: 'address' }],
    name: 'ERC721InvalidSender'
  },
  {
    type: 'error',
    inputs: [{ name: 'tokenId', internalType: 'uint256', type: 'uint256' }],
    name: 'ERC721NonexistentToken'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IFlashLoanRecipient
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iFlashLoanRecipientAbi = [
  {
    type: 'function',
    inputs: [
      { name: 'tokens', internalType: 'contract IERC20[]', type: 'address[]' },
      { name: 'amounts', internalType: 'uint256[]', type: 'uint256[]' },
      { name: 'feeAmounts', internalType: 'uint256[]', type: 'uint256[]' },
      { name: 'userData', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'receiveFlashLoan',
    outputs: [],
    stateMutability: 'nonpayable'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IGmxExchangeRouter
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iGmxExchangeRouterAbi = [
  {
    type: 'function',
    inputs: [{ name: 'key', internalType: 'bytes32', type: 'bytes32' }],
    name: 'cancelOrder',
    outputs: [],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'markets', internalType: 'address[]', type: 'address[]' },
      { name: 'tokens', internalType: 'address[]', type: 'address[]' },
      { name: 'receiver', internalType: 'address', type: 'address' }
    ],
    name: 'claimAffiliateRewards',
    outputs: [{ name: '', internalType: 'uint256[]', type: 'uint256[]' }],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'markets', internalType: 'address[]', type: 'address[]' },
      { name: 'tokens', internalType: 'address[]', type: 'address[]' },
      { name: 'receiver', internalType: 'address', type: 'address' }
    ],
    name: 'claimFundingFees',
    outputs: [{ name: '', internalType: 'uint256[]', type: 'uint256[]' }],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'params',
        internalType: 'struct GmxPositionUtils.CreateOrderParams',
        type: 'tuple',
        components: [
          {
            name: 'addresses',
            internalType: 'struct GmxPositionUtils.CreateOrderParamsAddresses',
            type: 'tuple',
            components: [
              { name: 'receiver', internalType: 'address', type: 'address' },
              {
                name: 'cancellationReceiver',
                internalType: 'address',
                type: 'address'
              },
              {
                name: 'callbackContract',
                internalType: 'address',
                type: 'address'
              },
              {
                name: 'uiFeeReceiver',
                internalType: 'address',
                type: 'address'
              },
              { name: 'market', internalType: 'address', type: 'address' },
              {
                name: 'initialCollateralToken',
                internalType: 'contract IERC20',
                type: 'address'
              },
              {
                name: 'swapPath',
                internalType: 'address[]',
                type: 'address[]'
              }
            ]
          },
          {
            name: 'numbers',
            internalType: 'struct GmxPositionUtils.CreateOrderParamsNumbers',
            type: 'tuple',
            components: [
              {
                name: 'sizeDeltaUsd',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'initialCollateralDeltaAmount',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'triggerPrice',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'acceptablePrice',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'executionFee',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'callbackGasLimit',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'minOutputAmount',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'validFromTime',
                internalType: 'uint256',
                type: 'uint256'
              }
            ]
          },
          {
            name: 'orderType',
            internalType: 'enum GmxPositionUtils.OrderType',
            type: 'uint8'
          },
          {
            name: 'decreasePositionSwapType',
            internalType: 'enum GmxPositionUtils.DecreasePositionSwapType',
            type: 'uint8'
          },
          { name: 'isLong', internalType: 'bool', type: 'bool' },
          {
            name: 'shouldUnwrapNativeToken',
            internalType: 'bool',
            type: 'bool'
          },
          { name: 'autoCancel', internalType: 'bool', type: 'bool' },
          { name: 'referralCode', internalType: 'bytes32', type: 'bytes32' }
        ]
      }
    ],
    name: 'createOrder',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [{ name: 'data', internalType: 'bytes[]', type: 'bytes[]' }],
    name: 'multicall',
    outputs: [{ name: 'results', internalType: 'bytes[]', type: 'bytes[]' }],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'receiver', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'sendNativeToken',
    outputs: [],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'token', internalType: 'address', type: 'address' },
      { name: 'receiver', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'sendTokens',
    outputs: [],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'receiver', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'sendWnt',
    outputs: [],
    stateMutability: 'payable'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IGmxOracle
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iGmxOracleAbi = [
  {
    type: 'function',
    inputs: [
      { name: 'dataStore', internalType: 'address', type: 'address' },
      { name: 'token', internalType: 'address', type: 'address' }
    ],
    name: 'getStablePrice',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IGmxOrderCallbackReceiver
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iGmxOrderCallbackReceiverAbi = [
  {
    type: 'function',
    inputs: [
      { name: 'key', internalType: 'bytes32', type: 'bytes32' },
      {
        name: 'order',
        internalType: 'struct GmxPositionUtils.Props',
        type: 'tuple',
        components: [
          {
            name: 'addresses',
            internalType: 'struct GmxPositionUtils.Addresses',
            type: 'tuple',
            components: [
              { name: 'account', internalType: 'address', type: 'address' },
              { name: 'receiver', internalType: 'address', type: 'address' },
              {
                name: 'callbackContract',
                internalType: 'address',
                type: 'address'
              },
              {
                name: 'uiFeeReceiver',
                internalType: 'address',
                type: 'address'
              },
              { name: 'market', internalType: 'address', type: 'address' },
              {
                name: 'initialCollateralToken',
                internalType: 'contract IERC20',
                type: 'address'
              },
              {
                name: 'swapPath',
                internalType: 'address[]',
                type: 'address[]'
              }
            ]
          },
          {
            name: 'numbers',
            internalType: 'struct GmxPositionUtils.Numbers',
            type: 'tuple',
            components: [
              {
                name: 'orderType',
                internalType: 'enum GmxPositionUtils.OrderType',
                type: 'uint8'
              },
              {
                name: 'decreasePositionSwapType',
                internalType: 'enum GmxPositionUtils.DecreasePositionSwapType',
                type: 'uint8'
              },
              {
                name: 'initialCollateralDeltaAmount',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'sizeDeltaUsd',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'triggerPrice',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'acceptablePrice',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'executionFee',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'callbackGasLimit',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'minOutputAmount',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'updatedAtBlock',
                internalType: 'uint256',
                type: 'uint256'
              }
            ]
          },
          {
            name: 'flags',
            internalType: 'struct GmxPositionUtils.Flags',
            type: 'tuple',
            components: [
              { name: 'isLong', internalType: 'bool', type: 'bool' },
              {
                name: 'shouldUnwrapNativeToken',
                internalType: 'bool',
                type: 'bool'
              },
              { name: 'isFrozen', internalType: 'bool', type: 'bool' }
            ]
          }
        ]
      },
      { name: 'eventData', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'afterOrderCancellation',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'key', internalType: 'bytes32', type: 'bytes32' },
      {
        name: 'order',
        internalType: 'struct GmxPositionUtils.Props',
        type: 'tuple',
        components: [
          {
            name: 'addresses',
            internalType: 'struct GmxPositionUtils.Addresses',
            type: 'tuple',
            components: [
              { name: 'account', internalType: 'address', type: 'address' },
              { name: 'receiver', internalType: 'address', type: 'address' },
              {
                name: 'callbackContract',
                internalType: 'address',
                type: 'address'
              },
              {
                name: 'uiFeeReceiver',
                internalType: 'address',
                type: 'address'
              },
              { name: 'market', internalType: 'address', type: 'address' },
              {
                name: 'initialCollateralToken',
                internalType: 'contract IERC20',
                type: 'address'
              },
              {
                name: 'swapPath',
                internalType: 'address[]',
                type: 'address[]'
              }
            ]
          },
          {
            name: 'numbers',
            internalType: 'struct GmxPositionUtils.Numbers',
            type: 'tuple',
            components: [
              {
                name: 'orderType',
                internalType: 'enum GmxPositionUtils.OrderType',
                type: 'uint8'
              },
              {
                name: 'decreasePositionSwapType',
                internalType: 'enum GmxPositionUtils.DecreasePositionSwapType',
                type: 'uint8'
              },
              {
                name: 'initialCollateralDeltaAmount',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'sizeDeltaUsd',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'triggerPrice',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'acceptablePrice',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'executionFee',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'callbackGasLimit',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'minOutputAmount',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'updatedAtBlock',
                internalType: 'uint256',
                type: 'uint256'
              }
            ]
          },
          {
            name: 'flags',
            internalType: 'struct GmxPositionUtils.Flags',
            type: 'tuple',
            components: [
              { name: 'isLong', internalType: 'bool', type: 'bool' },
              {
                name: 'shouldUnwrapNativeToken',
                internalType: 'bool',
                type: 'bool'
              },
              { name: 'isFrozen', internalType: 'bool', type: 'bool' }
            ]
          }
        ]
      },
      { name: 'eventData', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'afterOrderExecution',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'key', internalType: 'bytes32', type: 'bytes32' },
      {
        name: 'order',
        internalType: 'struct GmxPositionUtils.Props',
        type: 'tuple',
        components: [
          {
            name: 'addresses',
            internalType: 'struct GmxPositionUtils.Addresses',
            type: 'tuple',
            components: [
              { name: 'account', internalType: 'address', type: 'address' },
              { name: 'receiver', internalType: 'address', type: 'address' },
              {
                name: 'callbackContract',
                internalType: 'address',
                type: 'address'
              },
              {
                name: 'uiFeeReceiver',
                internalType: 'address',
                type: 'address'
              },
              { name: 'market', internalType: 'address', type: 'address' },
              {
                name: 'initialCollateralToken',
                internalType: 'contract IERC20',
                type: 'address'
              },
              {
                name: 'swapPath',
                internalType: 'address[]',
                type: 'address[]'
              }
            ]
          },
          {
            name: 'numbers',
            internalType: 'struct GmxPositionUtils.Numbers',
            type: 'tuple',
            components: [
              {
                name: 'orderType',
                internalType: 'enum GmxPositionUtils.OrderType',
                type: 'uint8'
              },
              {
                name: 'decreasePositionSwapType',
                internalType: 'enum GmxPositionUtils.DecreasePositionSwapType',
                type: 'uint8'
              },
              {
                name: 'initialCollateralDeltaAmount',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'sizeDeltaUsd',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'triggerPrice',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'acceptablePrice',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'executionFee',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'callbackGasLimit',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'minOutputAmount',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'updatedAtBlock',
                internalType: 'uint256',
                type: 'uint256'
              }
            ]
          },
          {
            name: 'flags',
            internalType: 'struct GmxPositionUtils.Flags',
            type: 'tuple',
            components: [
              { name: 'isLong', internalType: 'bool', type: 'bool' },
              {
                name: 'shouldUnwrapNativeToken',
                internalType: 'bool',
                type: 'bool'
              },
              { name: 'isFrozen', internalType: 'bool', type: 'bool' }
            ]
          }
        ]
      },
      { name: 'eventData', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'afterOrderFrozen',
    outputs: [],
    stateMutability: 'nonpayable'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IGmxReferralStorage
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iGmxReferralStorageAbi = [
  {
    type: 'function',
    inputs: [{ name: '_code', internalType: 'bytes32', type: 'bytes32' }],
    name: 'codeOwners',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: '_account', internalType: 'address', type: 'address' }],
    name: 'getTraderReferralInfo',
    outputs: [
      { name: '', internalType: 'bytes32', type: 'bytes32' },
      { name: '', internalType: 'address', type: 'address' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: '_code', internalType: 'bytes32', type: 'bytes32' },
      { name: '_newAccount', internalType: 'address', type: 'address' }
    ],
    name: 'govSetCodeOwner',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '_account', internalType: 'address', type: 'address' }],
    name: 'referrerDiscountShares',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: '_account', internalType: 'address', type: 'address' }],
    name: 'referrerTiers',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: '_codeHash', internalType: 'bytes32', type: 'bytes32' },
      { name: '_owner', internalType: 'address', type: 'address' }
    ],
    name: 'setCodeOwner',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: '_referrer', internalType: 'address', type: 'address' },
      { name: '_tierId', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'setReferrerTier',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: '_tierId', internalType: 'uint256', type: 'uint256' },
      { name: '_totalRebate', internalType: 'uint256', type: 'uint256' },
      { name: '_discountShare', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'setTier',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: '_account', internalType: 'address', type: 'address' },
      { name: '_code', internalType: 'bytes32', type: 'bytes32' }
    ],
    name: 'setTraderReferralCode',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '_tierLevel', internalType: 'uint256', type: 'uint256' }],
    name: 'tiers',
    outputs: [
      { name: '', internalType: 'uint256', type: 'uint256' },
      { name: '', internalType: 'uint256', type: 'uint256' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: '_account', internalType: 'address', type: 'address' }],
    name: 'traderReferralCodes',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IMulticall3
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iMulticall3Abi = [
  {
    type: 'function',
    inputs: [
      {
        name: 'calls',
        internalType: 'struct IMulticall3.Call[]',
        type: 'tuple[]',
        components: [
          { name: 'target', internalType: 'address', type: 'address' },
          { name: 'callData', internalType: 'bytes', type: 'bytes' }
        ]
      }
    ],
    name: 'aggregate',
    outputs: [
      { name: 'blockNumber', internalType: 'uint256', type: 'uint256' },
      { name: 'returnData', internalType: 'bytes[]', type: 'bytes[]' }
    ],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'calls',
        internalType: 'struct IMulticall3.Call3[]',
        type: 'tuple[]',
        components: [
          { name: 'target', internalType: 'address', type: 'address' },
          { name: 'allowFailure', internalType: 'bool', type: 'bool' },
          { name: 'callData', internalType: 'bytes', type: 'bytes' }
        ]
      }
    ],
    name: 'aggregate3',
    outputs: [
      {
        name: 'returnData',
        internalType: 'struct IMulticall3.Result[]',
        type: 'tuple[]',
        components: [
          { name: 'success', internalType: 'bool', type: 'bool' },
          { name: 'returnData', internalType: 'bytes', type: 'bytes' }
        ]
      }
    ],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'calls',
        internalType: 'struct IMulticall3.Call3Value[]',
        type: 'tuple[]',
        components: [
          { name: 'target', internalType: 'address', type: 'address' },
          { name: 'allowFailure', internalType: 'bool', type: 'bool' },
          { name: 'value', internalType: 'uint256', type: 'uint256' },
          { name: 'callData', internalType: 'bytes', type: 'bytes' }
        ]
      }
    ],
    name: 'aggregate3Value',
    outputs: [
      {
        name: 'returnData',
        internalType: 'struct IMulticall3.Result[]',
        type: 'tuple[]',
        components: [
          { name: 'success', internalType: 'bool', type: 'bool' },
          { name: 'returnData', internalType: 'bytes', type: 'bytes' }
        ]
      }
    ],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'calls',
        internalType: 'struct IMulticall3.Call[]',
        type: 'tuple[]',
        components: [
          { name: 'target', internalType: 'address', type: 'address' },
          { name: 'callData', internalType: 'bytes', type: 'bytes' }
        ]
      }
    ],
    name: 'blockAndAggregate',
    outputs: [
      { name: 'blockNumber', internalType: 'uint256', type: 'uint256' },
      { name: 'blockHash', internalType: 'bytes32', type: 'bytes32' },
      {
        name: 'returnData',
        internalType: 'struct IMulticall3.Result[]',
        type: 'tuple[]',
        components: [
          { name: 'success', internalType: 'bool', type: 'bool' },
          { name: 'returnData', internalType: 'bytes', type: 'bytes' }
        ]
      }
    ],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'getBasefee',
    outputs: [{ name: 'basefee', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'blockNumber', internalType: 'uint256', type: 'uint256' }],
    name: 'getBlockHash',
    outputs: [{ name: 'blockHash', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'getBlockNumber',
    outputs: [{ name: 'blockNumber', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'getChainId',
    outputs: [{ name: 'chainid', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'getCurrentBlockCoinbase',
    outputs: [{ name: 'coinbase', internalType: 'address', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'getCurrentBlockDifficulty',
    outputs: [{ name: 'difficulty', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'getCurrentBlockGasLimit',
    outputs: [{ name: 'gaslimit', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'getCurrentBlockTimestamp',
    outputs: [{ name: 'timestamp', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'addr', internalType: 'address', type: 'address' }],
    name: 'getEthBalance',
    outputs: [{ name: 'balance', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'getLastBlockHash',
    outputs: [{ name: 'blockHash', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'requireSuccess', internalType: 'bool', type: 'bool' },
      {
        name: 'calls',
        internalType: 'struct IMulticall3.Call[]',
        type: 'tuple[]',
        components: [
          { name: 'target', internalType: 'address', type: 'address' },
          { name: 'callData', internalType: 'bytes', type: 'bytes' }
        ]
      }
    ],
    name: 'tryAggregate',
    outputs: [
      {
        name: 'returnData',
        internalType: 'struct IMulticall3.Result[]',
        type: 'tuple[]',
        components: [
          { name: 'success', internalType: 'bool', type: 'bool' },
          { name: 'returnData', internalType: 'bytes', type: 'bytes' }
        ]
      }
    ],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'requireSuccess', internalType: 'bool', type: 'bool' },
      {
        name: 'calls',
        internalType: 'struct IMulticall3.Call[]',
        type: 'tuple[]',
        components: [
          { name: 'target', internalType: 'address', type: 'address' },
          { name: 'callData', internalType: 'bytes', type: 'bytes' }
        ]
      }
    ],
    name: 'tryBlockAndAggregate',
    outputs: [
      { name: 'blockNumber', internalType: 'uint256', type: 'uint256' },
      { name: 'blockHash', internalType: 'bytes32', type: 'bytes32' },
      {
        name: 'returnData',
        internalType: 'struct IMulticall3.Result[]',
        type: 'tuple[]',
        components: [
          { name: 'success', internalType: 'bool', type: 'bool' },
          { name: 'returnData', internalType: 'bytes', type: 'bytes' }
        ]
      }
    ],
    stateMutability: 'payable'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IProtocolFeesCollector
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iProtocolFeesCollectorAbi = [
  {
    type: 'function',
    inputs: [],
    name: 'getAuthorizer',
    outputs: [{ name: '', internalType: 'contract IAuthorizer', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'tokens', internalType: 'contract IERC20[]', type: 'address[]' }],
    name: 'getCollectedFeeAmounts',
    outputs: [{ name: 'feeAmounts', internalType: 'uint256[]', type: 'uint256[]' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'getFlashLoanFeePercentage',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'getSwapFeePercentage',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'newFlashLoanFeePercentage',
        internalType: 'uint256',
        type: 'uint256'
      }
    ],
    name: 'setFlashLoanFeePercentage',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'newSwapFeePercentage',
        internalType: 'uint256',
        type: 'uint256'
      }
    ],
    name: 'setSwapFeePercentage',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'vault',
    outputs: [{ name: '', internalType: 'contract IVault', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'tokens', internalType: 'contract IERC20[]', type: 'address[]' },
      { name: 'amounts', internalType: 'uint256[]', type: 'uint256[]' },
      { name: 'recipient', internalType: 'address', type: 'address' }
    ],
    name: 'withdrawCollectedFees',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'newFlashLoanFeePercentage',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'FlashLoanFeePercentageChanged'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'newSwapFeePercentage',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'SwapFeePercentageChanged'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IRateProvider
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iRateProviderAbi = [
  {
    type: 'function',
    inputs: [],
    name: 'getRate',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ISignaturesValidator
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iSignaturesValidatorAbi = [
  {
    type: 'function',
    inputs: [],
    name: 'getDomainSeparator',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'user', internalType: 'address', type: 'address' }],
    name: 'getNextNonce',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ITemporarilyPausable
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iTemporarilyPausableAbi = [
  {
    type: 'function',
    inputs: [],
    name: 'getPausedState',
    outputs: [
      { name: 'paused', internalType: 'bool', type: 'bool' },
      { name: 'pauseWindowEndTime', internalType: 'uint256', type: 'uint256' },
      { name: 'bufferPeriodEndTime', internalType: 'uint256', type: 'uint256' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [{ name: 'paused', internalType: 'bool', type: 'bool', indexed: false }],
    name: 'PausedStateChanged'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IUniswapV3Pool
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iUniswapV3PoolAbi = [
  {
    type: 'function',
    inputs: [
      { name: 'tickLower', internalType: 'int24', type: 'int24' },
      { name: 'tickUpper', internalType: 'int24', type: 'int24' },
      { name: 'amount', internalType: 'uint128', type: 'uint128' }
    ],
    name: 'burn',
    outputs: [
      { name: 'amount0', internalType: 'uint256', type: 'uint256' },
      { name: 'amount1', internalType: 'uint256', type: 'uint256' }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'recipient', internalType: 'address', type: 'address' },
      { name: 'tickLower', internalType: 'int24', type: 'int24' },
      { name: 'tickUpper', internalType: 'int24', type: 'int24' },
      { name: 'amount0Requested', internalType: 'uint128', type: 'uint128' },
      { name: 'amount1Requested', internalType: 'uint128', type: 'uint128' }
    ],
    name: 'collect',
    outputs: [
      { name: 'amount0', internalType: 'uint128', type: 'uint128' },
      { name: 'amount1', internalType: 'uint128', type: 'uint128' }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'recipient', internalType: 'address', type: 'address' },
      { name: 'amount0Requested', internalType: 'uint128', type: 'uint128' },
      { name: 'amount1Requested', internalType: 'uint128', type: 'uint128' }
    ],
    name: 'collectProtocol',
    outputs: [
      { name: 'amount0', internalType: 'uint128', type: 'uint128' },
      { name: 'amount1', internalType: 'uint128', type: 'uint128' }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'factory',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'fee',
    outputs: [{ name: '', internalType: 'uint24', type: 'uint24' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'feeGrowthGlobal0X128',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'feeGrowthGlobal1X128',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'recipient', internalType: 'address', type: 'address' },
      { name: 'amount0', internalType: 'uint256', type: 'uint256' },
      { name: 'amount1', internalType: 'uint256', type: 'uint256' },
      { name: 'data', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'flash',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'observationCardinalityNext',
        internalType: 'uint16',
        type: 'uint16'
      }
    ],
    name: 'increaseObservationCardinalityNext',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'sqrtPriceX96', internalType: 'uint160', type: 'uint160' }],
    name: 'initialize',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'liquidity',
    outputs: [{ name: '', internalType: 'uint128', type: 'uint128' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'maxLiquidityPerTick',
    outputs: [{ name: '', internalType: 'uint128', type: 'uint128' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'recipient', internalType: 'address', type: 'address' },
      { name: 'tickLower', internalType: 'int24', type: 'int24' },
      { name: 'tickUpper', internalType: 'int24', type: 'int24' },
      { name: 'amount', internalType: 'uint128', type: 'uint128' },
      { name: 'data', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'mint',
    outputs: [
      { name: 'amount0', internalType: 'uint256', type: 'uint256' },
      { name: 'amount1', internalType: 'uint256', type: 'uint256' }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'index', internalType: 'uint256', type: 'uint256' }],
    name: 'observations',
    outputs: [
      { name: 'blockTimestamp', internalType: 'uint32', type: 'uint32' },
      { name: 'tickCumulative', internalType: 'int56', type: 'int56' },
      {
        name: 'secondsPerLiquidityCumulativeX128',
        internalType: 'uint160',
        type: 'uint160'
      },
      { name: 'initialized', internalType: 'bool', type: 'bool' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'secondsAgos', internalType: 'uint32[]', type: 'uint32[]' }],
    name: 'observe',
    outputs: [
      { name: 'tickCumulatives', internalType: 'int56[]', type: 'int56[]' },
      {
        name: 'secondsPerLiquidityCumulativeX128s',
        internalType: 'uint160[]',
        type: 'uint160[]'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'key', internalType: 'bytes32', type: 'bytes32' }],
    name: 'positions',
    outputs: [
      { name: '_liquidity', internalType: 'uint128', type: 'uint128' },
      {
        name: 'feeGrowthInside0LastX128',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'feeGrowthInside1LastX128',
        internalType: 'uint256',
        type: 'uint256'
      },
      { name: 'tokensOwed0', internalType: 'uint128', type: 'uint128' },
      { name: 'tokensOwed1', internalType: 'uint128', type: 'uint128' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'protocolFees',
    outputs: [
      { name: 'token0', internalType: 'uint128', type: 'uint128' },
      { name: 'token1', internalType: 'uint128', type: 'uint128' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'feeProtocol0', internalType: 'uint8', type: 'uint8' },
      { name: 'feeProtocol1', internalType: 'uint8', type: 'uint8' }
    ],
    name: 'setFeeProtocol',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'slot0',
    outputs: [
      { name: 'sqrtPriceX96', internalType: 'uint160', type: 'uint160' },
      { name: 'tick', internalType: 'int24', type: 'int24' },
      { name: 'observationIndex', internalType: 'uint16', type: 'uint16' },
      {
        name: 'observationCardinality',
        internalType: 'uint16',
        type: 'uint16'
      },
      {
        name: 'observationCardinalityNext',
        internalType: 'uint16',
        type: 'uint16'
      },
      { name: 'feeProtocol', internalType: 'uint8', type: 'uint8' },
      { name: 'unlocked', internalType: 'bool', type: 'bool' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'tickLower', internalType: 'int24', type: 'int24' },
      { name: 'tickUpper', internalType: 'int24', type: 'int24' }
    ],
    name: 'snapshotCumulativesInside',
    outputs: [
      { name: 'tickCumulativeInside', internalType: 'int56', type: 'int56' },
      {
        name: 'secondsPerLiquidityInsideX128',
        internalType: 'uint160',
        type: 'uint160'
      },
      { name: 'secondsInside', internalType: 'uint32', type: 'uint32' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'recipient', internalType: 'address', type: 'address' },
      { name: 'zeroForOne', internalType: 'bool', type: 'bool' },
      { name: 'amountSpecified', internalType: 'int256', type: 'int256' },
      { name: 'sqrtPriceLimitX96', internalType: 'uint160', type: 'uint160' },
      { name: 'data', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'swap',
    outputs: [
      { name: 'amount0', internalType: 'int256', type: 'int256' },
      { name: 'amount1', internalType: 'int256', type: 'int256' }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'wordPosition', internalType: 'int16', type: 'int16' }],
    name: 'tickBitmap',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'tickSpacing',
    outputs: [{ name: '', internalType: 'int24', type: 'int24' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'tick', internalType: 'int24', type: 'int24' }],
    name: 'ticks',
    outputs: [
      { name: 'liquidityGross', internalType: 'uint128', type: 'uint128' },
      { name: 'liquidityNet', internalType: 'int128', type: 'int128' },
      {
        name: 'feeGrowthOutside0X128',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'feeGrowthOutside1X128',
        internalType: 'uint256',
        type: 'uint256'
      },
      { name: 'tickCumulativeOutside', internalType: 'int56', type: 'int56' },
      {
        name: 'secondsPerLiquidityOutsideX128',
        internalType: 'uint160',
        type: 'uint160'
      },
      { name: 'secondsOutside', internalType: 'uint32', type: 'uint32' },
      { name: 'initialized', internalType: 'bool', type: 'bool' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'token0',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'token1',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'owner',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'tickLower',
        internalType: 'int24',
        type: 'int24',
        indexed: true
      },
      {
        name: 'tickUpper',
        internalType: 'int24',
        type: 'int24',
        indexed: true
      },
      {
        name: 'amount',
        internalType: 'uint128',
        type: 'uint128',
        indexed: false
      },
      {
        name: 'amount0',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'amount1',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Burn'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'owner',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'recipient',
        internalType: 'address',
        type: 'address',
        indexed: false
      },
      {
        name: 'tickLower',
        internalType: 'int24',
        type: 'int24',
        indexed: true
      },
      {
        name: 'tickUpper',
        internalType: 'int24',
        type: 'int24',
        indexed: true
      },
      {
        name: 'amount0',
        internalType: 'uint128',
        type: 'uint128',
        indexed: false
      },
      {
        name: 'amount1',
        internalType: 'uint128',
        type: 'uint128',
        indexed: false
      }
    ],
    name: 'Collect'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'recipient',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'amount0',
        internalType: 'uint128',
        type: 'uint128',
        indexed: false
      },
      {
        name: 'amount1',
        internalType: 'uint128',
        type: 'uint128',
        indexed: false
      }
    ],
    name: 'CollectProtocol'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'recipient',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'amount0',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'amount1',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'paid0',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'paid1',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Flash'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'observationCardinalityNextOld',
        internalType: 'uint16',
        type: 'uint16',
        indexed: false
      },
      {
        name: 'observationCardinalityNextNew',
        internalType: 'uint16',
        type: 'uint16',
        indexed: false
      }
    ],
    name: 'IncreaseObservationCardinalityNext'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'sqrtPriceX96',
        internalType: 'uint160',
        type: 'uint160',
        indexed: false
      },
      { name: 'tick', internalType: 'int24', type: 'int24', indexed: false }
    ],
    name: 'Initialize'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: false
      },
      {
        name: 'owner',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'tickLower',
        internalType: 'int24',
        type: 'int24',
        indexed: true
      },
      {
        name: 'tickUpper',
        internalType: 'int24',
        type: 'int24',
        indexed: true
      },
      {
        name: 'amount',
        internalType: 'uint128',
        type: 'uint128',
        indexed: false
      },
      {
        name: 'amount0',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'amount1',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Mint'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'feeProtocol0Old',
        internalType: 'uint8',
        type: 'uint8',
        indexed: false
      },
      {
        name: 'feeProtocol1Old',
        internalType: 'uint8',
        type: 'uint8',
        indexed: false
      },
      {
        name: 'feeProtocol0New',
        internalType: 'uint8',
        type: 'uint8',
        indexed: false
      },
      {
        name: 'feeProtocol1New',
        internalType: 'uint8',
        type: 'uint8',
        indexed: false
      }
    ],
    name: 'SetFeeProtocol'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'recipient',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'amount0',
        internalType: 'int256',
        type: 'int256',
        indexed: false
      },
      {
        name: 'amount1',
        internalType: 'int256',
        type: 'int256',
        indexed: false
      },
      {
        name: 'sqrtPriceX96',
        internalType: 'uint160',
        type: 'uint160',
        indexed: false
      },
      {
        name: 'liquidity',
        internalType: 'uint128',
        type: 'uint128',
        indexed: false
      },
      { name: 'tick', internalType: 'int24', type: 'int24', indexed: false }
    ],
    name: 'Swap'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IUniswapV3PoolActions
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iUniswapV3PoolActionsAbi = [
  {
    type: 'function',
    inputs: [
      { name: 'tickLower', internalType: 'int24', type: 'int24' },
      { name: 'tickUpper', internalType: 'int24', type: 'int24' },
      { name: 'amount', internalType: 'uint128', type: 'uint128' }
    ],
    name: 'burn',
    outputs: [
      { name: 'amount0', internalType: 'uint256', type: 'uint256' },
      { name: 'amount1', internalType: 'uint256', type: 'uint256' }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'recipient', internalType: 'address', type: 'address' },
      { name: 'tickLower', internalType: 'int24', type: 'int24' },
      { name: 'tickUpper', internalType: 'int24', type: 'int24' },
      { name: 'amount0Requested', internalType: 'uint128', type: 'uint128' },
      { name: 'amount1Requested', internalType: 'uint128', type: 'uint128' }
    ],
    name: 'collect',
    outputs: [
      { name: 'amount0', internalType: 'uint128', type: 'uint128' },
      { name: 'amount1', internalType: 'uint128', type: 'uint128' }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'recipient', internalType: 'address', type: 'address' },
      { name: 'amount0', internalType: 'uint256', type: 'uint256' },
      { name: 'amount1', internalType: 'uint256', type: 'uint256' },
      { name: 'data', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'flash',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'observationCardinalityNext',
        internalType: 'uint16',
        type: 'uint16'
      }
    ],
    name: 'increaseObservationCardinalityNext',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'sqrtPriceX96', internalType: 'uint160', type: 'uint160' }],
    name: 'initialize',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'recipient', internalType: 'address', type: 'address' },
      { name: 'tickLower', internalType: 'int24', type: 'int24' },
      { name: 'tickUpper', internalType: 'int24', type: 'int24' },
      { name: 'amount', internalType: 'uint128', type: 'uint128' },
      { name: 'data', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'mint',
    outputs: [
      { name: 'amount0', internalType: 'uint256', type: 'uint256' },
      { name: 'amount1', internalType: 'uint256', type: 'uint256' }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'recipient', internalType: 'address', type: 'address' },
      { name: 'zeroForOne', internalType: 'bool', type: 'bool' },
      { name: 'amountSpecified', internalType: 'int256', type: 'int256' },
      { name: 'sqrtPriceLimitX96', internalType: 'uint160', type: 'uint160' },
      { name: 'data', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'swap',
    outputs: [
      { name: 'amount0', internalType: 'int256', type: 'int256' },
      { name: 'amount1', internalType: 'int256', type: 'int256' }
    ],
    stateMutability: 'nonpayable'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IUniswapV3PoolDerivedState
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iUniswapV3PoolDerivedStateAbi = [
  {
    type: 'function',
    inputs: [{ name: 'secondsAgos', internalType: 'uint32[]', type: 'uint32[]' }],
    name: 'observe',
    outputs: [
      { name: 'tickCumulatives', internalType: 'int56[]', type: 'int56[]' },
      {
        name: 'secondsPerLiquidityCumulativeX128s',
        internalType: 'uint160[]',
        type: 'uint160[]'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'tickLower', internalType: 'int24', type: 'int24' },
      { name: 'tickUpper', internalType: 'int24', type: 'int24' }
    ],
    name: 'snapshotCumulativesInside',
    outputs: [
      { name: 'tickCumulativeInside', internalType: 'int56', type: 'int56' },
      {
        name: 'secondsPerLiquidityInsideX128',
        internalType: 'uint160',
        type: 'uint160'
      },
      { name: 'secondsInside', internalType: 'uint32', type: 'uint32' }
    ],
    stateMutability: 'view'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IUniswapV3PoolEvents
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iUniswapV3PoolEventsAbi = [
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'owner',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'tickLower',
        internalType: 'int24',
        type: 'int24',
        indexed: true
      },
      {
        name: 'tickUpper',
        internalType: 'int24',
        type: 'int24',
        indexed: true
      },
      {
        name: 'amount',
        internalType: 'uint128',
        type: 'uint128',
        indexed: false
      },
      {
        name: 'amount0',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'amount1',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Burn'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'owner',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'recipient',
        internalType: 'address',
        type: 'address',
        indexed: false
      },
      {
        name: 'tickLower',
        internalType: 'int24',
        type: 'int24',
        indexed: true
      },
      {
        name: 'tickUpper',
        internalType: 'int24',
        type: 'int24',
        indexed: true
      },
      {
        name: 'amount0',
        internalType: 'uint128',
        type: 'uint128',
        indexed: false
      },
      {
        name: 'amount1',
        internalType: 'uint128',
        type: 'uint128',
        indexed: false
      }
    ],
    name: 'Collect'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'recipient',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'amount0',
        internalType: 'uint128',
        type: 'uint128',
        indexed: false
      },
      {
        name: 'amount1',
        internalType: 'uint128',
        type: 'uint128',
        indexed: false
      }
    ],
    name: 'CollectProtocol'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'recipient',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'amount0',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'amount1',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'paid0',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'paid1',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Flash'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'observationCardinalityNextOld',
        internalType: 'uint16',
        type: 'uint16',
        indexed: false
      },
      {
        name: 'observationCardinalityNextNew',
        internalType: 'uint16',
        type: 'uint16',
        indexed: false
      }
    ],
    name: 'IncreaseObservationCardinalityNext'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'sqrtPriceX96',
        internalType: 'uint160',
        type: 'uint160',
        indexed: false
      },
      { name: 'tick', internalType: 'int24', type: 'int24', indexed: false }
    ],
    name: 'Initialize'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: false
      },
      {
        name: 'owner',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'tickLower',
        internalType: 'int24',
        type: 'int24',
        indexed: true
      },
      {
        name: 'tickUpper',
        internalType: 'int24',
        type: 'int24',
        indexed: true
      },
      {
        name: 'amount',
        internalType: 'uint128',
        type: 'uint128',
        indexed: false
      },
      {
        name: 'amount0',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'amount1',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Mint'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'feeProtocol0Old',
        internalType: 'uint8',
        type: 'uint8',
        indexed: false
      },
      {
        name: 'feeProtocol1Old',
        internalType: 'uint8',
        type: 'uint8',
        indexed: false
      },
      {
        name: 'feeProtocol0New',
        internalType: 'uint8',
        type: 'uint8',
        indexed: false
      },
      {
        name: 'feeProtocol1New',
        internalType: 'uint8',
        type: 'uint8',
        indexed: false
      }
    ],
    name: 'SetFeeProtocol'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'recipient',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'amount0',
        internalType: 'int256',
        type: 'int256',
        indexed: false
      },
      {
        name: 'amount1',
        internalType: 'int256',
        type: 'int256',
        indexed: false
      },
      {
        name: 'sqrtPriceX96',
        internalType: 'uint160',
        type: 'uint160',
        indexed: false
      },
      {
        name: 'liquidity',
        internalType: 'uint128',
        type: 'uint128',
        indexed: false
      },
      { name: 'tick', internalType: 'int24', type: 'int24', indexed: false }
    ],
    name: 'Swap'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IUniswapV3PoolImmutables
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iUniswapV3PoolImmutablesAbi = [
  {
    type: 'function',
    inputs: [],
    name: 'factory',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'fee',
    outputs: [{ name: '', internalType: 'uint24', type: 'uint24' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'maxLiquidityPerTick',
    outputs: [{ name: '', internalType: 'uint128', type: 'uint128' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'tickSpacing',
    outputs: [{ name: '', internalType: 'int24', type: 'int24' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'token0',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'token1',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IUniswapV3PoolOwnerActions
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iUniswapV3PoolOwnerActionsAbi = [
  {
    type: 'function',
    inputs: [
      { name: 'recipient', internalType: 'address', type: 'address' },
      { name: 'amount0Requested', internalType: 'uint128', type: 'uint128' },
      { name: 'amount1Requested', internalType: 'uint128', type: 'uint128' }
    ],
    name: 'collectProtocol',
    outputs: [
      { name: 'amount0', internalType: 'uint128', type: 'uint128' },
      { name: 'amount1', internalType: 'uint128', type: 'uint128' }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'feeProtocol0', internalType: 'uint8', type: 'uint8' },
      { name: 'feeProtocol1', internalType: 'uint8', type: 'uint8' }
    ],
    name: 'setFeeProtocol',
    outputs: [],
    stateMutability: 'nonpayable'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IUniswapV3PoolState
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iUniswapV3PoolStateAbi = [
  {
    type: 'function',
    inputs: [],
    name: 'feeGrowthGlobal0X128',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'feeGrowthGlobal1X128',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'liquidity',
    outputs: [{ name: '', internalType: 'uint128', type: 'uint128' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'index', internalType: 'uint256', type: 'uint256' }],
    name: 'observations',
    outputs: [
      { name: 'blockTimestamp', internalType: 'uint32', type: 'uint32' },
      { name: 'tickCumulative', internalType: 'int56', type: 'int56' },
      {
        name: 'secondsPerLiquidityCumulativeX128',
        internalType: 'uint160',
        type: 'uint160'
      },
      { name: 'initialized', internalType: 'bool', type: 'bool' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'key', internalType: 'bytes32', type: 'bytes32' }],
    name: 'positions',
    outputs: [
      { name: '_liquidity', internalType: 'uint128', type: 'uint128' },
      {
        name: 'feeGrowthInside0LastX128',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'feeGrowthInside1LastX128',
        internalType: 'uint256',
        type: 'uint256'
      },
      { name: 'tokensOwed0', internalType: 'uint128', type: 'uint128' },
      { name: 'tokensOwed1', internalType: 'uint128', type: 'uint128' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'protocolFees',
    outputs: [
      { name: 'token0', internalType: 'uint128', type: 'uint128' },
      { name: 'token1', internalType: 'uint128', type: 'uint128' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'slot0',
    outputs: [
      { name: 'sqrtPriceX96', internalType: 'uint160', type: 'uint160' },
      { name: 'tick', internalType: 'int24', type: 'int24' },
      { name: 'observationIndex', internalType: 'uint16', type: 'uint16' },
      {
        name: 'observationCardinality',
        internalType: 'uint16',
        type: 'uint16'
      },
      {
        name: 'observationCardinalityNext',
        internalType: 'uint16',
        type: 'uint16'
      },
      { name: 'feeProtocol', internalType: 'uint8', type: 'uint8' },
      { name: 'unlocked', internalType: 'bool', type: 'bool' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'wordPosition', internalType: 'int16', type: 'int16' }],
    name: 'tickBitmap',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'tick', internalType: 'int24', type: 'int24' }],
    name: 'ticks',
    outputs: [
      { name: 'liquidityGross', internalType: 'uint128', type: 'uint128' },
      { name: 'liquidityNet', internalType: 'int128', type: 'int128' },
      {
        name: 'feeGrowthOutside0X128',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'feeGrowthOutside1X128',
        internalType: 'uint256',
        type: 'uint256'
      },
      { name: 'tickCumulativeOutside', internalType: 'int56', type: 'int56' },
      {
        name: 'secondsPerLiquidityOutsideX128',
        internalType: 'uint160',
        type: 'uint160'
      },
      { name: 'secondsOutside', internalType: 'uint32', type: 'uint32' },
      { name: 'initialized', internalType: 'bool', type: 'bool' }
    ],
    stateMutability: 'view'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IVault
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iVaultAbi = [
  {
    type: 'function',
    inputs: [],
    name: 'WETH',
    outputs: [{ name: '', internalType: 'contract IWETH', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'kind', internalType: 'enum IVault.SwapKind', type: 'uint8' },
      {
        name: 'swaps',
        internalType: 'struct IVault.BatchSwapStep[]',
        type: 'tuple[]',
        components: [
          { name: 'poolId', internalType: 'bytes32', type: 'bytes32' },
          { name: 'assetInIndex', internalType: 'uint256', type: 'uint256' },
          { name: 'assetOutIndex', internalType: 'uint256', type: 'uint256' },
          { name: 'amount', internalType: 'uint256', type: 'uint256' },
          { name: 'userData', internalType: 'bytes', type: 'bytes' }
        ]
      },
      { name: 'assets', internalType: 'contract IAsset[]', type: 'address[]' },
      {
        name: 'funds',
        internalType: 'struct IVault.FundManagement',
        type: 'tuple',
        components: [
          { name: 'sender', internalType: 'address', type: 'address' },
          { name: 'fromInternalBalance', internalType: 'bool', type: 'bool' },
          {
            name: 'recipient',
            internalType: 'address payable',
            type: 'address'
          },
          { name: 'toInternalBalance', internalType: 'bool', type: 'bool' }
        ]
      },
      { name: 'limits', internalType: 'int256[]', type: 'int256[]' },
      { name: 'deadline', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'batchSwap',
    outputs: [{ name: '', internalType: 'int256[]', type: 'int256[]' }],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'poolId', internalType: 'bytes32', type: 'bytes32' },
      { name: 'tokens', internalType: 'contract IERC20[]', type: 'address[]' }
    ],
    name: 'deregisterTokens',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'poolId', internalType: 'bytes32', type: 'bytes32' },
      { name: 'sender', internalType: 'address', type: 'address' },
      { name: 'recipient', internalType: 'address payable', type: 'address' },
      {
        name: 'request',
        internalType: 'struct IVault.ExitPoolRequest',
        type: 'tuple',
        components: [
          {
            name: 'assets',
            internalType: 'contract IAsset[]',
            type: 'address[]'
          },
          {
            name: 'minAmountsOut',
            internalType: 'uint256[]',
            type: 'uint256[]'
          },
          { name: 'userData', internalType: 'bytes', type: 'bytes' },
          { name: 'toInternalBalance', internalType: 'bool', type: 'bool' }
        ]
      }
    ],
    name: 'exitPool',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'recipient',
        internalType: 'contract IFlashLoanRecipient',
        type: 'address'
      },
      { name: 'tokens', internalType: 'contract IERC20[]', type: 'address[]' },
      { name: 'amounts', internalType: 'uint256[]', type: 'uint256[]' },
      { name: 'userData', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'flashLoan',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'selector', internalType: 'bytes4', type: 'bytes4' }],
    name: 'getActionId',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'getAuthorizer',
    outputs: [{ name: '', internalType: 'contract IAuthorizer', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'getDomainSeparator',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'tokens', internalType: 'contract IERC20[]', type: 'address[]' }
    ],
    name: 'getInternalBalance',
    outputs: [{ name: '', internalType: 'uint256[]', type: 'uint256[]' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'user', internalType: 'address', type: 'address' }],
    name: 'getNextNonce',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'getPausedState',
    outputs: [
      { name: 'paused', internalType: 'bool', type: 'bool' },
      { name: 'pauseWindowEndTime', internalType: 'uint256', type: 'uint256' },
      { name: 'bufferPeriodEndTime', internalType: 'uint256', type: 'uint256' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'poolId', internalType: 'bytes32', type: 'bytes32' }],
    name: 'getPool',
    outputs: [
      { name: '', internalType: 'address', type: 'address' },
      {
        name: '',
        internalType: 'enum IVault.PoolSpecialization',
        type: 'uint8'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'poolId', internalType: 'bytes32', type: 'bytes32' },
      { name: 'token', internalType: 'contract IERC20', type: 'address' }
    ],
    name: 'getPoolTokenInfo',
    outputs: [
      { name: 'cash', internalType: 'uint256', type: 'uint256' },
      { name: 'managed', internalType: 'uint256', type: 'uint256' },
      { name: 'lastChangeBlock', internalType: 'uint256', type: 'uint256' },
      { name: 'assetManager', internalType: 'address', type: 'address' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'poolId', internalType: 'bytes32', type: 'bytes32' }],
    name: 'getPoolTokens',
    outputs: [
      { name: 'tokens', internalType: 'contract IERC20[]', type: 'address[]' },
      { name: 'balances', internalType: 'uint256[]', type: 'uint256[]' },
      { name: 'lastChangeBlock', internalType: 'uint256', type: 'uint256' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'getProtocolFeesCollector',
    outputs: [
      {
        name: '',
        internalType: 'contract IProtocolFeesCollector',
        type: 'address'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'relayer', internalType: 'address', type: 'address' }
    ],
    name: 'hasApprovedRelayer',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'poolId', internalType: 'bytes32', type: 'bytes32' },
      { name: 'sender', internalType: 'address', type: 'address' },
      { name: 'recipient', internalType: 'address', type: 'address' },
      {
        name: 'request',
        internalType: 'struct IVault.JoinPoolRequest',
        type: 'tuple',
        components: [
          {
            name: 'assets',
            internalType: 'contract IAsset[]',
            type: 'address[]'
          },
          {
            name: 'maxAmountsIn',
            internalType: 'uint256[]',
            type: 'uint256[]'
          },
          { name: 'userData', internalType: 'bytes', type: 'bytes' },
          { name: 'fromInternalBalance', internalType: 'bool', type: 'bool' }
        ]
      }
    ],
    name: 'joinPool',
    outputs: [],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'ops',
        internalType: 'struct IVault.PoolBalanceOp[]',
        type: 'tuple[]',
        components: [
          {
            name: 'kind',
            internalType: 'enum IVault.PoolBalanceOpKind',
            type: 'uint8'
          },
          { name: 'poolId', internalType: 'bytes32', type: 'bytes32' },
          { name: 'token', internalType: 'contract IERC20', type: 'address' },
          { name: 'amount', internalType: 'uint256', type: 'uint256' }
        ]
      }
    ],
    name: 'managePoolBalance',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'ops',
        internalType: 'struct IVault.UserBalanceOp[]',
        type: 'tuple[]',
        components: [
          {
            name: 'kind',
            internalType: 'enum IVault.UserBalanceOpKind',
            type: 'uint8'
          },
          { name: 'asset', internalType: 'contract IAsset', type: 'address' },
          { name: 'amount', internalType: 'uint256', type: 'uint256' },
          { name: 'sender', internalType: 'address', type: 'address' },
          {
            name: 'recipient',
            internalType: 'address payable',
            type: 'address'
          }
        ]
      }
    ],
    name: 'manageUserBalance',
    outputs: [],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'kind', internalType: 'enum IVault.SwapKind', type: 'uint8' },
      {
        name: 'swaps',
        internalType: 'struct IVault.BatchSwapStep[]',
        type: 'tuple[]',
        components: [
          { name: 'poolId', internalType: 'bytes32', type: 'bytes32' },
          { name: 'assetInIndex', internalType: 'uint256', type: 'uint256' },
          { name: 'assetOutIndex', internalType: 'uint256', type: 'uint256' },
          { name: 'amount', internalType: 'uint256', type: 'uint256' },
          { name: 'userData', internalType: 'bytes', type: 'bytes' }
        ]
      },
      { name: 'assets', internalType: 'contract IAsset[]', type: 'address[]' },
      {
        name: 'funds',
        internalType: 'struct IVault.FundManagement',
        type: 'tuple',
        components: [
          { name: 'sender', internalType: 'address', type: 'address' },
          { name: 'fromInternalBalance', internalType: 'bool', type: 'bool' },
          {
            name: 'recipient',
            internalType: 'address payable',
            type: 'address'
          },
          { name: 'toInternalBalance', internalType: 'bool', type: 'bool' }
        ]
      }
    ],
    name: 'queryBatchSwap',
    outputs: [{ name: 'assetDeltas', internalType: 'int256[]', type: 'int256[]' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'specialization',
        internalType: 'enum IVault.PoolSpecialization',
        type: 'uint8'
      }
    ],
    name: 'registerPool',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'poolId', internalType: 'bytes32', type: 'bytes32' },
      { name: 'tokens', internalType: 'contract IERC20[]', type: 'address[]' },
      { name: 'assetManagers', internalType: 'address[]', type: 'address[]' }
    ],
    name: 'registerTokens',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'newAuthorizer',
        internalType: 'contract IAuthorizer',
        type: 'address'
      }
    ],
    name: 'setAuthorizer',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'paused', internalType: 'bool', type: 'bool' }],
    name: 'setPaused',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'sender', internalType: 'address', type: 'address' },
      { name: 'relayer', internalType: 'address', type: 'address' },
      { name: 'approved', internalType: 'bool', type: 'bool' }
    ],
    name: 'setRelayerApproval',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'singleSwap',
        internalType: 'struct IVault.SingleSwap',
        type: 'tuple',
        components: [
          { name: 'poolId', internalType: 'bytes32', type: 'bytes32' },
          { name: 'kind', internalType: 'enum IVault.SwapKind', type: 'uint8' },
          { name: 'assetIn', internalType: 'contract IAsset', type: 'address' },
          {
            name: 'assetOut',
            internalType: 'contract IAsset',
            type: 'address'
          },
          { name: 'amount', internalType: 'uint256', type: 'uint256' },
          { name: 'userData', internalType: 'bytes', type: 'bytes' }
        ]
      },
      {
        name: 'funds',
        internalType: 'struct IVault.FundManagement',
        type: 'tuple',
        components: [
          { name: 'sender', internalType: 'address', type: 'address' },
          { name: 'fromInternalBalance', internalType: 'bool', type: 'bool' },
          {
            name: 'recipient',
            internalType: 'address payable',
            type: 'address'
          },
          { name: 'toInternalBalance', internalType: 'bool', type: 'bool' }
        ]
      },
      { name: 'limit', internalType: 'uint256', type: 'uint256' },
      { name: 'deadline', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'swap',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'payable'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'newAuthorizer',
        internalType: 'contract IAuthorizer',
        type: 'address',
        indexed: true
      }
    ],
    name: 'AuthorizerChanged'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'token',
        internalType: 'contract IERC20',
        type: 'address',
        indexed: true
      },
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'recipient',
        internalType: 'address',
        type: 'address',
        indexed: false
      },
      {
        name: 'amount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'ExternalBalanceTransfer'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'recipient',
        internalType: 'contract IFlashLoanRecipient',
        type: 'address',
        indexed: true
      },
      {
        name: 'token',
        internalType: 'contract IERC20',
        type: 'address',
        indexed: true
      },
      {
        name: 'amount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'feeAmount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'FlashLoan'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'user', internalType: 'address', type: 'address', indexed: true },
      {
        name: 'token',
        internalType: 'contract IERC20',
        type: 'address',
        indexed: true
      },
      { name: 'delta', internalType: 'int256', type: 'int256', indexed: false }
    ],
    name: 'InternalBalanceChanged'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [{ name: 'paused', internalType: 'bool', type: 'bool', indexed: false }],
    name: 'PausedStateChanged'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'poolId',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true
      },
      {
        name: 'liquidityProvider',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'tokens',
        internalType: 'contract IERC20[]',
        type: 'address[]',
        indexed: false
      },
      {
        name: 'deltas',
        internalType: 'int256[]',
        type: 'int256[]',
        indexed: false
      },
      {
        name: 'protocolFeeAmounts',
        internalType: 'uint256[]',
        type: 'uint256[]',
        indexed: false
      }
    ],
    name: 'PoolBalanceChanged'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'poolId',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true
      },
      {
        name: 'assetManager',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'token',
        internalType: 'contract IERC20',
        type: 'address',
        indexed: true
      },
      {
        name: 'cashDelta',
        internalType: 'int256',
        type: 'int256',
        indexed: false
      },
      {
        name: 'managedDelta',
        internalType: 'int256',
        type: 'int256',
        indexed: false
      }
    ],
    name: 'PoolBalanceManaged'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'poolId',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true
      },
      {
        name: 'poolAddress',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'specialization',
        internalType: 'enum IVault.PoolSpecialization',
        type: 'uint8',
        indexed: false
      }
    ],
    name: 'PoolRegistered'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'relayer',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      { name: 'approved', internalType: 'bool', type: 'bool', indexed: false }
    ],
    name: 'RelayerApprovalChanged'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'poolId',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true
      },
      {
        name: 'tokenIn',
        internalType: 'contract IERC20',
        type: 'address',
        indexed: true
      },
      {
        name: 'tokenOut',
        internalType: 'contract IERC20',
        type: 'address',
        indexed: true
      },
      {
        name: 'amountIn',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'amountOut',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Swap'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'poolId',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true
      },
      {
        name: 'tokens',
        internalType: 'contract IERC20[]',
        type: 'address[]',
        indexed: false
      }
    ],
    name: 'TokensDeregistered'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'poolId',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true
      },
      {
        name: 'tokens',
        internalType: 'contract IERC20[]',
        type: 'address[]',
        indexed: false
      },
      {
        name: 'assetManagers',
        internalType: 'address[]',
        type: 'address[]',
        indexed: false
      }
    ],
    name: 'TokensRegistered'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IVotes
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iVotesAbi = [
  {
    type: 'function',
    inputs: [{ name: 'delegatee', internalType: 'address', type: 'address' }],
    name: 'delegate',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'delegatee', internalType: 'address', type: 'address' },
      { name: 'nonce', internalType: 'uint256', type: 'uint256' },
      { name: 'expiry', internalType: 'uint256', type: 'uint256' },
      { name: 'v', internalType: 'uint8', type: 'uint8' },
      { name: 'r', internalType: 'bytes32', type: 'bytes32' },
      { name: 's', internalType: 'bytes32', type: 'bytes32' }
    ],
    name: 'delegateBySig',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'delegates',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'timepoint', internalType: 'uint256', type: 'uint256' }],
    name: 'getPastTotalSupply',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'timepoint', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'getPastVotes',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'getVotes',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'delegator',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'fromDelegate',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'toDelegate',
        internalType: 'address',
        type: 'address',
        indexed: true
      }
    ],
    name: 'DelegateChanged'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'delegate',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'previousVotes',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'newVotes',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'DelegateVotesChanged'
  },
  {
    type: 'error',
    inputs: [{ name: 'expiry', internalType: 'uint256', type: 'uint256' }],
    name: 'VotesExpiredSignature'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IWETH
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iwethAbi = [
  {
    type: 'function',
    inputs: [
      { name: 'owner', internalType: 'address', type: 'address' },
      { name: 'spender', internalType: 'address', type: 'address' }
    ],
    name: 'allowance',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'spender', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'approve',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'deposit',
    outputs: [],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'totalSupply',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'recipient', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transfer',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'sender', internalType: 'address', type: 'address' },
      { name: 'recipient', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transferFrom',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'amount', internalType: 'uint256', type: 'uint256' }],
    name: 'withdraw',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'owner',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'spender',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'value',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Approval'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'from', internalType: 'address', type: 'address', indexed: true },
      { name: 'to', internalType: 'address', type: 'address', indexed: true },
      {
        name: 'value',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Transfer'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IWNT
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iwntAbi = [
  {
    type: 'function',
    inputs: [
      { name: 'owner', internalType: 'address', type: 'address' },
      { name: 'spender', internalType: 'address', type: 'address' }
    ],
    name: 'allowance',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'spender', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'approve',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'burn',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'deposit',
    outputs: [],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'mint',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'totalSupply',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transfer',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'from', internalType: 'address', type: 'address' },
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transferFrom',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'amount', internalType: 'uint256', type: 'uint256' }],
    name: 'withdraw',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'owner',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'spender',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'value',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Approval'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'from', internalType: 'address', type: 'address', indexed: true },
      { name: 'to', internalType: 'address', type: 'address', indexed: true },
      {
        name: 'value',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Transfer'
  },
  {
    type: 'error',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'TransferFailed'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IWeightedPoolFactory
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const iWeightedPoolFactoryAbi = [
  {
    type: 'function',
    inputs: [
      { name: 'name', internalType: 'string', type: 'string' },
      { name: 'symbol', internalType: 'string', type: 'string' },
      { name: 'tokens', internalType: 'contract IERC20[]', type: 'address[]' },
      {
        name: 'normalizedWeights',
        internalType: 'uint256[]',
        type: 'uint256[]'
      },
      {
        name: 'rateProviders',
        internalType: 'contract IRateProvider[]',
        type: 'address[]'
      },
      { name: 'swapFeePercentage', internalType: 'uint256', type: 'uint256' },
      { name: 'owner', internalType: 'address', type: 'address' },
      { name: 'salt', internalType: 'bytes32', type: 'bytes32' }
    ],
    name: 'create',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'nonpayable'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// MatchingRule
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const matchingRuleAbi = [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_authority',
        internalType: 'contract IAuthority',
        type: 'address'
      },
      {
        name: '_store',
        internalType: 'contract AllocationStore',
        type: 'address'
      },
      {
        name: '_mirrorPosition',
        internalType: 'contract MirrorPosition',
        type: 'address'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'allocationStore',
    outputs: [{ name: '', internalType: 'contract AllocationStore', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'authority',
    outputs: [{ name: '', internalType: 'contract IAuthority', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'signatureHash', internalType: 'bytes4', type: 'bytes4' },
      { name: 'user', internalType: 'address', type: 'address' }
    ],
    name: 'canCall',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'config',
    outputs: [
      { name: 'minExpiryDuration', internalType: 'uint256', type: 'uint256' },
      { name: 'minAllowanceRate', internalType: 'uint256', type: 'uint256' },
      { name: 'maxAllowanceRate', internalType: 'uint256', type: 'uint256' },
      { name: 'minActivityThrottle', internalType: 'uint256', type: 'uint256' },
      { name: 'maxActivityThrottle', internalType: 'uint256', type: 'uint256' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      {
        name: '_collateralToken',
        internalType: 'contract IERC20',
        type: 'address'
      },
      { name: '_user', internalType: 'address', type: 'address' },
      { name: '_amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'deposit',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: '_matchingKey', internalType: 'bytes32', type: 'bytes32' },
      { name: '_puppetList', internalType: 'address[]', type: 'address[]' }
    ],
    name: 'getRuleList',
    outputs: [
      {
        name: '_ruleList',
        internalType: 'struct MatchingRule.Rule[]',
        type: 'tuple[]',
        components: [
          { name: 'allowanceRate', internalType: 'uint256', type: 'uint256' },
          {
            name: 'throttleActivity',
            internalType: 'uint256',
            type: 'uint256'
          },
          { name: 'expiry', internalType: 'uint256', type: 'uint256' }
        ]
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'matchingKey', internalType: 'bytes32', type: 'bytes32' },
      { name: 'puppet', internalType: 'address', type: 'address' }
    ],
    name: 'matchingRuleMap',
    outputs: [
      { name: 'allowanceRate', internalType: 'uint256', type: 'uint256' },
      { name: 'throttleActivity', internalType: 'uint256', type: 'uint256' },
      { name: 'expiry', internalType: 'uint256', type: 'uint256' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'mirrorPosition',
    outputs: [{ name: '', internalType: 'contract MirrorPosition', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'data', internalType: 'bytes', type: 'bytes' }],
    name: 'setConfig',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'functionSig', internalType: 'bytes4', type: 'bytes4' },
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'isEnabled', internalType: 'bool', type: 'bool' }
    ],
    name: 'setPermission',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: '_collateralToken',
        internalType: 'contract IERC20',
        type: 'address'
      },
      { name: '_user', internalType: 'address', type: 'address' },
      { name: '_trader', internalType: 'address', type: 'address' },
      {
        name: '_ruleParams',
        internalType: 'struct MatchingRule.Rule',
        type: 'tuple',
        components: [
          { name: 'allowanceRate', internalType: 'uint256', type: 'uint256' },
          {
            name: 'throttleActivity',
            internalType: 'uint256',
            type: 'uint256'
          },
          { name: 'expiry', internalType: 'uint256', type: 'uint256' }
        ]
      }
    ],
    name: 'setRule',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: '_collateralToken',
        internalType: 'contract IERC20',
        type: 'address'
      },
      { name: '_user', internalType: 'address', type: 'address' },
      { name: '_receiver', internalType: 'address', type: 'address' },
      { name: '_amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'withdraw',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'error',
    inputs: [{ name: 'allowanceCap', internalType: 'uint256', type: 'uint256' }],
    name: 'MatchingRule__AllowanceAboveLimit'
  },
  { type: 'error', inputs: [], name: 'MatchingRule__InsufficientBalance' },
  {
    type: 'error',
    inputs: [
      {
        name: 'minAllocationActivity',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'maxAllocationActivity',
        internalType: 'uint256',
        type: 'uint256'
      }
    ],
    name: 'MatchingRule__InvalidActivityThrottle'
  },
  {
    type: 'error',
    inputs: [
      { name: 'min', internalType: 'uint256', type: 'uint256' },
      { name: 'max', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'MatchingRule__InvalidAllowanceRate'
  },
  { type: 'error', inputs: [], name: 'MatchingRule__InvalidAmount' },
  {
    type: 'error',
    inputs: [{ name: 'minExpiryDuration', internalType: 'uint256', type: 'uint256' }],
    name: 'MatchingRule__InvalidExpiryDuration'
  },
  { type: 'error', inputs: [], name: 'MatchingRule__TokenNotAllowed' },
  { type: 'error', inputs: [], name: 'Permission__CallerNotAuthority' },
  { type: 'error', inputs: [], name: 'Permission__Unauthorized' }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// MirrorPosition
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const mirrorPositionAbi = [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_authority',
        internalType: 'contract IAuthority',
        type: 'address'
      },
      {
        name: '_puppetStore',
        internalType: 'contract AllocationStore',
        type: 'address'
      },
      {
        name: '_matchingRule',
        internalType: 'contract MatchingRule',
        type: 'address'
      },
      {
        name: '_feeMarket',
        internalType: 'contract FeeMarketplace',
        type: 'address'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: '_callParams',
        internalType: 'struct MirrorPosition.CallPosition',
        type: 'tuple',
        components: [
          {
            name: 'collateralToken',
            internalType: 'contract IERC20',
            type: 'address'
          },
          { name: 'trader', internalType: 'address', type: 'address' },
          { name: 'market', internalType: 'address', type: 'address' },
          {
            name: 'keeperExecutionFeeReceiver',
            internalType: 'address',
            type: 'address'
          },
          { name: 'isIncrease', internalType: 'bool', type: 'bool' },
          { name: 'isLong', internalType: 'bool', type: 'bool' },
          { name: 'executionFee', internalType: 'uint256', type: 'uint256' },
          { name: 'collateralDelta', internalType: 'uint256', type: 'uint256' },
          { name: 'sizeDeltaInUsd', internalType: 'uint256', type: 'uint256' },
          { name: 'acceptablePrice', internalType: 'uint256', type: 'uint256' },
          { name: 'triggerPrice', internalType: 'uint256', type: 'uint256' },
          {
            name: 'keeperExecutionFee',
            internalType: 'uint256',
            type: 'uint256'
          }
        ]
      },
      { name: '_puppetList', internalType: 'address[]', type: 'address[]' },
      { name: '_allocationId', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'adjust',
    outputs: [{ name: '_requestKey', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [{ name: 'allocationAddress', internalType: 'address', type: 'address' }],
    name: 'allocationMap',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'allocationKey', internalType: 'bytes32', type: 'bytes32' },
      { name: 'puppet', internalType: 'address', type: 'address' }
    ],
    name: 'allocationPuppetMap',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'allocationStore',
    outputs: [{ name: '', internalType: 'contract AllocationStore', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'allocationStoreImplementation',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'authority',
    outputs: [{ name: '', internalType: 'contract IAuthority', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'signatureHash', internalType: 'bytes4', type: 'bytes4' },
      { name: 'user', internalType: 'address', type: 'address' }
    ],
    name: 'canCall',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      {
        name: '_allocationAccount',
        internalType: 'contract AllocationAccount',
        type: 'address'
      },
      { name: '_dustToken', internalType: 'contract IERC20', type: 'address' },
      { name: '_receiver', internalType: 'address', type: 'address' }
    ],
    name: 'collectDust',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'config',
    outputs: [
      {
        name: 'gmxExchangeRouter',
        internalType: 'contract IGmxExchangeRouter',
        type: 'address'
      },
      { name: 'callbackHandler', internalType: 'address', type: 'address' },
      { name: 'gmxOrderVault', internalType: 'address', type: 'address' },
      { name: 'referralCode', internalType: 'bytes32', type: 'bytes32' },
      {
        name: 'increaseCallbackGasLimit',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'decreaseCallbackGasLimit',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'platformSettleFeeFactor',
        internalType: 'uint256',
        type: 'uint256'
      },
      { name: 'maxPuppetList', internalType: 'uint256', type: 'uint256' },
      {
        name: 'maxKeeperFeeToAllocationRatio',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'maxKeeperFeeToAdjustmentRatio',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'maxKeeperFeeToCollectDustRatio',
        internalType: 'uint256',
        type: 'uint256'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: '_requestKey', internalType: 'bytes32', type: 'bytes32' }],
    name: 'execute',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'feeMarket',
    outputs: [{ name: '', internalType: 'contract FeeMarketplace', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: '_allocationAddress', internalType: 'address', type: 'address' }],
    name: 'getAllocation',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: '_allocationKey', internalType: 'bytes32', type: 'bytes32' }],
    name: 'getAllocationByKey',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'getConfig',
    outputs: [
      {
        name: '',
        internalType: 'struct MirrorPosition.Config',
        type: 'tuple',
        components: [
          {
            name: 'gmxExchangeRouter',
            internalType: 'contract IGmxExchangeRouter',
            type: 'address'
          },
          { name: 'callbackHandler', internalType: 'address', type: 'address' },
          { name: 'gmxOrderVault', internalType: 'address', type: 'address' },
          { name: 'referralCode', internalType: 'bytes32', type: 'bytes32' },
          {
            name: 'increaseCallbackGasLimit',
            internalType: 'uint256',
            type: 'uint256'
          },
          {
            name: 'decreaseCallbackGasLimit',
            internalType: 'uint256',
            type: 'uint256'
          },
          {
            name: 'platformSettleFeeFactor',
            internalType: 'uint256',
            type: 'uint256'
          },
          { name: 'maxPuppetList', internalType: 'uint256', type: 'uint256' },
          {
            name: 'maxKeeperFeeToAllocationRatio',
            internalType: 'uint256',
            type: 'uint256'
          },
          {
            name: 'maxKeeperFeeToAdjustmentRatio',
            internalType: 'uint256',
            type: 'uint256'
          },
          {
            name: 'maxKeeperFeeToCollectDustRatio',
            internalType: 'uint256',
            type: 'uint256'
          }
        ]
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: '_allocationAddress', internalType: 'address', type: 'address' }],
    name: 'getPosition',
    outputs: [
      {
        name: '',
        internalType: 'struct MirrorPosition.Position',
        type: 'tuple',
        components: [
          { name: 'size', internalType: 'uint256', type: 'uint256' },
          { name: 'traderSize', internalType: 'uint256', type: 'uint256' },
          {
            name: 'traderCollateral',
            internalType: 'uint256',
            type: 'uint256'
          }
        ]
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: '_requestKey', internalType: 'bytes32', type: 'bytes32' }],
    name: 'getRequestAdjustment',
    outputs: [
      {
        name: '',
        internalType: 'struct MirrorPosition.RequestAdjustment',
        type: 'tuple',
        components: [
          {
            name: 'allocationAddress',
            internalType: 'address',
            type: 'address'
          },
          { name: 'traderIsIncrease', internalType: 'bool', type: 'bool' },
          {
            name: 'traderTargetLeverage',
            internalType: 'uint256',
            type: 'uint256'
          },
          {
            name: 'traderCollateralDelta',
            internalType: 'uint256',
            type: 'uint256'
          },
          { name: 'traderSizeDelta', internalType: 'uint256', type: 'uint256' },
          { name: 'sizeDelta', internalType: 'uint256', type: 'uint256' }
        ]
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: '_matchingKey', internalType: 'bytes32', type: 'bytes32' },
      { name: '_puppet', internalType: 'address', type: 'address' }
    ],
    name: 'initializeTraderActivityThrottle',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'matchingKey', internalType: 'bytes32', type: 'bytes32' },
      { name: 'puppet', internalType: 'address', type: 'address' }
    ],
    name: 'lastActivityThrottleMap',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: '_allocationAddress', internalType: 'address', type: 'address' }],
    name: 'liquidate',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'matchingRule',
    outputs: [{ name: '', internalType: 'contract MatchingRule', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      {
        name: '_callParams',
        internalType: 'struct MirrorPosition.CallPosition',
        type: 'tuple',
        components: [
          {
            name: 'collateralToken',
            internalType: 'contract IERC20',
            type: 'address'
          },
          { name: 'trader', internalType: 'address', type: 'address' },
          { name: 'market', internalType: 'address', type: 'address' },
          {
            name: 'keeperExecutionFeeReceiver',
            internalType: 'address',
            type: 'address'
          },
          { name: 'isIncrease', internalType: 'bool', type: 'bool' },
          { name: 'isLong', internalType: 'bool', type: 'bool' },
          { name: 'executionFee', internalType: 'uint256', type: 'uint256' },
          { name: 'collateralDelta', internalType: 'uint256', type: 'uint256' },
          { name: 'sizeDeltaInUsd', internalType: 'uint256', type: 'uint256' },
          { name: 'acceptablePrice', internalType: 'uint256', type: 'uint256' },
          { name: 'triggerPrice', internalType: 'uint256', type: 'uint256' },
          {
            name: 'keeperExecutionFee',
            internalType: 'uint256',
            type: 'uint256'
          }
        ]
      },
      { name: '_puppetList', internalType: 'address[]', type: 'address[]' }
    ],
    name: 'mirror',
    outputs: [
      { name: '_allocationAddress', internalType: 'address', type: 'address' },
      { name: '_nextAllocationId', internalType: 'uint256', type: 'uint256' },
      { name: '_requestKey', internalType: 'bytes32', type: 'bytes32' }
    ],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'nextAllocationId',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'allocationAddress', internalType: 'address', type: 'address' }],
    name: 'positionMap',
    outputs: [
      { name: 'size', internalType: 'uint256', type: 'uint256' },
      { name: 'traderSize', internalType: 'uint256', type: 'uint256' },
      { name: 'traderCollateral', internalType: 'uint256', type: 'uint256' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'requestKey', internalType: 'bytes32', type: 'bytes32' }],
    name: 'requestAdjustmentMap',
    outputs: [
      { name: 'allocationAddress', internalType: 'address', type: 'address' },
      { name: 'traderIsIncrease', internalType: 'bool', type: 'bool' },
      {
        name: 'traderTargetLeverage',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'traderCollateralDelta',
        internalType: 'uint256',
        type: 'uint256'
      },
      { name: 'traderSizeDelta', internalType: 'uint256', type: 'uint256' },
      { name: 'sizeDelta', internalType: 'uint256', type: 'uint256' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'data', internalType: 'bytes', type: 'bytes' }],
    name: 'setConfig',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'functionSig', internalType: 'bytes4', type: 'bytes4' },
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'isEnabled', internalType: 'bool', type: 'bool' }
    ],
    name: 'setPermission',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: '_tokenDustThresholdList',
        internalType: 'contract IERC20[]',
        type: 'address[]'
      },
      {
        name: '_tokenDustThresholdCapList',
        internalType: 'uint256[]',
        type: 'uint256[]'
      }
    ],
    name: 'setTokenDustThreshold',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: '_callParams',
        internalType: 'struct MirrorPosition.CallSettle',
        type: 'tuple',
        components: [
          {
            name: 'collateralToken',
            internalType: 'contract IERC20',
            type: 'address'
          },
          {
            name: 'distributionToken',
            internalType: 'contract IERC20',
            type: 'address'
          },
          {
            name: 'keeperExecutionFeeReceiver',
            internalType: 'address',
            type: 'address'
          },
          { name: 'trader', internalType: 'address', type: 'address' },
          { name: 'allocationId', internalType: 'uint256', type: 'uint256' },
          {
            name: 'keeperExecutionFee',
            internalType: 'uint256',
            type: 'uint256'
          }
        ]
      },
      { name: '_puppetList', internalType: 'address[]', type: 'address[]' }
    ],
    name: 'settle',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'token', internalType: 'contract IERC20', type: 'address' }],
    name: 'tokenDustThresholdAmountMap',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'error',
    inputs: [],
    name: 'MirrorPosition__AllocationAccountNotFound'
  },
  {
    type: 'error',
    inputs: [],
    name: 'MirrorPosition__AmountExceedsDustThreshold'
  },
  { type: 'error', inputs: [], name: 'MirrorPosition__DustThresholdNotSet' },
  { type: 'error', inputs: [], name: 'MirrorPosition__DustTransferFailed' },
  {
    type: 'error',
    inputs: [],
    name: 'MirrorPosition__ExecutionRequestMissing'
  },
  { type: 'error', inputs: [], name: 'MirrorPosition__InitialMustBeIncrease' },
  {
    type: 'error',
    inputs: [],
    name: 'MirrorPosition__InsufficientGmxExecutionFee'
  },
  { type: 'error', inputs: [], name: 'MirrorPosition__InvalidAllocation' },
  {
    type: 'error',
    inputs: [],
    name: 'MirrorPosition__InvalidAllocationOrFullyReduced'
  },
  { type: 'error', inputs: [], name: 'MirrorPosition__InvalidCollateralDelta' },
  { type: 'error', inputs: [], name: 'MirrorPosition__InvalidCurrentLeverage' },
  {
    type: 'error',
    inputs: [],
    name: 'MirrorPosition__InvalidKeeperExeuctionFeeAmount'
  },
  {
    type: 'error',
    inputs: [],
    name: 'MirrorPosition__InvalidKeeperExeuctionFeeReceiver'
  },
  { type: 'error', inputs: [], name: 'MirrorPosition__InvalidReceiver' },
  { type: 'error', inputs: [], name: 'MirrorPosition__InvalidSizeDelta' },
  {
    type: 'error',
    inputs: [],
    name: 'MirrorPosition__KeeperAdjustmentExecutionFeeExceedsAllocatedAmount'
  },
  {
    type: 'error',
    inputs: [],
    name: 'MirrorPosition__KeeperFeeExceedsCostFactor'
  },
  { type: 'error', inputs: [], name: 'MirrorPosition__MaxPuppetList' },
  { type: 'error', inputs: [], name: 'MirrorPosition__NoAdjustmentRequired' },
  { type: 'error', inputs: [], name: 'MirrorPosition__NoDustToCollect' },
  { type: 'error', inputs: [], name: 'MirrorPosition__NoNetFundsAllocated' },
  { type: 'error', inputs: [], name: 'MirrorPosition__OrderCreationFailed' },
  { type: 'error', inputs: [], name: 'MirrorPosition__PositionNotFound' },
  { type: 'error', inputs: [], name: 'MirrorPosition__PuppetListEmpty' },
  {
    type: 'error',
    inputs: [],
    name: 'MirrorPosition__SettlementTransferFailed'
  },
  { type: 'error', inputs: [], name: 'MirrorPosition__TraderCollateralZero' },
  { type: 'error', inputs: [], name: 'Permission__CallerNotAuthority' },
  { type: 'error', inputs: [], name: 'Permission__Unauthorized' }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// MockGmxExchangeRouter
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const mockGmxExchangeRouterAbi = [
  {
    type: 'function',
    inputs: [{ name: 'key', internalType: 'bytes32', type: 'bytes32' }],
    name: 'cancelOrder',
    outputs: [],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'markets', internalType: 'address[]', type: 'address[]' },
      { name: 'tokens', internalType: 'address[]', type: 'address[]' },
      { name: 'receiver', internalType: 'address', type: 'address' }
    ],
    name: 'claimAffiliateRewards',
    outputs: [{ name: '', internalType: 'uint256[]', type: 'uint256[]' }],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'markets', internalType: 'address[]', type: 'address[]' },
      { name: 'tokens', internalType: 'address[]', type: 'address[]' },
      { name: 'receiver', internalType: 'address', type: 'address' }
    ],
    name: 'claimFundingFees',
    outputs: [{ name: '', internalType: 'uint256[]', type: 'uint256[]' }],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'params',
        internalType: 'struct GmxPositionUtils.CreateOrderParams',
        type: 'tuple',
        components: [
          {
            name: 'addresses',
            internalType: 'struct GmxPositionUtils.CreateOrderParamsAddresses',
            type: 'tuple',
            components: [
              { name: 'receiver', internalType: 'address', type: 'address' },
              {
                name: 'cancellationReceiver',
                internalType: 'address',
                type: 'address'
              },
              {
                name: 'callbackContract',
                internalType: 'address',
                type: 'address'
              },
              {
                name: 'uiFeeReceiver',
                internalType: 'address',
                type: 'address'
              },
              { name: 'market', internalType: 'address', type: 'address' },
              {
                name: 'initialCollateralToken',
                internalType: 'contract IERC20',
                type: 'address'
              },
              {
                name: 'swapPath',
                internalType: 'address[]',
                type: 'address[]'
              }
            ]
          },
          {
            name: 'numbers',
            internalType: 'struct GmxPositionUtils.CreateOrderParamsNumbers',
            type: 'tuple',
            components: [
              {
                name: 'sizeDeltaUsd',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'initialCollateralDeltaAmount',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'triggerPrice',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'acceptablePrice',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'executionFee',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'callbackGasLimit',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'minOutputAmount',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'validFromTime',
                internalType: 'uint256',
                type: 'uint256'
              }
            ]
          },
          {
            name: 'orderType',
            internalType: 'enum GmxPositionUtils.OrderType',
            type: 'uint8'
          },
          {
            name: 'decreasePositionSwapType',
            internalType: 'enum GmxPositionUtils.DecreasePositionSwapType',
            type: 'uint8'
          },
          { name: 'isLong', internalType: 'bool', type: 'bool' },
          {
            name: 'shouldUnwrapNativeToken',
            internalType: 'bool',
            type: 'bool'
          },
          { name: 'autoCancel', internalType: 'bool', type: 'bool' },
          { name: 'referralCode', internalType: 'bytes32', type: 'bytes32' }
        ]
      }
    ],
    name: 'createOrder',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [{ name: 'data', internalType: 'bytes[]', type: 'bytes[]' }],
    name: 'multicall',
    outputs: [{ name: 'results', internalType: 'bytes[]', type: 'bytes[]' }],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'orderCount',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    name: 'orders',
    outputs: [
      {
        name: 'addresses',
        internalType: 'struct GmxPositionUtils.CreateOrderParamsAddresses',
        type: 'tuple',
        components: [
          { name: 'receiver', internalType: 'address', type: 'address' },
          {
            name: 'cancellationReceiver',
            internalType: 'address',
            type: 'address'
          },
          {
            name: 'callbackContract',
            internalType: 'address',
            type: 'address'
          },
          { name: 'uiFeeReceiver', internalType: 'address', type: 'address' },
          { name: 'market', internalType: 'address', type: 'address' },
          {
            name: 'initialCollateralToken',
            internalType: 'contract IERC20',
            type: 'address'
          },
          { name: 'swapPath', internalType: 'address[]', type: 'address[]' }
        ]
      },
      {
        name: 'numbers',
        internalType: 'struct GmxPositionUtils.CreateOrderParamsNumbers',
        type: 'tuple',
        components: [
          { name: 'sizeDeltaUsd', internalType: 'uint256', type: 'uint256' },
          {
            name: 'initialCollateralDeltaAmount',
            internalType: 'uint256',
            type: 'uint256'
          },
          { name: 'triggerPrice', internalType: 'uint256', type: 'uint256' },
          { name: 'acceptablePrice', internalType: 'uint256', type: 'uint256' },
          { name: 'executionFee', internalType: 'uint256', type: 'uint256' },
          {
            name: 'callbackGasLimit',
            internalType: 'uint256',
            type: 'uint256'
          },
          { name: 'minOutputAmount', internalType: 'uint256', type: 'uint256' },
          { name: 'validFromTime', internalType: 'uint256', type: 'uint256' }
        ]
      },
      {
        name: 'orderType',
        internalType: 'enum GmxPositionUtils.OrderType',
        type: 'uint8'
      },
      {
        name: 'decreasePositionSwapType',
        internalType: 'enum GmxPositionUtils.DecreasePositionSwapType',
        type: 'uint8'
      },
      { name: 'isLong', internalType: 'bool', type: 'bool' },
      { name: 'shouldUnwrapNativeToken', internalType: 'bool', type: 'bool' },
      { name: 'autoCancel', internalType: 'bool', type: 'bool' },
      { name: 'referralCode', internalType: 'bytes32', type: 'bytes32' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'receiver', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'sendNativeToken',
    outputs: [],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'token', internalType: 'address', type: 'address' },
      { name: 'receiver', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'sendTokens',
    outputs: [],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'receiver', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'sendWnt',
    outputs: [],
    stateMutability: 'payable'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'orderId',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true
      },
      {
        name: 'params',
        internalType: 'struct GmxPositionUtils.CreateOrderParams',
        type: 'tuple',
        components: [
          {
            name: 'addresses',
            internalType: 'struct GmxPositionUtils.CreateOrderParamsAddresses',
            type: 'tuple',
            components: [
              { name: 'receiver', internalType: 'address', type: 'address' },
              {
                name: 'cancellationReceiver',
                internalType: 'address',
                type: 'address'
              },
              {
                name: 'callbackContract',
                internalType: 'address',
                type: 'address'
              },
              {
                name: 'uiFeeReceiver',
                internalType: 'address',
                type: 'address'
              },
              { name: 'market', internalType: 'address', type: 'address' },
              {
                name: 'initialCollateralToken',
                internalType: 'contract IERC20',
                type: 'address'
              },
              {
                name: 'swapPath',
                internalType: 'address[]',
                type: 'address[]'
              }
            ]
          },
          {
            name: 'numbers',
            internalType: 'struct GmxPositionUtils.CreateOrderParamsNumbers',
            type: 'tuple',
            components: [
              {
                name: 'sizeDeltaUsd',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'initialCollateralDeltaAmount',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'triggerPrice',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'acceptablePrice',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'executionFee',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'callbackGasLimit',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'minOutputAmount',
                internalType: 'uint256',
                type: 'uint256'
              },
              {
                name: 'validFromTime',
                internalType: 'uint256',
                type: 'uint256'
              }
            ]
          },
          {
            name: 'orderType',
            internalType: 'enum GmxPositionUtils.OrderType',
            type: 'uint8'
          },
          {
            name: 'decreasePositionSwapType',
            internalType: 'enum GmxPositionUtils.DecreasePositionSwapType',
            type: 'uint8'
          },
          { name: 'isLong', internalType: 'bool', type: 'bool' },
          {
            name: 'shouldUnwrapNativeToken',
            internalType: 'bool',
            type: 'bool'
          },
          { name: 'autoCancel', internalType: 'bool', type: 'bool' },
          { name: 'referralCode', internalType: 'bytes32', type: 'bytes32' }
        ],
        indexed: false
      }
    ],
    name: 'OrderCreated'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// MockUniswapV3Pool
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const mockUniswapV3PoolAbi = [
  {
    type: 'constructor',
    inputs: [
      { name: 'initialSqrtPriceX96', internalType: 'uint160', type: 'uint160' },
      { name: '_token0', internalType: 'address', type: 'address' },
      { name: '_token1', internalType: 'address', type: 'address' }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'tickLower', internalType: 'int24', type: 'int24' },
      { name: 'tickUpper', internalType: 'int24', type: 'int24' },
      { name: 'amount', internalType: 'uint128', type: 'uint128' }
    ],
    name: 'burn',
    outputs: [
      { name: 'amount0', internalType: 'uint256', type: 'uint256' },
      { name: 'amount1', internalType: 'uint256', type: 'uint256' }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'recipient', internalType: 'address', type: 'address' },
      { name: 'tickLower', internalType: 'int24', type: 'int24' },
      { name: 'tickUpper', internalType: 'int24', type: 'int24' },
      { name: 'amount0Requested', internalType: 'uint128', type: 'uint128' },
      { name: 'amount1Requested', internalType: 'uint128', type: 'uint128' }
    ],
    name: 'collect',
    outputs: [
      { name: 'amount0', internalType: 'uint128', type: 'uint128' },
      { name: 'amount1', internalType: 'uint128', type: 'uint128' }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'recipient', internalType: 'address', type: 'address' },
      { name: 'amount0Requested', internalType: 'uint128', type: 'uint128' },
      { name: 'amount1Requested', internalType: 'uint128', type: 'uint128' }
    ],
    name: 'collectProtocol',
    outputs: [
      { name: 'amount0', internalType: 'uint128', type: 'uint128' },
      { name: 'amount1', internalType: 'uint128', type: 'uint128' }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'factory',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'fee',
    outputs: [{ name: '', internalType: 'uint24', type: 'uint24' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'feeGrowthGlobal0X128',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'feeGrowthGlobal1X128',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'recipient', internalType: 'address', type: 'address' },
      { name: 'amount0', internalType: 'uint256', type: 'uint256' },
      { name: 'amount1', internalType: 'uint256', type: 'uint256' },
      { name: 'data', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'flash',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'observationCardinalityNext',
        internalType: 'uint16',
        type: 'uint16'
      }
    ],
    name: 'increaseObservationCardinalityNext',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '_sqrtPriceX96', internalType: 'uint160', type: 'uint160' }],
    name: 'initialize',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'liquidity',
    outputs: [{ name: '', internalType: 'uint128', type: 'uint128' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'maxLiquidityPerTick',
    outputs: [{ name: '', internalType: 'uint128', type: 'uint128' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'recipient', internalType: 'address', type: 'address' },
      { name: 'tickLower', internalType: 'int24', type: 'int24' },
      { name: 'tickUpper', internalType: 'int24', type: 'int24' },
      { name: 'amount', internalType: 'uint128', type: 'uint128' },
      { name: 'data', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'mint',
    outputs: [
      { name: 'amount0', internalType: 'uint256', type: 'uint256' },
      { name: 'amount1', internalType: 'uint256', type: 'uint256' }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'index', internalType: 'uint256', type: 'uint256' }],
    name: 'observations',
    outputs: [
      { name: 'blockTimestamp', internalType: 'uint32', type: 'uint32' },
      { name: 'tickCumulative', internalType: 'int56', type: 'int56' },
      {
        name: 'secondsPerLiquidityCumulativeX128',
        internalType: 'uint160',
        type: 'uint160'
      },
      { name: 'initialized', internalType: 'bool', type: 'bool' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'uint32[]', type: 'uint32[]' }],
    name: 'observe',
    outputs: [
      { name: '', internalType: 'int56[]', type: 'int56[]' },
      { name: '', internalType: 'uint160[]', type: 'uint160[]' }
    ],
    stateMutability: 'pure'
  },
  {
    type: 'function',
    inputs: [{ name: 'key', internalType: 'bytes32', type: 'bytes32' }],
    name: 'positions',
    outputs: [
      { name: '_liquidity', internalType: 'uint128', type: 'uint128' },
      {
        name: 'feeGrowthInside0LastX128',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'feeGrowthInside1LastX128',
        internalType: 'uint256',
        type: 'uint256'
      },
      { name: 'tokensOwed0', internalType: 'uint128', type: 'uint128' },
      { name: 'tokensOwed1', internalType: 'uint128', type: 'uint128' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'protocolFees',
    outputs: [
      { name: '_token0', internalType: 'uint128', type: 'uint128' },
      { name: '_token1', internalType: 'uint128', type: 'uint128' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'feeProtocol0', internalType: 'uint8', type: 'uint8' },
      { name: 'feeProtocol1', internalType: 'uint8', type: 'uint8' }
    ],
    name: 'setFeeProtocol',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '_ratio', internalType: 'uint256', type: 'uint256' }],
    name: 'setSqrtPriceX96',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'slot0',
    outputs: [
      { name: '_sqrtPriceX96', internalType: 'uint160', type: 'uint160' },
      { name: 'tick', internalType: 'int24', type: 'int24' },
      { name: 'observationIndex', internalType: 'uint16', type: 'uint16' },
      {
        name: 'observationCardinality',
        internalType: 'uint16',
        type: 'uint16'
      },
      {
        name: 'observationCardinalityNext',
        internalType: 'uint16',
        type: 'uint16'
      },
      { name: 'feeProtocol', internalType: 'uint8', type: 'uint8' },
      { name: '_unlocked', internalType: 'bool', type: 'bool' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'tickLower', internalType: 'int24', type: 'int24' },
      { name: 'tickUpper', internalType: 'int24', type: 'int24' }
    ],
    name: 'snapshotCumulativesInside',
    outputs: [
      { name: 'tickCumulativeInside', internalType: 'int56', type: 'int56' },
      {
        name: 'secondsPerLiquidityInsideX128',
        internalType: 'uint160',
        type: 'uint160'
      },
      { name: 'secondsInside', internalType: 'uint32', type: 'uint32' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'sqrtPriceX96',
    outputs: [{ name: '', internalType: 'uint160', type: 'uint160' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'recipient', internalType: 'address', type: 'address' },
      { name: 'zeroForOne', internalType: 'bool', type: 'bool' },
      { name: 'amountSpecified', internalType: 'int256', type: 'int256' },
      { name: 'sqrtPriceLimitX96', internalType: 'uint160', type: 'uint160' },
      { name: 'data', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'swap',
    outputs: [
      { name: 'amount0', internalType: 'int256', type: 'int256' },
      { name: 'amount1', internalType: 'int256', type: 'int256' }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'wordPosition', internalType: 'int16', type: 'int16' }],
    name: 'tickBitmap',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'tickSpacing',
    outputs: [{ name: '', internalType: 'int24', type: 'int24' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'tick', internalType: 'int24', type: 'int24' }],
    name: 'ticks',
    outputs: [
      { name: 'liquidityGross', internalType: 'uint128', type: 'uint128' },
      { name: 'liquidityNet', internalType: 'int128', type: 'int128' },
      {
        name: 'feeGrowthOutside0X128',
        internalType: 'uint256',
        type: 'uint256'
      },
      {
        name: 'feeGrowthOutside1X128',
        internalType: 'uint256',
        type: 'uint256'
      },
      { name: 'tickCumulativeOutside', internalType: 'int56', type: 'int56' },
      {
        name: 'secondsPerLiquidityOutsideX128',
        internalType: 'uint160',
        type: 'uint160'
      },
      { name: 'secondsOutside', internalType: 'uint32', type: 'uint32' },
      { name: 'initialized', internalType: 'bool', type: 'bool' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'token0',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'token1',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'unlocked',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'owner',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'tickLower',
        internalType: 'int24',
        type: 'int24',
        indexed: true
      },
      {
        name: 'tickUpper',
        internalType: 'int24',
        type: 'int24',
        indexed: true
      },
      {
        name: 'amount',
        internalType: 'uint128',
        type: 'uint128',
        indexed: false
      },
      {
        name: 'amount0',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'amount1',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Burn'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'owner',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'recipient',
        internalType: 'address',
        type: 'address',
        indexed: false
      },
      {
        name: 'tickLower',
        internalType: 'int24',
        type: 'int24',
        indexed: true
      },
      {
        name: 'tickUpper',
        internalType: 'int24',
        type: 'int24',
        indexed: true
      },
      {
        name: 'amount0',
        internalType: 'uint128',
        type: 'uint128',
        indexed: false
      },
      {
        name: 'amount1',
        internalType: 'uint128',
        type: 'uint128',
        indexed: false
      }
    ],
    name: 'Collect'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'recipient',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'amount0',
        internalType: 'uint128',
        type: 'uint128',
        indexed: false
      },
      {
        name: 'amount1',
        internalType: 'uint128',
        type: 'uint128',
        indexed: false
      }
    ],
    name: 'CollectProtocol'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'recipient',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'amount0',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'amount1',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'paid0',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'paid1',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Flash'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'observationCardinalityNextOld',
        internalType: 'uint16',
        type: 'uint16',
        indexed: false
      },
      {
        name: 'observationCardinalityNextNew',
        internalType: 'uint16',
        type: 'uint16',
        indexed: false
      }
    ],
    name: 'IncreaseObservationCardinalityNext'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'sqrtPriceX96',
        internalType: 'uint160',
        type: 'uint160',
        indexed: false
      },
      { name: 'tick', internalType: 'int24', type: 'int24', indexed: false }
    ],
    name: 'Initialize'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: false
      },
      {
        name: 'owner',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'tickLower',
        internalType: 'int24',
        type: 'int24',
        indexed: true
      },
      {
        name: 'tickUpper',
        internalType: 'int24',
        type: 'int24',
        indexed: true
      },
      {
        name: 'amount',
        internalType: 'uint128',
        type: 'uint128',
        indexed: false
      },
      {
        name: 'amount0',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'amount1',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Mint'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'sqrtPriceX96',
        internalType: 'uint160',
        type: 'uint160',
        indexed: false
      }
    ],
    name: 'PoolInitialized'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'feeProtocol0Old',
        internalType: 'uint8',
        type: 'uint8',
        indexed: false
      },
      {
        name: 'feeProtocol1Old',
        internalType: 'uint8',
        type: 'uint8',
        indexed: false
      },
      {
        name: 'feeProtocol0New',
        internalType: 'uint8',
        type: 'uint8',
        indexed: false
      },
      {
        name: 'feeProtocol1New',
        internalType: 'uint8',
        type: 'uint8',
        indexed: false
      }
    ],
    name: 'SetFeeProtocol'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'recipient',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'amount0',
        internalType: 'int256',
        type: 'int256',
        indexed: false
      },
      {
        name: 'amount1',
        internalType: 'int256',
        type: 'int256',
        indexed: false
      },
      {
        name: 'sqrtPriceX96',
        internalType: 'uint160',
        type: 'uint160',
        indexed: false
      },
      {
        name: 'liquidity',
        internalType: 'uint128',
        type: 'uint128',
        indexed: false
      },
      { name: 'tick', internalType: 'int24', type: 'int24', indexed: false }
    ],
    name: 'Swap'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// MockWeightedPoolVault
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const mockWeightedPoolVaultAbi = [
  {
    type: 'function',
    inputs: [],
    name: 'WETH',
    outputs: [{ name: '', internalType: 'contract IWETH', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'kind', internalType: 'enum IVault.SwapKind', type: 'uint8' },
      {
        name: 'swaps',
        internalType: 'struct IVault.BatchSwapStep[]',
        type: 'tuple[]',
        components: [
          { name: 'poolId', internalType: 'bytes32', type: 'bytes32' },
          { name: 'assetInIndex', internalType: 'uint256', type: 'uint256' },
          { name: 'assetOutIndex', internalType: 'uint256', type: 'uint256' },
          { name: 'amount', internalType: 'uint256', type: 'uint256' },
          { name: 'userData', internalType: 'bytes', type: 'bytes' }
        ]
      },
      { name: 'assets', internalType: 'contract IAsset[]', type: 'address[]' },
      {
        name: 'funds',
        internalType: 'struct IVault.FundManagement',
        type: 'tuple',
        components: [
          { name: 'sender', internalType: 'address', type: 'address' },
          { name: 'fromInternalBalance', internalType: 'bool', type: 'bool' },
          {
            name: 'recipient',
            internalType: 'address payable',
            type: 'address'
          },
          { name: 'toInternalBalance', internalType: 'bool', type: 'bool' }
        ]
      },
      { name: 'limits', internalType: 'int256[]', type: 'int256[]' },
      { name: 'deadline', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'batchSwap',
    outputs: [{ name: '', internalType: 'int256[]', type: 'int256[]' }],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'poolId', internalType: 'bytes32', type: 'bytes32' },
      { name: 'tokens', internalType: 'contract IERC20[]', type: 'address[]' }
    ],
    name: 'deregisterTokens',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'poolId', internalType: 'bytes32', type: 'bytes32' },
      { name: 'sender', internalType: 'address', type: 'address' },
      { name: 'recipient', internalType: 'address payable', type: 'address' },
      {
        name: 'request',
        internalType: 'struct IVault.ExitPoolRequest',
        type: 'tuple',
        components: [
          {
            name: 'assets',
            internalType: 'contract IAsset[]',
            type: 'address[]'
          },
          {
            name: 'minAmountsOut',
            internalType: 'uint256[]',
            type: 'uint256[]'
          },
          { name: 'userData', internalType: 'bytes', type: 'bytes' },
          { name: 'toInternalBalance', internalType: 'bool', type: 'bool' }
        ]
      }
    ],
    name: 'exitPool',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'recipient',
        internalType: 'contract IFlashLoanRecipient',
        type: 'address'
      },
      { name: 'tokens', internalType: 'contract IERC20[]', type: 'address[]' },
      { name: 'amounts', internalType: 'uint256[]', type: 'uint256[]' },
      { name: 'userData', internalType: 'bytes', type: 'bytes' }
    ],
    name: 'flashLoan',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'selector', internalType: 'bytes4', type: 'bytes4' }],
    name: 'getActionId',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'getAuthorizer',
    outputs: [{ name: '', internalType: 'contract IAuthorizer', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'getDomainSeparator',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'tokens', internalType: 'contract IERC20[]', type: 'address[]' }
    ],
    name: 'getInternalBalance',
    outputs: [{ name: '', internalType: 'uint256[]', type: 'uint256[]' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'user', internalType: 'address', type: 'address' }],
    name: 'getNextNonce',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'getPausedState',
    outputs: [
      { name: 'paused', internalType: 'bool', type: 'bool' },
      { name: 'pauseWindowEndTime', internalType: 'uint256', type: 'uint256' },
      { name: 'bufferPeriodEndTime', internalType: 'uint256', type: 'uint256' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'poolId', internalType: 'bytes32', type: 'bytes32' }],
    name: 'getPool',
    outputs: [
      { name: '', internalType: 'address', type: 'address' },
      {
        name: '',
        internalType: 'enum IVault.PoolSpecialization',
        type: 'uint8'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'poolId', internalType: 'bytes32', type: 'bytes32' },
      { name: 'token', internalType: 'contract IERC20', type: 'address' }
    ],
    name: 'getPoolTokenInfo',
    outputs: [
      { name: 'cash', internalType: 'uint256', type: 'uint256' },
      { name: 'managed', internalType: 'uint256', type: 'uint256' },
      { name: 'lastChangeBlock', internalType: 'uint256', type: 'uint256' },
      { name: 'assetManager', internalType: 'address', type: 'address' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    name: 'getPoolTokens',
    outputs: [
      { name: 'tokens', internalType: 'contract IERC20[]', type: 'address[]' },
      { name: 'balances', internalType: 'uint256[]', type: 'uint256[]' },
      { name: 'lastChangeBlock', internalType: 'uint256', type: 'uint256' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'getProtocolFeesCollector',
    outputs: [
      {
        name: '',
        internalType: 'contract IProtocolFeesCollector',
        type: 'address'
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'relayer', internalType: 'address', type: 'address' }
    ],
    name: 'hasApprovedRelayer',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'token0', internalType: 'address', type: 'address' },
      { name: 'token1', internalType: 'address', type: 'address' },
      { name: 'balances0', internalType: 'uint256', type: 'uint256' },
      { name: 'balance1', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'initPool',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'poolId', internalType: 'bytes32', type: 'bytes32' },
      { name: 'sender', internalType: 'address', type: 'address' },
      { name: 'recipient', internalType: 'address', type: 'address' },
      {
        name: 'request',
        internalType: 'struct IVault.JoinPoolRequest',
        type: 'tuple',
        components: [
          {
            name: 'assets',
            internalType: 'contract IAsset[]',
            type: 'address[]'
          },
          {
            name: 'maxAmountsIn',
            internalType: 'uint256[]',
            type: 'uint256[]'
          },
          { name: 'userData', internalType: 'bytes', type: 'bytes' },
          { name: 'fromInternalBalance', internalType: 'bool', type: 'bool' }
        ]
      }
    ],
    name: 'joinPool',
    outputs: [],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'ops',
        internalType: 'struct IVault.PoolBalanceOp[]',
        type: 'tuple[]',
        components: [
          {
            name: 'kind',
            internalType: 'enum IVault.PoolBalanceOpKind',
            type: 'uint8'
          },
          { name: 'poolId', internalType: 'bytes32', type: 'bytes32' },
          { name: 'token', internalType: 'contract IERC20', type: 'address' },
          { name: 'amount', internalType: 'uint256', type: 'uint256' }
        ]
      }
    ],
    name: 'managePoolBalance',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'ops',
        internalType: 'struct IVault.UserBalanceOp[]',
        type: 'tuple[]',
        components: [
          {
            name: 'kind',
            internalType: 'enum IVault.UserBalanceOpKind',
            type: 'uint8'
          },
          { name: 'asset', internalType: 'contract IAsset', type: 'address' },
          { name: 'amount', internalType: 'uint256', type: 'uint256' },
          { name: 'sender', internalType: 'address', type: 'address' },
          {
            name: 'recipient',
            internalType: 'address payable',
            type: 'address'
          }
        ]
      }
    ],
    name: 'manageUserBalance',
    outputs: [],
    stateMutability: 'payable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'kind', internalType: 'enum IVault.SwapKind', type: 'uint8' },
      {
        name: 'swaps',
        internalType: 'struct IVault.BatchSwapStep[]',
        type: 'tuple[]',
        components: [
          { name: 'poolId', internalType: 'bytes32', type: 'bytes32' },
          { name: 'assetInIndex', internalType: 'uint256', type: 'uint256' },
          { name: 'assetOutIndex', internalType: 'uint256', type: 'uint256' },
          { name: 'amount', internalType: 'uint256', type: 'uint256' },
          { name: 'userData', internalType: 'bytes', type: 'bytes' }
        ]
      },
      { name: 'assets', internalType: 'contract IAsset[]', type: 'address[]' },
      {
        name: 'funds',
        internalType: 'struct IVault.FundManagement',
        type: 'tuple',
        components: [
          { name: 'sender', internalType: 'address', type: 'address' },
          { name: 'fromInternalBalance', internalType: 'bool', type: 'bool' },
          {
            name: 'recipient',
            internalType: 'address payable',
            type: 'address'
          },
          { name: 'toInternalBalance', internalType: 'bool', type: 'bool' }
        ]
      }
    ],
    name: 'queryBatchSwap',
    outputs: [{ name: 'assetDeltas', internalType: 'int256[]', type: 'int256[]' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'specialization',
        internalType: 'enum IVault.PoolSpecialization',
        type: 'uint8'
      }
    ],
    name: 'registerPool',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'poolId', internalType: 'bytes32', type: 'bytes32' },
      { name: 'tokens', internalType: 'contract IERC20[]', type: 'address[]' },
      { name: 'assetManagers', internalType: 'address[]', type: 'address[]' }
    ],
    name: 'registerTokens',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'newAuthorizer',
        internalType: 'contract IAuthorizer',
        type: 'address'
      }
    ],
    name: 'setAuthorizer',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'paused', internalType: 'bool', type: 'bool' }],
    name: 'setPaused',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'balances0', internalType: 'uint256', type: 'uint256' },
      { name: 'balance1', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'setPoolBalances',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'sender', internalType: 'address', type: 'address' },
      { name: 'relayer', internalType: 'address', type: 'address' },
      { name: 'approved', internalType: 'bool', type: 'bool' }
    ],
    name: 'setRelayerApproval',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'blance0', internalType: 'uint256', type: 'uint256' }],
    name: 'setToken0Balance',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'blance0', internalType: 'uint256', type: 'uint256' }],
    name: 'setToken1Balance',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'blance0', internalType: 'uint256', type: 'uint256' }],
    name: 'setToken2Balance',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'singleSwap',
        internalType: 'struct IVault.SingleSwap',
        type: 'tuple',
        components: [
          { name: 'poolId', internalType: 'bytes32', type: 'bytes32' },
          { name: 'kind', internalType: 'enum IVault.SwapKind', type: 'uint8' },
          { name: 'assetIn', internalType: 'contract IAsset', type: 'address' },
          {
            name: 'assetOut',
            internalType: 'contract IAsset',
            type: 'address'
          },
          { name: 'amount', internalType: 'uint256', type: 'uint256' },
          { name: 'userData', internalType: 'bytes', type: 'bytes' }
        ]
      },
      {
        name: 'funds',
        internalType: 'struct IVault.FundManagement',
        type: 'tuple',
        components: [
          { name: 'sender', internalType: 'address', type: 'address' },
          { name: 'fromInternalBalance', internalType: 'bool', type: 'bool' },
          {
            name: 'recipient',
            internalType: 'address payable',
            type: 'address'
          },
          { name: 'toInternalBalance', internalType: 'bool', type: 'bool' }
        ]
      },
      { name: 'limit', internalType: 'uint256', type: 'uint256' },
      { name: 'deadline', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'swap',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'payable'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'newAuthorizer',
        internalType: 'contract IAuthorizer',
        type: 'address',
        indexed: true
      }
    ],
    name: 'AuthorizerChanged'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'token',
        internalType: 'contract IERC20',
        type: 'address',
        indexed: true
      },
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'recipient',
        internalType: 'address',
        type: 'address',
        indexed: false
      },
      {
        name: 'amount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'ExternalBalanceTransfer'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'recipient',
        internalType: 'contract IFlashLoanRecipient',
        type: 'address',
        indexed: true
      },
      {
        name: 'token',
        internalType: 'contract IERC20',
        type: 'address',
        indexed: true
      },
      {
        name: 'amount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'feeAmount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'FlashLoan'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'user', internalType: 'address', type: 'address', indexed: true },
      {
        name: 'token',
        internalType: 'contract IERC20',
        type: 'address',
        indexed: true
      },
      { name: 'delta', internalType: 'int256', type: 'int256', indexed: false }
    ],
    name: 'InternalBalanceChanged'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [{ name: 'paused', internalType: 'bool', type: 'bool', indexed: false }],
    name: 'PausedStateChanged'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'poolId',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true
      },
      {
        name: 'liquidityProvider',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'tokens',
        internalType: 'contract IERC20[]',
        type: 'address[]',
        indexed: false
      },
      {
        name: 'deltas',
        internalType: 'int256[]',
        type: 'int256[]',
        indexed: false
      },
      {
        name: 'protocolFeeAmounts',
        internalType: 'uint256[]',
        type: 'uint256[]',
        indexed: false
      }
    ],
    name: 'PoolBalanceChanged'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'poolId',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true
      },
      {
        name: 'assetManager',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'token',
        internalType: 'contract IERC20',
        type: 'address',
        indexed: true
      },
      {
        name: 'cashDelta',
        internalType: 'int256',
        type: 'int256',
        indexed: false
      },
      {
        name: 'managedDelta',
        internalType: 'int256',
        type: 'int256',
        indexed: false
      }
    ],
    name: 'PoolBalanceManaged'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'poolId',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true
      },
      {
        name: 'poolAddress',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'specialization',
        internalType: 'enum IVault.PoolSpecialization',
        type: 'uint8',
        indexed: false
      }
    ],
    name: 'PoolRegistered'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'relayer',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      { name: 'approved', internalType: 'bool', type: 'bool', indexed: false }
    ],
    name: 'RelayerApprovalChanged'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'poolId',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true
      },
      {
        name: 'tokenIn',
        internalType: 'contract IERC20',
        type: 'address',
        indexed: true
      },
      {
        name: 'tokenOut',
        internalType: 'contract IERC20',
        type: 'address',
        indexed: true
      },
      {
        name: 'amountIn',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'amountOut',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Swap'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'poolId',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true
      },
      {
        name: 'tokens',
        internalType: 'contract IERC20[]',
        type: 'address[]',
        indexed: false
      }
    ],
    name: 'TokensDeregistered'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'poolId',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true
      },
      {
        name: 'tokens',
        internalType: 'contract IERC20[]',
        type: 'address[]',
        indexed: false
      },
      {
        name: 'assetManagers',
        internalType: 'address[]',
        type: 'address[]',
        indexed: false
      }
    ],
    name: 'TokensRegistered'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Multicall
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const multicallAbi = [
  {
    type: 'function',
    inputs: [{ name: 'data', internalType: 'bytes[]', type: 'bytes[]' }],
    name: 'multicall',
    outputs: [{ name: 'results', internalType: 'bytes[]', type: 'bytes[]' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'error',
    inputs: [{ name: 'target', internalType: 'address', type: 'address' }],
    name: 'AddressEmptyCode'
  },
  { type: 'error', inputs: [], name: 'FailedCall' }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Nonces
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const noncesAbi = [
  {
    type: 'function',
    inputs: [{ name: 'owner', internalType: 'address', type: 'address' }],
    name: 'nonces',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'error',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'currentNonce', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'InvalidAccountNonce'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Ownable
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const ownableAbi = [
  {
    type: 'function',
    inputs: [],
    name: 'owner',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'renounceOwnership',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'newOwner', internalType: 'address', type: 'address' }],
    name: 'transferOwnership',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'previousOwner',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'newOwner',
        internalType: 'address',
        type: 'address',
        indexed: true
      }
    ],
    name: 'OwnershipTransferred'
  },
  {
    type: 'error',
    inputs: [{ name: 'owner', internalType: 'address', type: 'address' }],
    name: 'OwnableInvalidOwner'
  },
  {
    type: 'error',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'OwnableUnauthorizedAccount'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Permission
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const permissionAbi = [
  {
    type: 'function',
    inputs: [],
    name: 'authority',
    outputs: [{ name: '', internalType: 'contract IAuthority', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'signatureHash', internalType: 'bytes4', type: 'bytes4' },
      { name: 'user', internalType: 'address', type: 'address' }
    ],
    name: 'canCall',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'functionSig', internalType: 'bytes4', type: 'bytes4' },
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'isEnabled', internalType: 'bool', type: 'bool' }
    ],
    name: 'setPermission',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  { type: 'error', inputs: [], name: 'Permission__CallerNotAuthority' }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Precision
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const precisionAbi = [
  {
    type: 'function',
    inputs: [],
    name: 'BASIS_POINT_DIVISOR',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'FLOAT_PRECISION',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Proxy
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const proxyAbi = [{ type: 'fallback', stateMutability: 'payable' }] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// PuppetToken
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const puppetTokenAbi = [
  { type: 'constructor', inputs: [], stateMutability: 'nonpayable' },
  {
    type: 'function',
    inputs: [
      { name: 'owner', internalType: 'address', type: 'address' },
      { name: 'spender', internalType: 'address', type: 'address' }
    ],
    name: 'allowance',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'spender', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'approve',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'value', internalType: 'uint256', type: 'uint256' }],
    name: 'burn',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'burnFrom',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'decimals',
    outputs: [{ name: '', internalType: 'uint8', type: 'uint8' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'name',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'symbol',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'totalSupply',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transfer',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'from', internalType: 'address', type: 'address' },
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transferFrom',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'owner',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'spender',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'value',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Approval'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'from', internalType: 'address', type: 'address', indexed: true },
      { name: 'to', internalType: 'address', type: 'address', indexed: true },
      {
        name: 'value',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Transfer'
  },
  {
    type: 'error',
    inputs: [
      { name: 'spender', internalType: 'address', type: 'address' },
      { name: 'allowance', internalType: 'uint256', type: 'uint256' },
      { name: 'needed', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'ERC20InsufficientAllowance'
  },
  {
    type: 'error',
    inputs: [
      { name: 'sender', internalType: 'address', type: 'address' },
      { name: 'balance', internalType: 'uint256', type: 'uint256' },
      { name: 'needed', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'ERC20InsufficientBalance'
  },
  {
    type: 'error',
    inputs: [{ name: 'approver', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidApprover'
  },
  {
    type: 'error',
    inputs: [{ name: 'receiver', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidReceiver'
  },
  {
    type: 'error',
    inputs: [{ name: 'sender', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidSender'
  },
  {
    type: 'error',
    inputs: [{ name: 'spender', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidSpender'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// PuppetVoteToken
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const puppetVoteTokenAbi = [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_authority',
        internalType: 'contract IAuthority',
        type: 'address'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'CLOCK_MODE',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'owner', internalType: 'address', type: 'address' },
      { name: 'spender', internalType: 'address', type: 'address' }
    ],
    name: 'allowance',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'spender', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'approve',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'authority',
    outputs: [{ name: '', internalType: 'contract IAuthority', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'burn',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'signatureHash', internalType: 'bytes4', type: 'bytes4' },
      { name: 'user', internalType: 'address', type: 'address' }
    ],
    name: 'canCall',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'pos', internalType: 'uint32', type: 'uint32' }
    ],
    name: 'checkpoints',
    outputs: [
      {
        name: '',
        internalType: 'struct Checkpoints.Checkpoint208',
        type: 'tuple',
        components: [
          { name: '_key', internalType: 'uint48', type: 'uint48' },
          { name: '_value', internalType: 'uint208', type: 'uint208' }
        ]
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'clock',
    outputs: [{ name: '', internalType: 'uint48', type: 'uint48' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'decimals',
    outputs: [{ name: '', internalType: 'uint8', type: 'uint8' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'delegatee', internalType: 'address', type: 'address' }],
    name: 'delegate',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'delegatee', internalType: 'address', type: 'address' },
      { name: 'nonce', internalType: 'uint256', type: 'uint256' },
      { name: 'expiry', internalType: 'uint256', type: 'uint256' },
      { name: 'v', internalType: 'uint8', type: 'uint8' },
      { name: 'r', internalType: 'bytes32', type: 'bytes32' },
      { name: 's', internalType: 'bytes32', type: 'bytes32' }
    ],
    name: 'delegateBySig',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'delegates',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'eip712Domain',
    outputs: [
      { name: 'fields', internalType: 'bytes1', type: 'bytes1' },
      { name: 'name', internalType: 'string', type: 'string' },
      { name: 'version', internalType: 'string', type: 'string' },
      { name: 'chainId', internalType: 'uint256', type: 'uint256' },
      { name: 'verifyingContract', internalType: 'address', type: 'address' },
      { name: 'salt', internalType: 'bytes32', type: 'bytes32' },
      { name: 'extensions', internalType: 'uint256[]', type: 'uint256[]' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'timepoint', internalType: 'uint256', type: 'uint256' }],
    name: 'getPastTotalSupply',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'timepoint', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'getPastVotes',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'getVotes',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'mint',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'name',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'owner', internalType: 'address', type: 'address' }],
    name: 'nonces',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'numCheckpoints',
    outputs: [{ name: '', internalType: 'uint32', type: 'uint32' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'functionSig', internalType: 'bytes4', type: 'bytes4' },
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'isEnabled', internalType: 'bool', type: 'bool' }
    ],
    name: 'setPermission',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'interfaceId', internalType: 'bytes4', type: 'bytes4' }],
    name: 'supportsInterface',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'symbol',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'totalSupply',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: '', internalType: 'address', type: 'address' },
      { name: '', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transfer',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'pure'
  },
  {
    type: 'function',
    inputs: [
      { name: '', internalType: 'address', type: 'address' },
      { name: '', internalType: 'address', type: 'address' },
      { name: '', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transferFrom',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'pure'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'owner',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'spender',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'value',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Approval'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'delegator',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'fromDelegate',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'toDelegate',
        internalType: 'address',
        type: 'address',
        indexed: true
      }
    ],
    name: 'DelegateChanged'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'delegate',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'previousVotes',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'newVotes',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'DelegateVotesChanged'
  },
  { type: 'event', anonymous: false, inputs: [], name: 'EIP712DomainChanged' },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'from', internalType: 'address', type: 'address', indexed: true },
      { name: 'to', internalType: 'address', type: 'address', indexed: true },
      {
        name: 'value',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'Transfer'
  },
  { type: 'error', inputs: [], name: 'CheckpointUnorderedInsertion' },
  { type: 'error', inputs: [], name: 'ECDSAInvalidSignature' },
  {
    type: 'error',
    inputs: [{ name: 'length', internalType: 'uint256', type: 'uint256' }],
    name: 'ECDSAInvalidSignatureLength'
  },
  {
    type: 'error',
    inputs: [{ name: 's', internalType: 'bytes32', type: 'bytes32' }],
    name: 'ECDSAInvalidSignatureS'
  },
  {
    type: 'error',
    inputs: [
      { name: 'increasedSupply', internalType: 'uint256', type: 'uint256' },
      { name: 'cap', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'ERC20ExceededSafeSupply'
  },
  {
    type: 'error',
    inputs: [
      { name: 'spender', internalType: 'address', type: 'address' },
      { name: 'allowance', internalType: 'uint256', type: 'uint256' },
      { name: 'needed', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'ERC20InsufficientAllowance'
  },
  {
    type: 'error',
    inputs: [
      { name: 'sender', internalType: 'address', type: 'address' },
      { name: 'balance', internalType: 'uint256', type: 'uint256' },
      { name: 'needed', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'ERC20InsufficientBalance'
  },
  {
    type: 'error',
    inputs: [{ name: 'approver', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidApprover'
  },
  {
    type: 'error',
    inputs: [{ name: 'receiver', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidReceiver'
  },
  {
    type: 'error',
    inputs: [{ name: 'sender', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidSender'
  },
  {
    type: 'error',
    inputs: [{ name: 'spender', internalType: 'address', type: 'address' }],
    name: 'ERC20InvalidSpender'
  },
  {
    type: 'error',
    inputs: [
      { name: 'timepoint', internalType: 'uint256', type: 'uint256' },
      { name: 'clock', internalType: 'uint48', type: 'uint48' }
    ],
    name: 'ERC5805FutureLookup'
  },
  { type: 'error', inputs: [], name: 'ERC6372InconsistentClock' },
  {
    type: 'error',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'currentNonce', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'InvalidAccountNonce'
  },
  { type: 'error', inputs: [], name: 'InvalidShortString' },
  { type: 'error', inputs: [], name: 'Permission__CallerNotAuthority' },
  { type: 'error', inputs: [], name: 'Permission__Unauthorized' },
  {
    type: 'error',
    inputs: [
      { name: 'bits', internalType: 'uint8', type: 'uint8' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'SafeCastOverflowedUintDowncast'
  },
  {
    type: 'error',
    inputs: [{ name: 'str', internalType: 'string', type: 'string' }],
    name: 'StringTooLong'
  },
  {
    type: 'error',
    inputs: [{ name: 'expiry', internalType: 'uint256', type: 'uint256' }],
    name: 'VotesExpiredSignature'
  },
  { type: 'error', inputs: [], name: 'VotingEscrow__Unsupported' }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ReentrancyGuardTransient
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const reentrancyGuardTransientAbi = [
  { type: 'error', inputs: [], name: 'ReentrancyGuardReentrantCall' }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RewardDistributor
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const rewardDistributorAbi = [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_authority',
        internalType: 'contract IAuthority',
        type: 'address'
      },
      {
        name: '_rewardToken',
        internalType: 'contract IERC20',
        type: 'address'
      },
      { name: '_vToken', internalType: 'contract IERC20', type: 'address' },
      { name: '_store', internalType: 'contract RewardStore', type: 'address' }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'authority',
    outputs: [{ name: '', internalType: 'contract IAuthority', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'signatureHash', internalType: 'bytes4', type: 'bytes4' },
      { name: 'user', internalType: 'address', type: 'address' }
    ],
    name: 'canCall',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: '_user', internalType: 'address', type: 'address' },
      { name: '_receiver', internalType: 'address', type: 'address' },
      { name: '_amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'claim',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '_user', internalType: 'address', type: 'address' }],
    name: 'claimable',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'config',
    outputs: [{ name: 'distributionWindow', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'cumulativeRewardPerToken',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: '_depositor', internalType: 'address', type: 'address' },
      { name: '_amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'deposit',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'lastDistributionTime',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'pendingDistribution',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'rewardToken',
    outputs: [{ name: '', internalType: 'contract IERC20', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'data', internalType: 'bytes', type: 'bytes' }],
    name: 'setConfig',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'functionSig', internalType: 'bytes4', type: 'bytes4' },
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'isEnabled', internalType: 'bool', type: 'bool' }
    ],
    name: 'setPermission',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'store',
    outputs: [{ name: '', internalType: 'contract RewardStore', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'totalUndistributed',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      {
        name: '_referralStorage',
        internalType: 'contract IGmxReferralStorage',
        type: 'address'
      },
      { name: '_code', internalType: 'bytes32', type: 'bytes32' },
      { name: '_newOwner', internalType: 'address', type: 'address' }
    ],
    name: 'transferReferralOwnership',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'address', type: 'address' }],
    name: 'userRewardMap',
    outputs: [
      {
        name: 'cumulativeRewardCheckpoint',
        internalType: 'uint256',
        type: 'uint256'
      },
      { name: 'accrued', internalType: 'uint256', type: 'uint256' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'vToken',
    outputs: [{ name: '', internalType: 'contract IERC20', type: 'address' }],
    stateMutability: 'view'
  },
  { type: 'error', inputs: [], name: 'Permission__CallerNotAuthority' },
  { type: 'error', inputs: [], name: 'Permission__Unauthorized' },
  {
    type: 'error',
    inputs: [{ name: 'accured', internalType: 'uint256', type: 'uint256' }],
    name: 'RewardDistributor__InsufficientRewards'
  },
  { type: 'error', inputs: [], name: 'RewardDistributor__InvalidAmount' }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RewardStore
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const rewardStoreAbi = [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_authority',
        internalType: 'contract IAuthority',
        type: 'address'
      },
      {
        name: '_router',
        internalType: 'contract TokenRouter',
        type: 'address'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'authority',
    outputs: [{ name: '', internalType: 'contract IAuthority', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'user', internalType: 'address', type: 'address' }],
    name: 'canCall',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: '_token', internalType: 'contract IERC20', type: 'address' }],
    name: 'getTokenBalance',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: '_token', internalType: 'contract IERC20', type: 'address' },
      { name: '_bank', internalType: 'contract BankStore', type: 'address' },
      { name: '_value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'interTransferIn',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '_token', internalType: 'contract IERC20', type: 'address' }],
    name: 'recordTransferIn',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'isEnabled', internalType: 'bool', type: 'bool' }
    ],
    name: 'setAccess',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '_token', internalType: 'contract IERC20', type: 'address' }],
    name: 'syncTokenBalance',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'contract IERC20', type: 'address' }],
    name: 'tokenBalanceMap',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: '_token', internalType: 'contract IERC20', type: 'address' },
      { name: '_depositor', internalType: 'address', type: 'address' },
      { name: '_value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transferIn',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: '_token', internalType: 'contract IERC20', type: 'address' },
      { name: '_receiver', internalType: 'address', type: 'address' },
      { name: '_value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transferOut',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  { type: 'error', inputs: [], name: 'Access__CallerNotAuthority' },
  { type: 'error', inputs: [], name: 'Access__Unauthorized' },
  { type: 'error', inputs: [], name: 'BankStore__InsufficientBalance' }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Router
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const routerAbi = [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_matchingRule',
        internalType: 'contract MatchingRule',
        type: 'address'
      },
      {
        name: '_feeMarketplace',
        internalType: 'contract FeeMarketplace',
        type: 'address'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'feeToken', internalType: 'contract IERC20', type: 'address' },
      { name: 'receiver', internalType: 'address', type: 'address' },
      { name: 'purchaseAmount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'acceptOffer',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'token', internalType: 'contract IERC20', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'deposit',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'feeMarketplace',
    outputs: [{ name: '', internalType: 'contract FeeMarketplace', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'matchingRule',
    outputs: [{ name: '', internalType: 'contract MatchingRule', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'collateralToken',
        internalType: 'contract IERC20',
        type: 'address'
      },
      { name: 'trader', internalType: 'address', type: 'address' },
      {
        name: 'ruleParams',
        internalType: 'struct MatchingRule.Rule',
        type: 'tuple',
        components: [
          { name: 'allowanceRate', internalType: 'uint256', type: 'uint256' },
          {
            name: 'throttleActivity',
            internalType: 'uint256',
            type: 'uint256'
          },
          { name: 'expiry', internalType: 'uint256', type: 'uint256' }
        ]
      }
    ],
    name: 'setMatchingRule',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'token', internalType: 'contract IERC20', type: 'address' },
      { name: 'receiver', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'withdraw',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  { type: 'error', inputs: [], name: 'ReentrancyGuardReentrantCall' }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RouterProxy
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const routerProxyAbi = [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_authority',
        internalType: 'contract IAuthority',
        type: 'address'
      }
    ],
    stateMutability: 'nonpayable'
  },
  { type: 'fallback', stateMutability: 'payable' },
  { type: 'receive', stateMutability: 'payable' },
  {
    type: 'function',
    inputs: [],
    name: 'authority',
    outputs: [{ name: '', internalType: 'contract IAuthority', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'user', internalType: 'address', type: 'address' }],
    name: 'canCall',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'data', internalType: 'bytes[]', type: 'bytes[]' }],
    name: 'multicall',
    outputs: [{ name: 'results', internalType: 'bytes[]', type: 'bytes[]' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'isEnabled', internalType: 'bool', type: 'bool' }
    ],
    name: 'setAccess',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '_impl', internalType: 'address', type: 'address' }],
    name: 'update',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'implementation',
        internalType: 'address',
        type: 'address',
        indexed: true
      }
    ],
    name: 'Upgraded'
  },
  { type: 'error', inputs: [], name: 'Access__CallerNotAuthority' },
  { type: 'error', inputs: [], name: 'Access__Unauthorized' },
  {
    type: 'error',
    inputs: [{ name: 'target', internalType: 'address', type: 'address' }],
    name: 'AddressEmptyCode'
  },
  {
    type: 'error',
    inputs: [{ name: 'implementation', internalType: 'address', type: 'address' }],
    name: 'ERC1967InvalidImplementation'
  },
  { type: 'error', inputs: [], name: 'ERC1967NonPayable' },
  { type: 'error', inputs: [], name: 'FailedCall' }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// SafeCast
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const safeCastAbi = [
  {
    type: 'error',
    inputs: [
      { name: 'bits', internalType: 'uint8', type: 'uint8' },
      { name: 'value', internalType: 'int256', type: 'int256' }
    ],
    name: 'SafeCastOverflowedIntDowncast'
  },
  {
    type: 'error',
    inputs: [{ name: 'value', internalType: 'int256', type: 'int256' }],
    name: 'SafeCastOverflowedIntToUint'
  },
  {
    type: 'error',
    inputs: [
      { name: 'bits', internalType: 'uint8', type: 'uint8' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'SafeCastOverflowedUintDowncast'
  },
  {
    type: 'error',
    inputs: [{ name: 'value', internalType: 'uint256', type: 'uint256' }],
    name: 'SafeCastOverflowedUintToInt'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// SafeERC20
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const safeErc20Abi = [
  {
    type: 'error',
    inputs: [
      { name: 'spender', internalType: 'address', type: 'address' },
      { name: 'currentAllowance', internalType: 'uint256', type: 'uint256' },
      { name: 'requestedDecrease', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'SafeERC20FailedDecreaseAllowance'
  },
  {
    type: 'error',
    inputs: [{ name: 'token', internalType: 'address', type: 'address' }],
    name: 'SafeERC20FailedOperation'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ShortStrings
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const shortStringsAbi = [
  { type: 'error', inputs: [], name: 'InvalidShortString' },
  {
    type: 'error',
    inputs: [{ name: 'str', internalType: 'string', type: 'string' }],
    name: 'StringTooLong'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Strings
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const stringsAbi = [
  {
    type: 'error',
    inputs: [
      { name: 'value', internalType: 'uint256', type: 'uint256' },
      { name: 'length', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'StringsInsufficientHexLength'
  },
  { type: 'error', inputs: [], name: 'StringsInvalidAddressFormat' },
  { type: 'error', inputs: [], name: 'StringsInvalidChar' }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// TokenRouter
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const tokenRouterAbi = [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_authority',
        internalType: 'contract IAuthority',
        type: 'address'
      },
      {
        name: '_initialTransferGasLimit',
        internalType: 'uint256',
        type: 'uint256'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'authority',
    outputs: [{ name: '', internalType: 'contract IAuthority', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'user', internalType: 'address', type: 'address' }],
    name: 'canCall',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'isEnabled', internalType: 'bool', type: 'bool' }
    ],
    name: 'setAccess',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '_trasnferGasLimit', internalType: 'uint256', type: 'uint256' }],
    name: 'setTransferGasLimit',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'token', internalType: 'contract IERC20', type: 'address' },
      { name: 'from', internalType: 'address', type: 'address' },
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transfer',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  { type: 'error', inputs: [], name: 'Access__CallerNotAuthority' },
  { type: 'error', inputs: [], name: 'Access__Unauthorized' },
  {
    type: 'error',
    inputs: [{ name: 'target', internalType: 'address', type: 'address' }],
    name: 'CallUtils__AddressEmptyCode'
  },
  { type: 'error', inputs: [], name: 'CallUtils__FailedInnerCall' },
  {
    type: 'error',
    inputs: [{ name: 'token', internalType: 'address', type: 'address' }],
    name: 'CallUtils__SafeERC20FailedOperation'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Votes
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const votesAbi = [
  {
    type: 'function',
    inputs: [],
    name: 'CLOCK_MODE',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'clock',
    outputs: [{ name: '', internalType: 'uint48', type: 'uint48' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'delegatee', internalType: 'address', type: 'address' }],
    name: 'delegate',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'delegatee', internalType: 'address', type: 'address' },
      { name: 'nonce', internalType: 'uint256', type: 'uint256' },
      { name: 'expiry', internalType: 'uint256', type: 'uint256' },
      { name: 'v', internalType: 'uint8', type: 'uint8' },
      { name: 'r', internalType: 'bytes32', type: 'bytes32' },
      { name: 's', internalType: 'bytes32', type: 'bytes32' }
    ],
    name: 'delegateBySig',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'delegates',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'eip712Domain',
    outputs: [
      { name: 'fields', internalType: 'bytes1', type: 'bytes1' },
      { name: 'name', internalType: 'string', type: 'string' },
      { name: 'version', internalType: 'string', type: 'string' },
      { name: 'chainId', internalType: 'uint256', type: 'uint256' },
      { name: 'verifyingContract', internalType: 'address', type: 'address' },
      { name: 'salt', internalType: 'bytes32', type: 'bytes32' },
      { name: 'extensions', internalType: 'uint256[]', type: 'uint256[]' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'timepoint', internalType: 'uint256', type: 'uint256' }],
    name: 'getPastTotalSupply',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'timepoint', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'getPastVotes',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'getVotes',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'owner', internalType: 'address', type: 'address' }],
    name: 'nonces',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'delegator',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'fromDelegate',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'toDelegate',
        internalType: 'address',
        type: 'address',
        indexed: true
      }
    ],
    name: 'DelegateChanged'
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'delegate',
        internalType: 'address',
        type: 'address',
        indexed: true
      },
      {
        name: 'previousVotes',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      },
      {
        name: 'newVotes',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false
      }
    ],
    name: 'DelegateVotesChanged'
  },
  { type: 'event', anonymous: false, inputs: [], name: 'EIP712DomainChanged' },
  { type: 'error', inputs: [], name: 'CheckpointUnorderedInsertion' },
  { type: 'error', inputs: [], name: 'ECDSAInvalidSignature' },
  {
    type: 'error',
    inputs: [{ name: 'length', internalType: 'uint256', type: 'uint256' }],
    name: 'ECDSAInvalidSignatureLength'
  },
  {
    type: 'error',
    inputs: [{ name: 's', internalType: 'bytes32', type: 'bytes32' }],
    name: 'ECDSAInvalidSignatureS'
  },
  {
    type: 'error',
    inputs: [
      { name: 'timepoint', internalType: 'uint256', type: 'uint256' },
      { name: 'clock', internalType: 'uint48', type: 'uint48' }
    ],
    name: 'ERC5805FutureLookup'
  },
  { type: 'error', inputs: [], name: 'ERC6372InconsistentClock' },
  {
    type: 'error',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'currentNonce', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'InvalidAccountNonce'
  },
  { type: 'error', inputs: [], name: 'InvalidShortString' },
  {
    type: 'error',
    inputs: [
      { name: 'bits', internalType: 'uint8', type: 'uint8' },
      { name: 'value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'SafeCastOverflowedUintDowncast'
  },
  {
    type: 'error',
    inputs: [{ name: 'str', internalType: 'string', type: 'string' }],
    name: 'StringTooLong'
  },
  {
    type: 'error',
    inputs: [{ name: 'expiry', internalType: 'uint256', type: 'uint256' }],
    name: 'VotesExpiredSignature'
  }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// VotingEscrow
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const votingEscrowAbi = [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_authority',
        internalType: 'contract IAuthority',
        type: 'address'
      },
      {
        name: '_store',
        internalType: 'contract VotingEscrowStore',
        type: 'address'
      },
      { name: '_token', internalType: 'contract PuppetToken', type: 'address' },
      {
        name: '_vToken',
        internalType: 'contract PuppetVoteToken',
        type: 'address'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'MAXTIME',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'authority',
    outputs: [{ name: '', internalType: 'contract IAuthority', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'duration', internalType: 'uint256', type: 'uint256' }],
    name: 'calcDurationMultiplier',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'signatureHash', internalType: 'bytes4', type: 'bytes4' },
      { name: 'user', internalType: 'address', type: 'address' }
    ],
    name: 'canCall',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'receiver', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'claim',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'config',
    outputs: [{ name: 'baseMultiplier', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'user', internalType: 'address', type: 'address' }],
    name: 'getClaimable',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'amount', internalType: 'uint256', type: 'uint256' },
      { name: 'duration', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'getVestedBonus',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'user', internalType: 'address', type: 'address' }],
    name: 'getVestingCursor',
    outputs: [
      {
        name: 'vested',
        internalType: 'struct VotingEscrow.Vested',
        type: 'tuple',
        components: [
          { name: 'amount', internalType: 'uint256', type: 'uint256' },
          {
            name: 'remainingDuration',
            internalType: 'uint256',
            type: 'uint256'
          },
          { name: 'lastAccruedTime', internalType: 'uint256', type: 'uint256' },
          { name: 'accrued', internalType: 'uint256', type: 'uint256' }
        ]
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'depositor', internalType: 'address', type: 'address' },
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' },
      { name: 'duration', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'lock',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'address', type: 'address' }],
    name: 'lockDurationMap',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'data', internalType: 'bytes', type: 'bytes' }],
    name: 'setConfig',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'functionSig', internalType: 'bytes4', type: 'bytes4' },
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'isEnabled', internalType: 'bool', type: 'bool' }
    ],
    name: 'setPermission',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'store',
    outputs: [{ name: '', internalType: 'contract VotingEscrowStore', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'token',
    outputs: [{ name: '', internalType: 'contract PuppetToken', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [],
    name: 'vToken',
    outputs: [{ name: '', internalType: 'contract PuppetVoteToken', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'receiver', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'vest',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'address', type: 'address' }],
    name: 'vestMap',
    outputs: [
      { name: 'amount', internalType: 'uint256', type: 'uint256' },
      { name: 'remainingDuration', internalType: 'uint256', type: 'uint256' },
      { name: 'lastAccruedTime', internalType: 'uint256', type: 'uint256' },
      { name: 'accrued', internalType: 'uint256', type: 'uint256' }
    ],
    stateMutability: 'view'
  },
  { type: 'error', inputs: [], name: 'Permission__CallerNotAuthority' },
  { type: 'error', inputs: [], name: 'Permission__Unauthorized' },
  { type: 'error', inputs: [], name: 'VotingEscrowLogic__ExceedMaxTime' },
  {
    type: 'error',
    inputs: [{ name: 'accured', internalType: 'uint256', type: 'uint256' }],
    name: 'VotingEscrowLogic__ExceedingAccruedAmount'
  },
  { type: 'error', inputs: [], name: 'VotingEscrowLogic__ZeroAmount' }
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// VotingEscrowStore
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const votingEscrowStoreAbi = [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_authority',
        internalType: 'contract IAuthority',
        type: 'address'
      },
      {
        name: '_router',
        internalType: 'contract TokenRouter',
        type: 'address'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [],
    name: 'authority',
    outputs: [{ name: '', internalType: 'contract IAuthority', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: 'user', internalType: 'address', type: 'address' }],
    name: 'canCall',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [{ name: '_token', internalType: 'contract IERC20', type: 'address' }],
    name: 'getTokenBalance',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: '_token', internalType: 'contract IERC20', type: 'address' },
      { name: '_bank', internalType: 'contract BankStore', type: 'address' },
      { name: '_value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'interTransferIn',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '_token', internalType: 'contract IERC20', type: 'address' }],
    name: 'recordTransferIn',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'isEnabled', internalType: 'bool', type: 'bool' }
    ],
    name: 'setAccess',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '_token', internalType: 'contract IERC20', type: 'address' }],
    name: 'syncTokenBalance',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'contract IERC20', type: 'address' }],
    name: 'tokenBalanceMap',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    inputs: [
      { name: '_token', internalType: 'contract IERC20', type: 'address' },
      { name: '_depositor', internalType: 'address', type: 'address' },
      { name: '_value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transferIn',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    inputs: [
      { name: '_token', internalType: 'contract IERC20', type: 'address' },
      { name: '_receiver', internalType: 'address', type: 'address' },
      { name: '_value', internalType: 'uint256', type: 'uint256' }
    ],
    name: 'transferOut',
    outputs: [],
    stateMutability: 'nonpayable'
  },
  { type: 'error', inputs: [], name: 'Access__CallerNotAuthority' },
  { type: 'error', inputs: [], name: 'Access__Unauthorized' },
  { type: 'error', inputs: [], name: 'BankStore__InsufficientBalance' }
] as const
