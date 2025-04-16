import * as abi from "./abi.js";

export const CONTRACT = {
  42161: {
    RouterProxy: {
      address: "0x186194beB8FF7c6CeE8E2C56F0969c87e396c118",
      abi: [...abi.routerAbi, ...abi.routerProxyAbi],
    },

    Dictatorship: {
      address: "0x583367f217a6684039d378C0a142Cbe17F2FC058",
      abi: abi.dictatorshipAbi,
    },
    PuppetToken: {
      address: "0x2F076BdCE9bf6f118d612Ee6bAa9BCF6266De199",
      abi: abi.puppetTokenAbi,
    },
    PuppetVoteToken: {
      address: "",
      abi: abi.puppetVoteTokenAbi,
    },
    TokenRouter: {
      address: "0xb05Ec3598F5fA2f997B1a79E5e6995a158E8C26D",
      abi: abi.routerAbi,
    },
    AllocationStore: {
      address: "",
      abi: abi.allocationStoreAbi,
    },

    MatchingRule: {
      address: "0x1fC2D4aE5E8bA3fE3dF7B6c8D9B1fF8C8E0eA8C7",
      abi: abi.matchingRuleAbi,
    },
    MirrorPosition: {
      address: "0x4F2B5C8D3E1A7F6C9D5B2A8E4F8C8E0eA8C7",
      abi: abi.mirrorPositionAbi,
    },
    FeeMarketplace: {
      address: "0x5F2B5C8D3E1A7F6C9D5B2A8E4F8C8E0eA8C7",
      abi: abi.feeMarketplaceAbi,
    },

    CustomError: {
      abi: abi.errorAbi,
    },
  },
} as const;
