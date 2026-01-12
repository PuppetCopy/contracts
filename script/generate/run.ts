#!/usr/bin/env bun
import { join } from 'path'
import { parse as parseToml } from 'smol-toml'
import { generateEventParamsCode, parseEventsFromSolidity } from './parse-events.js'

const FORGE_ARTIFACTS_PATH = './forge-artifacts'
const DEPLOYMENTS_PATH = './deployments.toml'
const BROADCAST_PATH = './broadcast'
const ERROR_SOL_PATH = './src/utils/Error.sol'
const OUTPUT_DIR = './src-ts'

// Chain alias to chain ID mapping (matches Alloy/Foundry)
const CHAIN_ID_MAP: Record<string, number> = {
  mainnet: 1,
  arbitrum: 42161,
  optimism: 10,
  base: 8453,
  sepolia: 11155111
}

type ContractInfo = {
  name: string
  address: string
  chainId?: number
  blockNumber?: number
  abi?: unknown[]
}

type BroadcastArtifact = {
  transactions: {
    hash: string
    transactionType: string
    contractName: string
    contractAddress: string
  }[]
  receipts: {
    transactionHash: string
    blockNumber: string
  }[]
}

async function loadBlockNumbersFromBroadcasts(chainId: number): Promise<Map<string, number>> {
  const blockNumbers = new Map<string, number>()

  // Scan all broadcast directories for this chain
  const broadcastGlob = new Bun.Glob(`*/${chainId}/run-latest.json`)

  for await (const file of broadcastGlob.scan({ cwd: BROADCAST_PATH })) {
    try {
      const broadcastFile = Bun.file(join(BROADCAST_PATH, file))
      const broadcast: BroadcastArtifact = await broadcastFile.json()

      // Build txHash -> blockNumber map from receipts
      const receiptMap = new Map<string, number>()
      for (const receipt of broadcast.receipts) {
        receiptMap.set(receipt.transactionHash, Number(receipt.blockNumber))
      }

      // Extract block numbers for CREATE transactions
      for (const tx of broadcast.transactions) {
        if (tx.transactionType === 'CREATE' && tx.contractAddress) {
          const blockNumber = receiptMap.get(tx.hash)
          if (blockNumber) {
            // Normalize address to lowercase for comparison
            blockNumbers.set(tx.contractAddress.toLowerCase(), blockNumber)
          }
        }
      }
    } catch {
      // Skip files that can't be parsed
    }
  }

  return blockNumbers
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

// Check if a contract name is a Puppet contract (PascalCase) vs external (lowercase/snake_case)
function isPuppetContract(name: string): boolean {
  return /^[A-Z]/.test(name)
}

async function generateContracts(): Promise<void> {
  console.log('Loading Puppet contract deployments from TOML...')

  const deploymentsFile = Bun.file(DEPLOYMENTS_PATH)
  const tomlContent = await deploymentsFile.text()
  const deployments = parseToml(tomlContent) as Record<string, Record<string, unknown>>

  const contracts: ContractInfo[] = []

  // Load universal contracts (same address all chains, via CREATE2) - no chainId
  const universalAddresses = (deployments.universal as Record<string, unknown>)?.address as
    | Record<string, string>
    | undefined

  if (universalAddresses) {
    for (const [name, address] of Object.entries(universalAddresses)) {
      if (address) {
        const abi = await findAbiFile(name)
        contracts.push({ name, address, abi })
      }
    }
    console.log(`  Found ${contracts.length} universal contracts`)
  }

  for (const chainAlias of Object.keys(deployments)) {
    // Skip non-chain keys
    if (chainAlias === 'universal') continue
    const chainData = deployments[chainAlias]
    if (!chainData || typeof chainData !== 'object') continue

    // Resolve chain ID from alias or numeric string
    const chainId = CHAIN_ID_MAP[chainAlias] ?? Number(chainAlias)
    if (Number.isNaN(chainId)) continue

    // Get address section
    const addresses = (chainData as Record<string, unknown>).address as Record<string, string> | undefined
    if (!addresses) continue

    // Load block numbers from broadcast files for this chain
    const blockNumbers = await loadBlockNumbersFromBroadcasts(chainId)

    // Extract chain-specific Puppet contracts (PascalCase names only, skip external like usdc, weth, gmx_*)
    const puppetContracts = Object.entries(addresses).filter(([name]) => isPuppetContract(name))
    console.log(`  Found ${puppetContracts.length} chain-specific contracts on ${chainAlias} (${chainId})`)

    for (const [name, address] of puppetContracts) {
      const isZeroAddress = address === '0x0000000000000000000000000000000000000000'
      const abi = await findAbiFile(name)

      // For zero addresses, include contract definition but without chainId/blockNumber
      if (isZeroAddress) {
        contracts.push({ name, address, abi })
      } else {
        const blockNumber = blockNumbers.get(address.toLowerCase())
        contracts.push({
          name,
          address,
          chainId,
          blockNumber,
          abi
        })
      }
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
  const contractsContent = `// This file is auto-generated from Puppet deployments.toml and forge-artifacts
// Do not edit manually.

${contracts
  .filter(c => c.abi)
  .map(c => `import ${c.name.toLowerCase()}Abi from './abi/puppet${c.name}.js'`)
  .join('\n')}

export const PUPPET_CONTRACT_MAP = {
${contracts
  .map(contract => {
    const hasChain = contract.chainId != null
    const hasBlock = contract.blockNumber != null
    const hasAbi = contract.abi != null
    const lines: string[] = [`    address: '${contract.address}'`]
    if (hasChain) lines.push(`    chainId: ${contract.chainId}`)
    if (hasBlock) lines.push(`    blockNumber: ${contract.blockNumber}`)
    if (hasAbi) lines.push(`    abi: ${contract.name.toLowerCase()}Abi`)
    return `  ${contract.name}: {\n${lines.join(',\n')}\n  }`
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
  await Bun.$`bun run script/generate/gmx-contract-list.ts`
  await Bun.$`bun run script/generate/gmx-market-list.ts`
  await Bun.$`bun run script/generate/gmx-token-list.ts`
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

async function cleanGeneratedFiles(): Promise<void> {
  console.log('Cleaning old generated files...')

  // Clean ABI files (except external ones we want to keep)
  const keepFiles = new Set(['erc20.ts', 'externalReferralStorage.ts'])
  const abiDir = `${OUTPUT_DIR}/abi`

  try {
    const files = await Array.fromAsync(new Bun.Glob('*.ts').scan({ cwd: abiDir }))
    for (const file of files) {
      if (!keepFiles.has(file)) {
        await Bun.$`rm -f ${abiDir}/${file}`
      }
    }
  } catch {
    // Directory may not exist yet
  }

  // Clean top-level generated files (but not gmx folder)
  const topLevelFiles = ['contracts.ts', 'contract.ts', 'events.ts', 'errors.ts', 'index.ts']
  for (const file of topLevelFiles) {
    await Bun.$`rm -f ${OUTPUT_DIR}/${file}`
  }
}

async function main(): Promise<void> {
  console.log('=== Puppet Contracts TypeScript Generator ===\n')

  // Clean old generated files
  await cleanGeneratedFiles()

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
    const gmxPath = './lib/gmx-synthetics'
    const gmxExists = await Bun.file(`${gmxPath}/deployments/arbitrum/Reader.json`)
      .exists()
      .catch(() => false)
    if (gmxExists) {
      await generateGmx()
      await generateGmxIndex()
    } else {
      console.log('Skipping GMX generation (gmx-synthetics lib not found)')
    }
  }

  console.log('\n=== Generation complete ===')
  console.log(`Output: ${OUTPUT_DIR}/`)
}

main().catch(error => {
  console.error('Generation failed:', error)
  process.exit(1)
})
