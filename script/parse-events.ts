#!/usr/bin/env bun
import { Glob } from 'bun'
import { basename } from 'path'
import { keccak256, parseAbiParameters, toHex } from 'viem'

const SRC_PATH = './src'

interface StructDefinition {
  name: string
  fields: Array<{ type: string; name: string }>
}

interface EventParam {
  type: string
  name: string
}

interface EventDefinition {
  name: string
  params: EventParam[]
  contractName: string
  sourceFile: string
}

type TypeMap = Record<string, string>

// Map Solidity contract names to deployment names (for CONTRACT_EVENT_MAP keys)
// Currently no mappings needed - use Solidity contract names directly
const CONTRACT_NAME_MAP: Record<string, string> = {}

const SOLIDITY_TO_ABI_TYPE: TypeMap = {
  uint: 'uint256',
  uint8: 'uint8',
  uint16: 'uint16',
  uint32: 'uint32',
  uint64: 'uint64',
  uint128: 'uint128',
  uint256: 'uint256',
  int: 'int256',
  int8: 'int8',
  int16: 'int16',
  int32: 'int32',
  int64: 'int64',
  int128: 'int128',
  int256: 'int256',
  address: 'address',
  bool: 'bool',
  bytes: 'bytes',
  bytes32: 'bytes32',
  bytes4: 'bytes4',
  string: 'string'
}

const SPECIAL_VARS: TypeMap = {
  'msg.value': 'uint256',
  'msg.sender': 'address',
  'block.timestamp': 'uint256',
  'block.number': 'uint256'
}

const LITERAL_PATTERNS: Array<{ pattern: RegExp; type: string }> = [
  { pattern: /^0$/, type: 'uint256' },
  { pattern: /^\d+$/, type: 'uint256' },
  { pattern: /^true$/, type: 'bool' },
  { pattern: /^false$/, type: 'bool' },
  { pattern: /^0x[a-fA-F0-9]{64}$/, type: 'bytes32' },
  { pattern: /^bytes32\(0\)$/, type: 'bytes32' },
  { pattern: /^address\(0\)$/, type: 'address' }
]

async function getAllSolFiles(dir: string): Promise<string[]> {
  const glob = new Glob('**/*.sol')
  const files: string[] = []

  for await (const file of glob.scan({ cwd: dir, absolute: true })) {
    if (!file.includes('/interface/') && !file.includes('/test/')) {
      files.push(file)
    }
  }

  return files
}

function parseStructs(content: string): Map<string, StructDefinition> {
  const structs = new Map<string, StructDefinition>()
  const structRegex = /struct\s+(\w+)\s*\{([^}]+)\}/g
  let match: RegExpExecArray | null

  while ((match = structRegex.exec(content)) !== null) {
    const structName = match[1]!
    const body = match[2]!
    const fields: Array<{ type: string; name: string }> = []

    const fieldRegex = /(\w+(?:\[\])?)\s+(\w+)\s*;/g
    let fieldMatch: RegExpExecArray | null

    while ((fieldMatch = fieldRegex.exec(body)) !== null) {
      fields.push({
        type: fieldMatch[1]!,
        name: fieldMatch[2]!
      })
    }

    structs.set(structName, { name: structName, fields })
  }

  return structs
}

