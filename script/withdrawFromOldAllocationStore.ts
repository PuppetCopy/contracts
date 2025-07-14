#!/usr/bin/env bun
import { CONTRACT } from '@puppet-copy/middleware/const'
import { createPublicClient, createWalletClient, erc20Abi, http, parseAbi } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { arbitrum } from 'viem/chains'

// Configuration
const DEPLOYER_PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY
if (!DEPLOYER_PRIVATE_KEY) {
  throw new Error('DEPLOYER_PRIVATE_KEY not found in environment')
}

const account = privateKeyToAccount(DEPLOYER_PRIVATE_KEY as `0x${string}`)

// Contract addresses
const OLD_ALLOCATION_STORE = '0xD737388C88b1d0bfA56c0753476B0d2Aa755C6A1'
const USDC_ADDRESS = '0xaf88d065e77c8cC2239327C5EDb3A432268e5831' // USDC on Arbitrum

const allocationStoreAbi = parseAbi([
  'function transferOut(address token, address receiver, uint256 value) external',
  'function syncTokenBalance(address token) external',
  'function getTokenBalance(address token) view returns (uint256)',
  'function authority() view returns (address)'
])

// Create clients
const publicClient = createPublicClient({
  chain: arbitrum,
  transport: http(process.env.RPC_URL)
})

const walletClient = createWalletClient({
  account,
  chain: arbitrum,
  transport: http(process.env.RPC_URL)
})

async function main() {
  console.log('🚀 Starting USDC withdrawal from old AllocationStore...')
  console.log(`📍 Old AllocationStore: ${OLD_ALLOCATION_STORE}`)
  console.log(`💰 USDC Address: ${USDC_ADDRESS}`)
  console.log(`👤 Deployer: ${account.address}`)

  try {
    // Step 0: Get the authority address
    console.log('\n🔍 Step 0: Getting authority address...')
    const authorityAddress = await publicClient.readContract({
      address: OLD_ALLOCATION_STORE,
      abi: allocationStoreAbi,
      functionName: 'authority'
    })
    console.log(`🏛️ Authority: ${authorityAddress}`)

    // Step 1: Grant access to deployer
    console.log('\n📝 Step 1: Granting access to deployer...')

    const { request: accessRequest } = await publicClient.simulateContract({
      abi: CONTRACT.Dictatorship.abi,
      address: authorityAddress,
      functionName: 'setAccess',
      args: [OLD_ALLOCATION_STORE, account.address],
      account
    })

    const accessHash = await walletClient.writeContract(accessRequest)
    console.log(`✅ Access granted: ${accessHash}`)

    // Wait for transaction
    await publicClient.waitForTransactionReceipt({ hash: accessHash })

    // Step 2: Check USDC balance
    console.log('\n💰 Step 2: Checking USDC balance...')

    const balance = await publicClient.readContract({
      address: USDC_ADDRESS,
      abi: erc20Abi,
      functionName: 'balanceOf',
      args: [OLD_ALLOCATION_STORE]
    })

    const decimals = await publicClient.readContract({
      address: USDC_ADDRESS,
      abi: erc20Abi,
      functionName: 'decimals'
    })

    const usdcAmount = Number(balance) / 10 ** Number(decimals)
    console.log(`💰 Actual USDC Balance: ${usdcAmount}`)

    if (balance === 0n) {
      console.log('ℹ️  No USDC to withdraw')
      return
    }

    // Step 3: Transfer out USDC
    console.log('\n💸 Step 3: Transferring out USDC...')

    // Skip simulation and send directly
    const transferHash = await walletClient.writeContract({
      address: OLD_ALLOCATION_STORE,
      abi: allocationStoreAbi,
      functionName: 'transferOut',
      args: [USDC_ADDRESS, account.address, balance], // gasLimit, token, receiver, value
      account
    })
    console.log(`✅ Transfer initiated: ${transferHash}`)

    // Wait for transaction
    const receipt = await publicClient.waitForTransactionReceipt({ hash: transferHash })

    if (receipt.status === 'success') {
      console.log('\n🎉 USDC successfully withdrawn from old AllocationStore!')
      console.log(`📊 Transaction: https://arbiscan.io/tx/${transferHash}`)
    } else {
      console.error('❌ Transfer failed')
    }
  } catch (error) {
    console.error('❌ Error:', error)
    process.exit(1)
  }
}

main().catch(console.error)
