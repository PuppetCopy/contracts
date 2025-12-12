#!/usr/bin/env bun
import { join } from 'path'
import { generateEventParamsCode, parseEventsFromSolidity } from './parse-events.js'

const FORGE_ARTIFACTS_PATH = './forge-artifacts'
const DEPLOYMENTS_PATH = './deployments.json'
const ERROR_SOL_PATH = './src/utils/Error.sol'
const OUTPUT_DIR = './script/generated'

type ContractInfo = {
  name: string
  address: string
  chainId: number
  abi?: unknown[]
}

async function findAbiFile(contractName: string): Promise<unknown[] | undefined> {
  try {
    const artifactPath = join(FORGE_ARTIFACTS_PATH, `${contractName}.sol`, `${contractName}.json`)
    const artifactFile = Bun.file(artifactPath)

    if (await artifactFile.exists()) {
      const artifact = await artifactFile.json()
      return artifact.abi
    }

    console.warn(`  No ABI found for ${contractName}`)
    return undefined
  } catch (error) {
    console.error(`  Error loading ABI for ${contractName}:`, error)
    return undefined
  }
}

async function generateErrorAbi(): Promise<void> {
  console.log('Generating Error ABI from Error.sol...')

  const errorSolContent = await Bun.file(ERROR_SOL_PATH).text()
  const errorRegex = /error\s+(\w+)\s*\((.*?)\)\s*;/g
  const errors: unknown[] = []

  let match: RegExpExecArray | null
  while ((match = errorRegex.exec(errorSolContent)) !== null) {
    const errorName = match[1]
    const params = match[2]!.trim()

    const errorAbi: Record<string, unknown> = {
      type: 'error',
      name: errorName
    }

    if (params) {
      const inputs: unknown[] = []
      const paramList = params.split(',').map(p => p.trim())

      for (const param of paramList) {
        const paramMatch = param.match(/^(.+?)\s+(\w+)$/)
        if (paramMatch) {
          let [, type, name] = paramMatch
          if (type === 'uint') type = 'uint256'
          if (type === 'IERC20') type = 'address'

          let internalType = type
          if (type === 'address' && param.includes('IERC20')) {
            internalType = 'contract IERC20'
          }

          inputs.push({
            name,
            internalType,
            type: type === 'contract IERC20' ? 'address' : type
          })
        }
      }

      if (inputs.length > 0) {
        errorAbi.inputs = inputs
      }
    } else {
      errorAbi.inputs = []
    }

    errors.push(errorAbi)
  }

  const output = `// This file is auto-generated from contracts/src/utils/Error.sol
// Do not edit manually.

export const puppetErrorAbi = ${JSON.stringify(errors, null, 2).replace(/"(\w+)":/g, '$1:')} as const
`

  await Bun.write(`${OUTPUT_DIR}/errors.ts`, output)
  console.log(`  Generated error ABI with ${errors.length} errors`)
}

async function generateContracts(): Promise<void> {
  console.log('Loading Puppet contract deployments...')

  const deploymentsFile = Bun.file(DEPLOYMENTS_PATH)
  const deployments = await deploymentsFile.json()

  const contracts: ContractInfo[] = []

  for (const chainIdStr of Object.keys(deployments)) {
    const chainId = Number(chainIdStr)
    const addresses = deployments[chainId]

    const contractNames = Object.keys(addresses)
    console.log(`  Found ${contractNames.length} contracts on chain ${chainId}`)

    for (const contractName of contractNames) {
      const abi = await findAbiFile(contractName)

      contracts.push({
        name: contractName,
        address: addresses[contractName],
        chainId,
        abi
      })
    }
  }

  console.log(`  Loaded ${contracts.length} contracts across ${Object.keys(deployments).length} chain(s)`)

  // Generate individual ABI files
  for (const contract of contracts) {
    if (contract.abi) {
      const abiFileName = `puppet${contract.name}`
      const abiFilePath = `${OUTPUT_DIR}/abi/${abiFileName}.ts`
      const abiContent = `// This file is auto-generated from forge-artifacts/${contract.name}.sol/${contract.name}.json
// Do not edit manually.

export default ${JSON.stringify(contract.abi, null, 2)} as const
`
      await Bun.write(abiFilePath, abiContent)
    }
  }

  // Generate ABI index file
  const abiIndexContent = `// This file is auto-generated. Do not edit manually.

${contracts
  .filter(c => c.abi)
  .map(c => `export { default as ${c.name.toLowerCase()}Abi } from './puppet${c.name}.js'`)
  .join('\n')}
`
  await Bun.write(`${OUTPUT_DIR}/abi/index.ts`, abiIndexContent)

  // Generate contracts map
  const contractsContent = `// This file is auto-generated from Puppet deployments.json and forge-artifacts
// Do not edit manually.

${contracts
  .filter(c => c.abi)
  .map(c => `import ${c.name.toLowerCase()}Abi from './abi/puppet${c.name}.js'`)
  .join('\n')}

export const PUPPET_CONTRACT_MAP = {
${contracts
  .map(contract => {
    if (contract.abi) {
      return `  ${contract.name}: {
    address: '${contract.address}',
    chainId: ${contract.chainId},
    abi: ${contract.name.toLowerCase()}Abi
  }`
    }
    return `  ${contract.name}: {
    address: '${contract.address}',
    chainId: ${contract.chainId}
  }`
  })
  .join(',\n')}
} as const
`

  await Bun.write(`${OUTPUT_DIR}/contracts.ts`, contractsContent)
  console.log('  Generated contracts map')
}

