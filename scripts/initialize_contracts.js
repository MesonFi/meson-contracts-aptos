const dotenv = require('dotenv')
const fs = require('fs')
const path = require('path')
const { AptosClient } = require('aptos')
const { adaptor } = require('@mesonfi/sdk')
const { testnets } = require('@mesonfi/presets')

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
  const wallet = adaptor.getWallet(privateKey, client)

  if (address !== await wallet.getAddress()) {
    throw new Error('Address and private key in config.yaml do not match')
  }

  const tx = await wallet.sendTransaction({
    function: `${address}::MesonStates::initialize`,
    type_arguments: [],
    arguments: []
  })
  console.log(`initialize: ${tx.hash}`)
  await tx.wait()

  const coins = testnets.find(n => n.id.startsWith('aptos')).tokens
  for (const coin of coins) {
    const tx = await wallet.sendTransaction({
      function: `${address}::MesonStates::addSupportToken`,
      type_arguments: [coin.addr],
      arguments: [coin.tokenIndex]
    })
    console.log(`addSupportToken (${coin.addr.split('::')[1]}): ${tx.hash}`)
    await tx.wait()
  }

  if (APTOS_LP_PRIVATE_KEY && AMOUNT_TO_DEPOSIT) {
    const lp = adaptor.getWallet(APTOS_LP_PRIVATE_KEY, client)
    let registered = false
    for (const coin of coins) {
      const func = registered ? 'deposit' : 'depositAndRegister'
      const arguments = [BigInt(AMOUNT_TO_DEPOSIT)]
      if (!registered) {
        arguments.push(1)
      }
      const tx = await lp.sendTransaction({
        function: `${address}::MesonPools::${func}`,
        type_arguments: [coin.addr],
        arguments
      })
      console.log(`${func} (${coin.addr.split('::')[1]}): ${tx.hash}`)
      await tx.wait()
      registered = true
    }
  }
}