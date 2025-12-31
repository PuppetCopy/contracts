import { $, file, write } from 'bun'
import { createPublicClient, getAddress, http } from 'viem'

// Bun automatically loads .env files
const rpcUrl = Bun.env.RPC_URL
const scriptName = Bun.env.SCRIPT_NAME
const privateKey = Bun.env.DEPLOYER_PRIVATE_KEY

if (!rpcUrl) throw new Error('Missing RPC_URL')
if (!scriptName) throw new Error('Missing SCRIPT_NAME')
if (!privateKey) throw new Error('Missing DEPLOYER_PRIVATE_KEY')

const client = createPublicClient({
  transport: http(rpcUrl)
})

const chainId = await client.getChainId()
const scriptFile = `${scriptName}.s.sol`

console.log(`Deploying ${scriptName} on chain ${chainId}...`)

type IDeploymentArtifact = {
  transactions: {
    hash: string
    transactionType: string
    contractName: string
    contractAddress: string
  }[]
  chain: number
}

const result = await $`forge script \
  script/${scriptFile}:${scriptName} \
  --broadcast \
  --verify \
  --resume \
  -vvvv \
  --rpc-url ${rpcUrl} \
  --private-key ${privateKey}`.nothrow()

if (result.exitCode !== 0) {
  console.error('Forge script failed')
  process.exit(1)
}

const deploymentsFilePath = './deployments.json'
const deploymentsFile = file(deploymentsFilePath)
const deployments: Record<string, Record<string, string>> = (await deploymentsFile.exists())
  ? await deploymentsFile.json()
  : {}

const broadcastFile = file(`./broadcast/${scriptFile}/${chainId}/run-latest.json`)
const latestRun = (await broadcastFile.json()) as IDeploymentArtifact

const chainKey = String(latestRun.chain)
deployments[chainKey] ??= {}

for (const tx of latestRun.transactions) {
  if (tx.contractName) {
    deployments[chainKey][tx.contractName] = getAddress(tx.contractAddress)
  }
}

await write(deploymentsFilePath, JSON.stringify(deployments, null, 2))
console.log(`Updated deployments.json for chain ${chainKey}`)

// Regenerate TypeScript
console.log('Regenerating TypeScript...')
await $`bun run generate && bun run build:ts`
console.log('Done!')