async function generateEvents(): Promise<void> {
  console.log('Parsing Solidity for event definitions...')

  const contractEvents = await parseEventsFromSolidity()
  const code = generateEventParamsCode(contractEvents)

  await Bun.write(`${OUTPUT_DIR}/events.ts`, code)

  let totalEvents = 0
  let unknownCount = 0
  for (const [contractName, events] of contractEvents) {
    for (const event of events) {
      totalEvents++
      const unknowns = event.params.filter(p => p.type === 'unknown').length
      if (unknowns > 0) {
        console.warn(`    Warning: ${contractName}.${event.name} has ${unknowns} unknown param type(s)`)
        unknownCount += unknowns
      }
    }
  }

  console.log(`  Generated ${totalEvents} event definitions across ${contractEvents.size} contracts`)
  if (unknownCount > 0) {
    console.warn(`  Total unknown types: ${unknownCount} (may need manual fixes)`)
  }
}

async function generateIndex(): Promise<void> {
  const indexContent = `// This file is auto-generated. Do not edit manually.

export * from './contracts.js'
export * from './events.js'
export * from './errors.js'
`
  await Bun.write(`${OUTPUT_DIR}/index.ts`, indexContent)
}

async function generateGmx(): Promise<void> {
  console.log('Generating GMX contracts and data...')

  // Ensure GMX output directories exist
  await Bun.$`mkdir -p ${OUTPUT_DIR}/gmx/abi`

  // Run GMX generation scripts
  await Bun.$`bun run script/generate-gmx-contract-list.ts`
  await Bun.$`bun run script/generate-gmx-market-list.ts`
  await Bun.$`bun run script/generate-gmx-token-list.ts`
}

async function generateGmxIndex(): Promise<void> {
  const gmxIndexContent = `// This file is auto-generated. Do not edit manually.

export * from './gmxContracts.js'
export * from './marketList.js'
export * from './tokenList.js'
export { gmxErrorAbi } from './abi/gmxErrors.js'
`
  await Bun.write(`${OUTPUT_DIR}/gmx/index.ts`, gmxIndexContent)
}

async function formatGeneratedFiles(): Promise<void> {
  console.log('Formatting generated files...')
  await Bun.$`bunx @biomejs/biome check --fix --unsafe ${OUTPUT_DIR}`
}

async function main(): Promise<void> {
  console.log('=== Puppet Contracts TypeScript Generator ===\n')

  // Ensure output directories exist
  await Bun.$`mkdir -p ${OUTPUT_DIR}/abi`

  await generateContracts()
  await generateErrorAbi()
  await generateEvents()
  await generateIndex()

  const skipGmx =
    Bun.env.SKIP_GMX === '1' ||
    Bun.env.SKIP_GMX === 'true' ||
    Bun.env.SKIP_NETWORK === '1' ||
    Bun.env.SKIP_NETWORK === 'true'
  if (!skipGmx) {
    await generateGmx()
    await generateGmxIndex()
  }

  const skipFormat = Bun.env.SKIP_FORMAT === '1' || Bun.env.SKIP_FORMAT === 'true'
  if (!skipFormat) {
    await formatGeneratedFiles()
  }

  console.log('\n=== Generation complete ===')
  console.log(`Output: ${OUTPUT_DIR}/`)
}

main().catch(error => {
  console.error('Generation failed:', error)
  process.exit(1)
})
