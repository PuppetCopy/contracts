import { $, file, write } from 'bun'
import { createPublicClient, getAddress, http } from 'viem'

// Bun automatically loads .env files
const rpcUrl = Bun.env.RPC_URL
const scriptName = Bun.env.SCRIPT_NAME
const privateKey = Bun.env.DEPLOYER_PRIVATE_KEY
const shouldVerify = Bun.env.VERIFY !== 'false'
const shouldResume = Bun.env.RESUME === 'true'

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

const verifyFlag = shouldVerify ? '--verify' : ''
const resumeFlag = shouldResume ? '--resume' : ''

const result = await $`forge script \
  script/${scriptFile}:${scriptName} \
  --broadcast \
  ${verifyFlag} \
  ${resumeFlag} \
  -vvvv \
  --rpc-url ${rpcUrl} \
  --private-key ${privateKey}`
  .env({ FOUNDRY_PROFILE: 'prod' })
  .nothrow()

if (result.exitCode !== 0) {
  console.error('Forge script failed')
  process.exit(1)
}

const deploymentsFilePath = './deployments.json'
const deploymentsFile = file(deploymentsFilePath)
const deployments: Record<string, Record<string, string>> = (await deploymentsFile.exists())
  ? await deploymentsFile.json()
  : {}

const broadcastPath = `./broadcast/${scriptFile}/${chainId}/run-latest.json`
const broadcastFile = file(broadcastPath)

if (!(await broadcastFile.exists())) {
  console.error(`Broadcast file not found: ${broadcastPath}`)
  process.exit(1)
}

let latestRun: IDeploymentArtifact
try {
  latestRun = (await broadcastFile.json()) as IDeploymentArtifact
} catch (e) {
  console.error(`Failed to parse broadcast file: ${broadcastPath}`)
  process.exit(1)
}

const chainKey = String(latestRun.chain)
deployments[chainKey] ??= {}

const deployed: string[] = []
for (const tx of latestRun.transactions) {
  if (tx.transactionType === 'CREATE' && tx.contractName) {
    deployments[chainKey][tx.contractName] = getAddress(tx.contractAddress)
    deployed.push(tx.contractName)
  }
}

await write(deploymentsFilePath, JSON.stringify(deployments, null, 2))
console.log(`Updated deployments.json for chain ${chainKey}`)
console.log(`Deployed: ${deployed.join(', ')}`)

// Regenerate TypeScript
console.log('Regenerating TypeScript...')
await $`bun run generate && bun run build:ts`
console.log('Done!')
