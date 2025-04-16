import { $, file, write } from "bun"


const config = {
	chainId: process.env.CHAIN,
	RPC_URL: process.env.ARBITRUM_RPC_URL,
	script: process.env.SCRIPT,
}

if (!config.RPC_URL || !config.script || !config.chainId) {
	throw new Error(`Missing required environment variables: ${JSON.stringify(config)}`)
}

const scriptFile = `${config.script}.s.sol`

console.log(`Generating wagmi for ${scriptFile}`)
await $`wagmi generate`



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

console.log(`Deploying ${config.chainId}:${config.script} with RPC_URL ${config.RPC_URL}`)



await $`forge script script/${scriptFile}:${config.script} --broadcast --verify -vvvv --rpc-url $ARBITRUM_RPC_URL`

const deploymentsFilePath = "./deployments/addresses.json"
const deploymentsFile = file(deploymentsFilePath)
const deployments = (await deploymentsFile.exists())
	? await deploymentsFile.json()
	: ({} as {
		[chainId: string]: {
			[contractName: string]: string
		}
	})

const latestRun = (await import(
	`./broadcast/${scriptFile}/${config.chainId}/run-latest.json`
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
