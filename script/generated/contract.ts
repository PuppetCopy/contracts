// Main entrypoint for Puppet contracts
// This file is NOT auto-generated - it provides combined ABIs for router patterns

import { erc20Abi } from 'viem'
import referralStorageAbi from './abi/externalReferralStorage.js'
import { PUPPET_CONTRACT_MAP } from './contracts.js'
import { puppetErrorAbi } from './errors.js'
import { gmxErrorAbi } from './gmx/abi/gmxErrors.js'

// Combined ABIs for router proxy pattern and error handling
export const CONTRACT = {
  UserRouter: {
    address: PUPPET_CONTRACT_MAP.RouterProxy.address,
    abi: [...PUPPET_CONTRACT_MAP.UserRouter.abi, ...PUPPET_CONTRACT_MAP.RouterProxy.abi, ...puppetErrorAbi] as const,
    chainId: PUPPET_CONTRACT_MAP.UserRouter.chainId
  },
  SequencerRouter: {
    address: PUPPET_CONTRACT_MAP.SequencerRouter.address,
    abi: [...PUPPET_CONTRACT_MAP.SequencerRouter.abi, ...puppetErrorAbi, ...gmxErrorAbi] as const,
    chainId: PUPPET_CONTRACT_MAP.SequencerRouter.chainId
  },
  CustomError: {
    abi: puppetErrorAbi
  },
  GmxCustomError: {
    abi: gmxErrorAbi
  }
} as const

// External contracts (not Puppet contracts)
export const EXTERNAL_CONTRACT = {
  GMX: {
    address: '0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a' as const,
    abi: erc20Abi
  },
  ReferralStorage: {
    address: '0xe6fab3F0c7199b0d34d7FbE83394fc0e0D06e99d' as const,
    abi: referralStorageAbi
  }
} as const
