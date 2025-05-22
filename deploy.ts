import { $, file, write } from 'bun'
import { createPublicClient, http } from 'viem'

console.log('Running deployment script...')

const rpcUrl = process.env.ARBITRUM_RPC_URL
// Create a Viem client
const client = createPublicClient({
  transport: http(rpcUrl)
})

const chainId = await client.getChainId()
const scriptName = process.env.SCRIPT

console.log(`Config: ${JSON.stringify({ chainId, scriptName })}`)

if (!chainId || !scriptName) {
  throw new Error(`Missing required environment variables: ${JSON.stringify({ chainId, scriptName })}`)
}

const scriptFile = `${scriptName}.s.sol`

type IDeploymentArtifact = {
  transactions: {
    hash: string
    transactionType: string
    contractName: string
    contractAddress: string
    function: null
    arguments: string[]
    transaction: {
      from: string
      gas: string
      value: string
      input: string
      nonce: string
      chainId: string
      to?: undefined
    }
    additionalContracts: never[]
    isFixedGasLimit: boolean
  }[]
  chain: number
  commit: string
  timestamp: number
}

console.log(`Deploying ${chainId}:${scriptName} with RPC_URL ${rpcUrl}`)

await $`forge script \
  script/${scriptFile}:${scriptName} \
  --slow \
  --broadcast \
  --verify \
  --resume \
  -vvvv \
  --rpc-url ${rpcUrl}`

const deploymentsFilePath = './deployments/addresses.json'
const deploymentsFile = file(deploymentsFilePath)
const deployments = (await deploymentsFile.exists())
  ? await deploymentsFile.json()
  : ({} as {
      [chainId: string]: {
        [contractName: string]: string
      }
    })

const latestRun = (await import(
  `./broadcast/${scriptFile}/${chainId}/run-latest.json`,
  { with: { type: 'json' } } // Added 'with' assertion for JSON import
)) as IDeploymentArtifact

latestRun.transactions.reduce((acc, tx) => {
  if (!tx.contractName) {
    return acc
  }

  acc[String(latestRun.chain)] ??= {}
  acc[String(latestRun.chain)][tx.contractName] = tx.contractAddress

  return acc
}, deployments)

const jsonString = JSON.stringify(deployments, null, 2)
await write(deploymentsFilePath, jsonString, { createPath: true })
console.log(jsonString)