function parseFunctionSignatures(content: string): Map<string, TypeMap> {
  const functionParams = new Map<string, TypeMap>()

  const multilineFuncRegex = /function\s+(\w+)\s*\(([\s\S]*?)\)\s*[^{]*?(?:returns\s*\(([\s\S]*?)\))?\s*\{/g
  let match: RegExpExecArray | null

  while ((match = multilineFuncRegex.exec(content)) !== null) {
    const funcName = match[1]!
    const params = match[2]!.replace(/\s+/g, ' ').trim()
    const returnParams = match[3]?.replace(/\s+/g, ' ').trim()
    const paramMap: TypeMap = {}

    if (params) {
      const paramParts = params.split(',')
      for (const part of paramParts) {
        const trimmed = part.trim()
        const paramMatch = trimmed.match(/^(\w+(?:\[\])?)\s+(?:memory\s+|calldata\s+|storage\s+)?(\w+)$/)
        if (paramMatch) {
          paramMap[paramMatch[2]!] = paramMatch[1]!
        }
      }
    }

    if (returnParams) {
      const returnParts = returnParams.split(',')
      for (const part of returnParts) {
        const trimmed = part.trim()
        const returnMatch = trimmed.match(/^(\w+(?:\[\])?)\s+(?:memory\s+)?(\w+)$/)
        if (returnMatch) {
          paramMap[returnMatch[2]!] = returnMatch[1]!
        }
      }
    }

    functionParams.set(funcName, paramMap)
  }

  return functionParams
}

function parseLocalVariables(functionBody: string): TypeMap {
  const vars: TypeMap = {}

  const patterns = [/(\w+(?:\[\])?)\s+(?:memory\s+|storage\s+|calldata\s+)?(\w+)\s*=/g, /(\w+(?:\[\])?)\s+(\w+)\s*;/g]

  for (const pattern of patterns) {
    let match: RegExpExecArray | null
    while ((match = pattern.exec(functionBody)) !== null) {
      const type = match[1]!
      const name = match[2]!
      if (!type.match(/^(if|for|while|return|require|emit|delete|memory|storage|calldata)$/)) {
        vars[name] = type
      }
    }
  }

  return vars
}

function parseMappingDeclarations(content: string): TypeMap {
  const mappings: TypeMap = {}

  const mappingRegex = /mapping\s*\([^)]+\s*=>\s*(\w+(?:\[\])?)\)\s*(?:public\s+)?(\w+)/g
  let match: RegExpExecArray | null

  while ((match = mappingRegex.exec(content)) !== null) {
    const valueType = match[1]!
    const name = match[2]!
    mappings[name] = valueType
  }

  return mappings
}

function convertSolidityTypeToAbi(solType: string, structs: Map<string, StructDefinition>): string {
  const isArray = solType.endsWith('[]')
  const baseType = isArray ? solType.slice(0, -2) : solType

  if (SOLIDITY_TO_ABI_TYPE[baseType]) {
    return isArray ? `${SOLIDITY_TO_ABI_TYPE[baseType]}[]` : SOLIDITY_TO_ABI_TYPE[baseType]
  }

  if (
    baseType === 'IERC20' ||
    (baseType.startsWith('I') && baseType.length > 1 && baseType[1] === baseType[1]!.toUpperCase())
  ) {
    return isArray ? 'address[]' : 'address'
  }

  const structDef = structs.get(baseType)
  if (structDef) {
    const tupleTypes = structDef.fields.map(f => convertSolidityTypeToAbi(f.type, structs))
    const tuple = `(${tupleTypes.join(', ')})`
    return isArray ? `${tuple}[]` : tuple
  }

  if (baseType.endsWith('Router') || baseType.endsWith('Store') || baseType.endsWith('Contract')) {
    return isArray ? 'address[]' : 'address'
  }

  return isArray ? `${baseType}[]` : baseType
}

function resolveType(
  varName: string,
  structs: Map<string, StructDefinition>,
  functionParams: TypeMap,
  localVars: TypeMap
): string {
  if (SPECIAL_VARS[varName]) {
    return SPECIAL_VARS[varName]!
  }

  for (const { pattern, type } of LITERAL_PATTERNS) {
    if (pattern.test(varName)) {
      return type
    }
  }

  const memberMatch = varName.match(/^(\w+)\.(\w+)$/)
  if (memberMatch) {
    const [, structVar, fieldName] = memberMatch
    const structTypeName = functionParams[structVar!] || localVars[structVar!]
    if (structTypeName) {
      const structDef = structs.get(structTypeName)
      if (structDef) {
        const field = structDef.fields.find(f => f.name === fieldName)
        if (field) {
          return convertSolidityTypeToAbi(field.type, structs)
        }
      }
    }
  }

  let solType = functionParams[varName] || localVars[varName]

  if (!solType && varName.startsWith('_')) {
    const withoutUnderscore = varName.slice(1)
    solType = functionParams[withoutUnderscore] || localVars[withoutUnderscore]
  }

  if (!solType) {
    return 'unknown'
  }

  return convertSolidityTypeToAbi(solType, structs)
}

function extractLogEventCalls(content: string): Array<{ eventName: string; encodeArgs: string; lineNumber: number }> {
  const events: Array<{ eventName: string; encodeArgs: string; lineNumber: number }> = []

  const normalized = content.replace(/\r\n/g, '\n')

  const logEventRegex = /_logEvent\s*\(\s*"(\w+)"\s*,\s*abi\.encode\s*\(/g
  let match: RegExpExecArray | null

  while ((match = logEventRegex.exec(normalized)) !== null) {
    const eventName = match[1]!
    const startIdx = match.index + match[0].length
    const lineNumber = normalized.slice(0, match.index).split('\n').length

    let depth = 1
    let endIdx = startIdx

    for (let i = startIdx; i < normalized.length && depth > 0; i++) {
      if (normalized[i] === '(') depth++
      if (normalized[i] === ')') depth--
      endIdx = i
    }

    let encodeArgs = normalized.slice(startIdx, endIdx).trim()
    encodeArgs = encodeArgs.replace(/\/\/[^\n]*/g, '').replace(/\/\*[\s\S]*?\*\//g, '')
    encodeArgs = encodeArgs.replace(/\s+/g, ' ').trim()

    events.push({ eventName, encodeArgs, lineNumber })
  }

  return events
}

function parseEncodeArgs(encodeArgs: string): string[] {
  const args: string[] = []
  let current = ''
  let depth = 0

  for (const char of encodeArgs) {
    if (char === '(' || char === '[') {
      depth++
      current += char
    } else if (char === ')' || char === ']') {
      depth--
      current += char
    } else if (char === ',' && depth === 0) {
      const trimmed = current.trim()
      if (trimmed) args.push(trimmed)
      current = ''
    } else {
      current += char
    }
  }

  const trimmed = current.trim()
  if (trimmed) args.push(trimmed)

  return args
}

function extractVariableName(arg: string): string {
  const memberAccess = arg.match(/^(\w+)\.\w+$/)
  if (memberAccess) return arg

  const arrayIndex = arg.match(/^(\w+)\[\d+\]$/)
  if (arrayIndex) return arrayIndex[1]!

  const mappingAccess = arg.match(/^(\w+)\[.+\]$/)
  if (mappingAccess) return mappingAccess[1]!

  const simple = arg.match(/^_?\w+$/)
  if (simple) return arg

  return arg
}

const SOLIDITY_KEYWORDS = new Set([
  'true',
  'false',
  'null',
  'address',
  'bool',
  'string',
  'bytes',
  'uint',
  'int',
  'uint8',
  'uint16',
  'uint32',
  'uint64',
  'uint128',
  'uint256',
  'int8',
  'int16',
  'int32',
  'int64',
  'int128',
  'int256',
  'bytes1',
  'bytes2',
  'bytes4',
  'bytes8',
  'bytes16',
  'bytes32',
  'if',
  'else',
  'for',
  'while',
  'do',
  'break',
  'continue',
  'return',
  'function',
  'modifier',
  'event',
  'struct',
  'enum',
  'mapping',
  'public',
  'private',
  'internal',
  'external',
  'pure',
  'view',
  'payable',
  'memory',
  'storage',
  'calldata',
  'constant',
  'immutable',
  'contract',
  'interface',
  'library',
  'abstract',
  'virtual',
  'override',
  'constructor',
  'receive',
  'fallback',
  'error',
  'revert',
  'require',
  'assert'
])

function extractParamName(arg: string): string {
  let name: string

  // Member access: "foo.bar" -> "bar"
  const memberAccess = arg.match(/^(\w+)\.(\w+)$/)
  if (memberAccess) {
    name = memberAccess[2]!
  }
  // Array index: "foo[0]" -> "foo"
  else if (arg.match(/^(\w+)\[\d+\]$/)) {
    name = arg.match(/^(\w+)\[\d+\]$/)[1]!
  }
  // Mapping access: "foo[key]" -> "foo"
  else if (arg.match(/^(\w+)\[.+\]$/)) {
    name = arg.match(/^(\w+)\[.+\]$/)[1]!
  }
  // Simple variable, strip leading underscore: "_foo" -> "foo"
  else if (arg.match(/^_?(\w+)$/)) {
    name = arg.match(/^_?(\w+)$/)[1]!
  }
  // Special vars
  else if (arg === 'msg.sender') {
    name = 'sender'
  } else if (arg === 'msg.value') {
    name = 'msgValue'
  } else if (arg === 'block.timestamp') {
    name = 'timestamp'
  } else if (arg === 'block.number') {
    name = 'blockNumber'
  }
  // Literals - give generic names
  else if (/^\d+$/.test(arg)) {
    name = 'amount'
  } else if (arg === 'true' || arg === 'false') {
    name = 'flag'
  } else if (/^0x[a-fA-F0-9]+$/.test(arg)) {
    name = 'data'
  } else if (/^bytes32\(0\)$/.test(arg)) {
    name = 'data'
  } else if (/^address\(0\)$/.test(arg)) {
    name = 'addr'
  } else {
    name = 'param'
  }

  // Ensure name is not a Solidity keyword
  if (SOLIDITY_KEYWORDS.has(name)) {
    name = `${name}Value`
  }

  // Ensure name doesn't start with a number
  if (/^\d/.test(name)) {
    name = `param${name}`
  }

  return name
}

function getFunctionContaining(content: string, lineNumber: number): string | null {
  const lines = content.split('\n')
  let braceDepth = 0
  let funcStart = -1

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]!

    if (funcStart === -1 && line.match(/function\s+\w+/)) {
      funcStart = i
    }

    for (const char of line) {
      if (char === '{') braceDepth++
      if (char === '}') {
        braceDepth--
        if (braceDepth === 0 && funcStart !== -1) {
          if (lineNumber >= funcStart && lineNumber <= i) {
            return lines.slice(funcStart, i + 1).join('\n')
          }
          funcStart = -1
        }
      }
    }
  }

  return null
}

function extractContractName(content: string): string | null {
  // Match "contract ContractName is ..." or "contract ContractName {"
  const match = content.match(/\bcontract\s+(\w+)\s*(?:is|{)/)
  return match ? match[1]! : null
}

// Returns Map<contractName, EventDefinition[]>
export async function parseEventsFromSolidity(): Promise<Map<string, EventDefinition[]>> {
  const contractEvents = new Map<string, EventDefinition[]>()
  const allStructs = new Map<string, StructDefinition>()

  const solFiles = await getAllSolFiles(SRC_PATH)

  for (const file of solFiles) {
    const content = await Bun.file(file).text()
    const fileStructs = parseStructs(content)

    for (const [name, struct] of fileStructs) {
      allStructs.set(name, struct)
    }
  }

  for (const file of solFiles) {
    const content = await Bun.file(file).text()
    const contractName = extractContractName(content)
    if (!contractName) continue

    const logEvents = extractLogEventCalls(content)
    const functionSignatures = parseFunctionSignatures(content)
    const mappings = parseMappingDeclarations(content)

    for (const { eventName, encodeArgs, lineNumber } of logEvents) {
      const args = parseEncodeArgs(encodeArgs)
      const funcBody = getFunctionContaining(content, lineNumber)
      const localVars = funcBody ? parseLocalVariables(funcBody) : {}

      let funcParamsForEvent: TypeMap = { ...mappings }
      for (const [, params] of functionSignatures) {
        funcParamsForEvent = { ...funcParamsForEvent, ...params }
      }

      const eventParams: EventParam[] = []
      const usedNames = new Set<string>()

      for (const arg of args) {
        const varName = extractVariableName(arg)
        const resolvedType = resolveType(varName, allStructs, funcParamsForEvent, localVars)
        let paramName = extractParamName(arg)

        // Ensure unique names by appending index if needed
        if (usedNames.has(paramName)) {
          let i = 2
          while (usedNames.has(`${paramName}${i}`)) i++
          paramName = `${paramName}${i}`
        }
        usedNames.add(paramName)

        eventParams.push({ type: resolvedType, name: paramName })
      }

      const eventDef: EventDefinition = {
        name: eventName,
        params: eventParams,
        contractName,
        sourceFile: basename(file)
      }

      const existingEvents = contractEvents.get(contractName) || []

      // Check for duplicate event name within same contract
      const existingIdx = existingEvents.findIndex(e => e.name === eventName)
      if (existingIdx !== -1) {
        // Keep the one with fewer unknowns
        const existing = existingEvents[existingIdx]!
        const existingUnknowns = existing.params.filter(p => p.type === 'unknown').length
        const newUnknowns = eventParams.filter(p => p.type === 'unknown').length
        if (newUnknowns < existingUnknowns) {
          existingEvents[existingIdx] = eventDef
        }
      } else {
        existingEvents.push(eventDef)
      }

      contractEvents.set(contractName, existingEvents)
    }
  }

  return contractEvents
}

export function generateEventParamsCode(contractEvents: Map<string, EventDefinition[]>): string {
  // Generate CONTRACT_EVENT_MAP organized by contract with hashes included
  const sortedContracts = Array.from(contractEvents.entries()).sort((a, b) => a[0].localeCompare(b[0]))

  const contractLines = sortedContracts
    .map(([solidityName, events]) => {
      // Use mapped name if available (e.g., Subscribe -> Rule)
      const contractName = CONTRACT_NAME_MAP[solidityName] || solidityName
      const sortedEvents = events.sort((a, b) => a.name.localeCompare(b.name))
      const eventLines = sortedEvents
        .map(event => {
          const hash = keccak256(toHex(event.name))
          const paramStr = event.params.map(p => `${p.type} ${p.name}`).join(', ')
          const parsed = parseAbiParameters(paramStr)
          const argsStr = JSON.stringify(parsed).replace(/"(\w+)":/g, '$1:')
          return `    ${event.name}: {\n      hash: '${hash}',\n      args: ${argsStr}\n    }`
        })
        .join(',\n')

      return `  ${contractName}: {\n${eventLines}\n  }`
    })
    .join(',\n')

  return `// This file is auto-generated from Solidity source files. Do not edit manually.
// Generated by: bun run script/parse-events.ts

export const CONTRACT_EVENT_MAP = {
${contractLines}
} as const
`
}

if (import.meta.main) {
  console.log('Parsing Solidity files for _logEvent calls...')

  const contractEvents = await parseEventsFromSolidity()

  let totalEvents = 0
  for (const [contractName, events] of contractEvents) {
    console.log(`\n${contractName}:`)
    for (const event of events) {
      const paramsStr = event.params.map(p => `${p.type} ${p.name}`).join(', ')
      console.log(`  ${event.name}: (${paramsStr})`)
      totalEvents++
    }
  }
  console.log(`\nTotal: ${totalEvents} events across ${contractEvents.size} contracts`)

  const code = generateEventParamsCode(contractEvents)

  // Write to file
  const outputPath = './script/generated/events.ts'
  await Bun.write(outputPath, code)
  console.log(`\nWritten to ${outputPath}`)
}
