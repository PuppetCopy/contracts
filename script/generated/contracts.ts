// This file is auto-generated from Puppet deployments.json and forge-artifacts
// Do not edit manually.

import accountAbi from './abi/puppetAccount.js'
import accountstoreAbi from './abi/puppetAccountStore.js'
import dictatorshipAbi from './abi/puppetDictatorship.js'
import feemarketplaceAbi from './abi/puppetFeeMarketplace.js'
import feemarketplacestoreAbi from './abi/puppetFeeMarketplaceStore.js'
import mirrorAbi from './abi/puppetMirror.js'
import puppettokenAbi from './abi/puppetPuppetToken.js'
import routerproxyAbi from './abi/puppetRouterProxy.js'
import sequencerrouterAbi from './abi/puppetSequencerRouter.js'
import settleAbi from './abi/puppetSettle.js'
import subscribeAbi from './abi/puppetSubscribe.js'
import tokenrouterAbi from './abi/puppetTokenRouter.js'
import userrouterAbi from './abi/puppetUserRouter.js'

export const PUPPET_CONTRACT_MAP = {
  Dictatorship: {
    address: '0x5a5648423e6110e9b4AE94e88bd66F963a5253C2',
    chainId: 42161,
    abi: dictatorshipAbi
  },
  PuppetToken: {
    address: '0x10f7F9e33FaF343F9CfE1c69b177ed86Bc760B4e',
    chainId: 42161,
    abi: puppettokenAbi
  },
  TokenRouter: {
    address: '0x3Ccfe071124Cb0f6715038485Eb26096C35FE5EE',
    chainId: 42161,
    abi: tokenrouterAbi
  },
  RouterProxy: {
    address: '0xB43f1E80164bA23884076b9e816AC28895D76A34',
    chainId: 42161,
    abi: routerproxyAbi
  },
  AccountStore: {
    address: '0xc7Fb87E6Eb9bcE66ca32acb01B99cAF70cfE5DB0',
    chainId: 42161,
    abi: accountstoreAbi
  },
  FeeMarketplaceStore: {
    address: '0xAf97414983197b30485828ddb3De60134871dBe2',
    chainId: 42161,
    abi: feemarketplacestoreAbi
  },
  FeeMarketplace: {
    address: '0x1290fE1CC845D9D564183d3d8C65122DCf908ED5',
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
  SequencerRouter: {
    address: '0xaF02B24e394d73b62efaB84f4c231D7cE1acCB85',
    chainId: 42161,
    abi: sequencerrouterAbi
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
  }
} as const
