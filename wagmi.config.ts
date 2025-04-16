import { defineConfig } from '@wagmi/cli'
import { foundry } from '@wagmi/cli/plugins'

export default defineConfig({
  out: "deployments/abi.ts",
  plugins: [
    foundry({
      include: ['contracts/src/**/*.sol'],
      forge: {
        clean: true,
      }
    }),
  ],
})