import { defineConfig } from 'vocs'

export default defineConfig({
  title: '',
  outlineFooter: false,
  sidebar: [
    {
      text: 'About',
      link: '/about',
    },
    {
      text: 'Tokenomics',
      link: '/tokenomics',
    },
    {
      text: 'Core NatSpec',
      collapsed: false,
      items: [
        {
          text: 'PuppetToken.sol',
          link: '/contracts/tokenomics/PuppetToken',
        },
        {
          text: 'VotingEscrow.sol',
          link: '/contracts/tokenomics/VotingEscrow',
        },
        {
          text: 'RevenueLogic.sol',
          link: '/contracts/tokenomics/RevenueLogic',
        },
        {
          text: 'RewardLogic.sol',
          link: '/contracts/tokenomics/RewardLogic',
        },
      ],
      link: '/contracts/README',
    },
  ]
})
