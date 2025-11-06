import { $, file, write } from 'bun'
import { createPublicClient, getAddress, http } from 'viem'

console.log('Running deployment script...')

const rpcUrl = process.env.RPC_URL

if (!rpcUrl) {
  throw new Error('Missing environment variable: RPC_URL')
}

// Create a Viem client
const client = createPublicClient({
  transport: http(rpcUrl)
})

const chainId = await client.getChainId()
const scriptName = 'DeployUserRouter'
const scriptFile = `${scriptName}.s.sol`

console.log(`Config: ${JSON.stringify({ chainId, scriptName })}`)

if (!chainId || !scriptName) {
  throw new Error(`Missing required environment variables: ${JSON.stringify({ chainId, scriptName })}`)
}

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
  --broadcast \
  --verify \
  -vvvv \
  --rpc-url ${rpcUrl}`

const deploymentsFilePath = './deployments.json'
const deploymentsFile = file(deploymentsFilePath)
const deployments = (await deploymentsFile.exists())
  ? await deploymentsFile.json()
  : ({} as {
      [chainId: string]: {
        [contractName: string]: string
      }
    })

const broadcastFile = file(`./broadcast/${scriptFile}/${chainId}/run-latest.json`)
const latestRun = (await broadcastFile.json()) as IDeploymentArtifact

latestRun.transactions.reduce((acc, tx) => {
  if (!tx.contractName) {
    return acc
  }

  acc[String(latestRun.chain)] ??= {}
  acc[String(latestRun.chain)][tx.contractName] = getAddress(tx.contractAddress)

  return acc
}, deployments)

const jsonString = JSON.stringify(deployments, null, 2)
await write(deploymentsFilePath, jsonString, { createPath: true })
console.log(jsonString)
