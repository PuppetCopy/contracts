import * as abi from "./abi.js";
import addresses from './addresses.json' with { type: "json" };


export const PUPPET_ADDRESSES = {
  42161: {
    RouterProxy: {
      address: addresses[42161].RouterProxy,
      abi: [...abi.routerAbi, ...abi.routerProxyAbi],
    },

    Dictatorship: {
      address: addresses[42161].Dictatorship,
      abi: abi.dictatorshipAbi,
    },
    PuppetToken: {
      address: addresses[42161].PuppetToken,
      abi: abi.puppetTokenAbi,
    },
    PuppetVoteToken: {
      address: "",
      abi: abi.puppetVoteTokenAbi,
    },
    TokenRouter: {
      address: addresses[42161].TokenRouter,
      abi: abi.routerAbi,
    },
    AllocationStore: {
      address: "",
      abi: abi.allocationStoreAbi,
    },

    MatchingRule: {
      address: "",
      abi: abi.matchingRuleAbi,
    },
    MirrorPosition: {
      address: "",
      abi: abi.mirrorPositionAbi,
    },
    FeeMarketplace: {
      address: "",
      abi: abi.feeMarketplaceAbi,
    }
  },
} as const;
