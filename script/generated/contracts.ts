// This file is auto-generated from Puppet deployments.json and forge-artifacts
// Do not edit manually.

import dictatorshipAbi from './abi/puppetDictatorship.js'
import puppettokenAbi from './abi/puppetPuppetToken.js'
import puppetvotetokenAbi from './abi/puppetPuppetVoteToken.js'
import feemarketplacestoreAbi from './abi/puppetFeeMarketplaceStore.js'
import feemarketplaceAbi from './abi/puppetFeeMarketplace.js'
import matchAbi from './abi/puppetMatch.js'
import allocateAbi from './abi/puppetAllocate.js'
import positionAbi from './abi/puppetPosition.js'
import userrouterAbi from './abi/puppetUserRouter.js'
import masterhookAbi from './abi/puppetMasterHook.js'
import gmxstageAbi from './abi/puppetGmxStage.js'
import tokenrouterAbi from './abi/puppetTokenRouter.js'
import proxyuserrouterAbi from './abi/puppetProxyUserRouter.js'

export const PUPPET_CONTRACT_MAP = {
  Dictatorship: {
    address: '0x778820d455AA439F92578521F751c3439B193EC3',
    chainId: 42161,
    abi: dictatorshipAbi
  },
  PuppetToken: {
    address: '0x3b1A496303b8272C6558b1E9159074F13176adc8',
    chainId: 42161,
    abi: puppettokenAbi
  },
  PuppetVoteToken: {
    address: '0x95718B4EEC9316E3a61ef75A2BBD3951cF465Bff',
    chainId: 42161,
    abi: puppetvotetokenAbi
  },
  FeeMarketplaceStore: {
    address: '0xaF5798725AFA764748f9Dc85E8418510B459F722',
    chainId: 42161,
    abi: feemarketplacestoreAbi
  },
  FeeMarketplace: {
    address: '0x4d80C64A10e44c724203485A4349727e01A0BaDF',
    chainId: 42161,
    abi: feemarketplaceAbi
  },
  Match: {
    address: '0xE7fc062B5015ac5e9fa9DC3E8182B1959e7252cc',
    chainId: 42161,
    abi: matchAbi
  },
  Allocate: {
    address: '0x8EFACa3d5a6dEcfcAE13E6521897E15E86746796',
    chainId: 42161,
    abi: allocateAbi
  },
  Position: {
    address: '0xe50cA753400bf25Ebc9480F5D04f2F22B978b4fd',
    chainId: 42161,
    abi: positionAbi
  },
  UserRouter: {
    address: '0x456289bE407E3Ed74E727804BBD7FC65f52b2e65',
    chainId: 42161,
    abi: userrouterAbi
  },
  UserRouterImpl: {
    address: '0x0B1ba8b68CF1282a7770DecB650511126DF5142B',
    chainId: 42161
  },
  MasterHook: {
    address: '0xFD79dEefa341313Ed06Ba3709d39eC5aA062aDac',
    chainId: 42161,
    abi: masterhookAbi
  },
  GmxStage: {
    address: '0x4c6810e9b7b787fa5419C793912F6Aa37e485F7F',
    chainId: 42161,
    abi: gmxstageAbi
  },
  TokenRouter: {
    address: '0x0c69DB327925cd9367E39B7CB773Fcf97005a02c',
    chainId: 42161,
    abi: tokenrouterAbi
  },
  ProxyUserRouter: {
    address: '0x0DD0CdeeC28F81a404474d26eB72affDA3A18f7d',
    chainId: 42161,
    abi: proxyuserrouterAbi
  }
} as const
