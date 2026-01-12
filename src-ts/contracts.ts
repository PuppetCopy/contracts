// This file is auto-generated from Puppet deployments.toml and forge-artifacts
// Do not edit manually.

import dictatorshipAbi from './abi/puppetDictatorship.js'
import positionAbi from './abi/puppetPosition.js'
import registryAbi from './abi/puppetRegistry.js'
import masterhookAbi from './abi/puppetMasterHook.js'
import withdrawAbi from './abi/puppetWithdraw.js'
import tokenrouterAbi from './abi/puppetTokenRouter.js'
import proxyuserrouterAbi from './abi/puppetProxyUserRouter.js'
import matchAbi from './abi/puppetMatch.js'
import allocateAbi from './abi/puppetAllocate.js'
import userrouterAbi from './abi/puppetUserRouter.js'
import gmxstageAbi from './abi/puppetGmxStage.js'

export const PUPPET_CONTRACT_MAP = {
  Dictatorship: {
    address: '0x397CA6373D46a15510Ce3045d09b7cbB3Af68EAa',
    abi: dictatorshipAbi
  },
  Position: {
    address: '0x49F7e5F896ad4530eBedB1d4697Ffb5b31f34972',
    abi: positionAbi
  },
  Registry: {
    address: '0x0000000000000000000000000000000000000000',
    abi: registryAbi
  },
  MasterHook: {
    address: '0x0bf4f1740E9809b88c9B0317654EB80c35CEe33E',
    abi: masterhookAbi
  },
  Withdraw: {
    address: '0x4f87978d851D9D17B73D426A15A58CF9F064e16E',
    abi: withdrawAbi
  },
  TokenRouter: {
    address: '0x0c69DB327925cd9367E39B7CB773Fcf97005a02c',
    chainId: 42161,
    abi: tokenrouterAbi
  },
  ProxyUserRouter: {
    address: '0x8ea4425d1f26f1c715AF4020427480af9Fef20fF',
    chainId: 42161,
    blockNumber: 418295882,
    abi: proxyuserrouterAbi
  },
  Match: {
    address: '0xE7eAB5469ebbE492469E723FF5DAe7Cb91c6D04e',
    chainId: 42161,
    blockNumber: 418295895,
    abi: matchAbi
  },
  Allocate: {
    address: '0x5d2D41305b33DFf126FCb9585f919c7f13d183dB',
    chainId: 42161,
    blockNumber: 418295899,
    abi: allocateAbi
  },
  UserRouter: {
    address: '0x91DeC0891d3d5DF935790C6dc97c674f7f976994',
    chainId: 42161,
    blockNumber: 418295904,
    abi: userrouterAbi
  },
  GmxStage: {
    address: '0xB5E7CC3eD87F4f517351D50C639Fe9aB22b1D2Eb',
    chainId: 42161,
    blockNumber: 418295909,
    abi: gmxstageAbi
  }
} as const
