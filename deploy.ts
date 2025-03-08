import { $, file, write } from "bun"

type IDeploymentMetadata = {
	[chainId: string]: {
		[contractName: string]: string
	}
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

const config = {
	chainId: process.env.CHAIN,
	RPC_URL: process.env.ARBITRUM_RPC_URL,
	script: process.env.SCRIPT,
}

console.log(`Deploying ${config.chainId}:${config.script} with RPC_URL ${config.RPC_URL}`)

if (!config.RPC_URL || !config.chainId) {
	throw new Error("RPC_URL is required")
}

const scriptFile = `${config.script}.s.sol`

await $`FOUNDRY_PROFILE=prod forge script script/${scriptFile}:${config.script} --broadcast --verify -vvvv --rpc-url $ARBITRUM_RPC_URL`

const deploymentsFilePath = "./deployments/addresses.json"
const deploymentsFile = file(deploymentsFilePath)
const deployments = (await deploymentsFile.exists())
	? await deploymentsFile.json()
	: ({} as IDeploymentMetadata)

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
