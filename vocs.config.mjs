import { defineConfig } from 'vocs'

export default defineConfig({
  title: '',
  sidebar: [
    {
      text: 'Getting Started',
      link: '/getting-started',
    },
    {
      text: 'Example',
      link: '/example',
    },
    {
      text: 'Contracts',
      collapsed: false,
      items: [
        {
          text: 'PuppetToken',
          link: '/contracts/src/token/PuppetToken.sol/puppetToken',
        },
        // {
        //   text: 'ERC721',
        //   link: '/contracts/erc'
        // }
      ],
      link: '/contracts/README',
    },
  ],
  vite: {
  }
})
