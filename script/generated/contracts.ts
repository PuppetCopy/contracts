// This file is auto-generated from Puppet deployments.json and forge-artifacts
// Do not edit manually.

import accountAbi from './abi/puppetAccount.js'
import accountstoreAbi from './abi/puppetAccountStore.js'
import dictatorshipAbi from './abi/puppetDictatorship.js'
import feemarketplaceAbi from './abi/puppetFeeMarketplace.js'
import feemarketplacestoreAbi from './abi/puppetFeeMarketplaceStore.js'
import matchmakerrouterAbi from './abi/puppetMatchmakerRouter.js'
import mirrorAbi from './abi/puppetMirror.js'
import puppettokenAbi from './abi/puppetPuppetToken.js'
import puppetvotetokenAbi from './abi/puppetPuppetVoteToken.js'
import routerproxyAbi from './abi/puppetRouterProxy.js'
import settleAbi from './abi/puppetSettle.js'
import subscribeAbi from './abi/puppetSubscribe.js'
import tokenrouterAbi from './abi/puppetTokenRouter.js'
import userrouterAbi from './abi/puppetUserRouter.js'

export const PUPPET_CONTRACT_MAP = {
  Dictatorship: {
    address: '0x686B8A9701659F623c28e0A7c5053D9a499EFfE8',
    chainId: 42161,
    abi: dictatorshipAbi
  },
  PuppetToken: {
    address: '0x3b1A496303b8272C6558b1E9159074F13176adc8',
    chainId: 42161,
    abi: puppettokenAbi
  },
  TokenRouter: {
    address: '0x50403a2A8bfFedFE685c9729670614401d5ADcC3',
    chainId: 42161,
    abi: tokenrouterAbi
  },
  RouterProxy: {
    address: '0xa7E7a4F384885BF9b169FceD9e96F1220e5c1293',
    chainId: 42161,
    abi: routerproxyAbi
  },
  AccountStore: {
    address: '0xc7Fb87E6Eb9bcE66ca32acb01B99cAF70cfE5DB0',
    chainId: 42161,
    abi: accountstoreAbi
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
  Mirror: {
    address: '0xDfcfA30D3950ae4E94C869798276A06B167Bd5f1',
    chainId: 42161,
    abi: mirrorAbi
  },
  Settle: {
    address: '0x96F9fE6293ac6ED89c16e37177665a4904c3fe9f',
    chainId: 42161,
    abi: settleAbi
  },
  MatchmakerRouter: {
    address: '0xaF02B24e394d73b62efaB84f4c231D7cE1acCB85',
    chainId: 42161,
    abi: matchmakerrouterAbi
  },
  UserRouter: {
    address: '0xD65A4bD84Ae0B2434cF539ef5589b2C63a848BCf',
    chainId: 42161,
    abi: userrouterAbi
  },
  Account: {
    address: '0x40Fc327E61c0B55945585FD255FEC42F4C2e833e',
    chainId: 42161,
    abi: accountAbi
  },
  Subscribe: {
    address: '0xb7C104b156A2933161a4Cb92B4981858258de649',
    chainId: 42161,
    abi: subscribeAbi
  },
  PuppetVoteToken: {
    address: '0x95718B4EEC9316E3a61ef75A2BBD3951cF465Bff',
    chainId: 42161,
    abi: puppetvotetokenAbi
  }
} as const
