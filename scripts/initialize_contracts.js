const dotenv = require('dotenv')
const fs = require('fs')
const path = require('path')
const { AptosClient } = require('aptos')
const { adaptors } = require('@mesonfi/sdk')
const presets = require('@mesonfi/presets').default

dotenv.config()

const {
  APTOS_NODE_URL,
  APTOS_LP_PRIVATE_KEY,
  AMOUNT_TO_DEPOSIT,
} = process.env

initialize()

async function initialize() {
  const configYaml = fs.readFileSync(path.join(__dirname, '../.aptos/config.yaml'))
  const match = /private_key: "(.*)"[\s\S]*account: (.*)\s/.exec(configYaml)
  if (!match) {
    throw new Error('Failed to parse config.yaml')
  }
  const privateKey = match[1]
  const address = `0x${match[2]}`

  const client = new AptosClient(APTOS_NODE_URL)
  const wallet = adaptors.getWallet(privateKey, client)

  if (address !== wallet.address) {
    throw new Error('Address and private key in config.yaml do not match')
  }

  const coins = presets.getNetwork('aptos').tokens
  for (const coin of coins) {
    const tx = await wallet.sendTransaction({
      function: `${address}::MesonStates::addSupportToken`,
      type_arguments: [coin.addr],
      arguments: [coin.tokenIndex]
    })
    console.log(`addSupportToken (${coin.symbol}): ${tx.hash}`)
    await tx.wait()
  }

  if (!APTOS_LP_PRIVATE_KEY) {
    return
  }

  const lp = adaptors.getWallet(APTOS_LP_PRIVATE_KEY, client)
  const lpAddress = lp.address

  const tx = await wallet.sendTransaction({
    function: `${address}::MesonStates::transferPremiumManager`,
    type_arguments: [],
    arguments: [lpAddress],
  })
  console.log(`transferPremiumManager: ${tx.hash}`)
  await tx.wait()

  if (!AMOUNT_TO_DEPOSIT) {
    return
  }

  let registered = false
  for (const coin of coins) {
    const coinType = `${address}::Coins::${coin.symbol}`

    const tx1 = await lp.sendTransaction({
      function: `0x1::managed_coin::register`,
      type_arguments: [coinType],
      arguments: []
    })
    console.log(`register (${coin.symbol}): ${tx1.hash}`)
    await tx1.wait()

    const tx2 = await wallet.sendTransaction({
      function: `0x1::managed_coin::mint`,
      type_arguments: [coinType],
      arguments: [lpAddress, 1_000000_000000]
    })
    console.log(`mint (${coin.symbol}): ${tx2.hash}`)
    await tx2.wait()

    const func = registered ? 'deposit' : 'depositAndRegister'
    const tx3 = await lp.sendTransaction({
      function: `${address}::MesonPools::${func}`,
      type_arguments: [coinType],
      arguments: [BigInt(AMOUNT_TO_DEPOSIT), 1],
    })
    console.log(`${func} (${coin.symbol}): ${tx3.hash}`)
    await tx3.wait()
    registered = true
  }
}
