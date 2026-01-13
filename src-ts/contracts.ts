// This file is auto-generated from Puppet deployments.toml and forge-artifacts
// Do not edit manually.

import dictatorshipAbi from './abi/puppetDictatorship.js'
import positionAbi from './abi/puppetPosition.js'
import registryAbi from './abi/puppetRegistry.js'
import masterhookAbi from './abi/puppetMasterHook.js'
import withdrawAbi from './abi/puppetWithdraw.js'
import masterrouterAbi from './abi/puppetMasterRouter.js'
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
    address: '0xcef479cf0C6A8855561554738fe7aC4f43d45756',
    abi: positionAbi
  },
  Registry: {
    address: '0x2D28Ac8DE4c2b45e9252ef835929AAECbdF86141',
    abi: registryAbi
  },
  MasterHook: {
    address: '0xBBE149F3B6D27FBc60c2e73D13375AAfA538eC30',
    abi: masterhookAbi
  },
  Withdraw: {
    address: '0x4f87978d851D9D17B73D426A15A58CF9F064e16E',
    abi: withdrawAbi
  },
  MasterRouter: {
    address: '0xD2e09A9b0C6bd10e07f2874B9fd479E7B5Ff2f13',
    abi: masterrouterAbi
  },
  TokenRouter: {
    address: '0x418aE8cc6628E7921aF2c6f6526d5f54537670bb',
    chainId: 42161,
    blockNumber: 420731804,
    abi: tokenrouterAbi
  },
  ProxyUserRouter: {
    address: '0x0a4f9244C67F743A590599226A180b76af2829De',
    chainId: 42161,
    blockNumber: 420731809,
    abi: proxyuserrouterAbi
  },
  Match: {
    address: '0x403124Bfa8E795E82b1976B06D7a453BFcff1A7B',
    chainId: 42161,
    blockNumber: 420731813,
    abi: matchAbi
  },
  Allocate: {
    address: '0xA53fAc1423A35185bd16af21FC1De1f288a3Fa7A',
    chainId: 42161,
    blockNumber: 420731817,
    abi: allocateAbi
  },
  UserRouter: {
    address: '0x18C48Cd6f71E17dA86F7b375fEB44678188679e7',
    chainId: 42161,
    blockNumber: 420731821,
    abi: userrouterAbi
  },
  GmxStage: {
    address: '0x0679bD70463EfC2b31A3914C483d3083004dBE27',
    chainId: 42161,
    blockNumber: 420731825,
    abi: gmxstageAbi
  }
} as const
