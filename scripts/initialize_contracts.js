const dotenv = require('dotenv')
const fs = require('fs')
const path = require('path')
const { AptosClient } = require('aptos')
const { adaptor } = require('@mesonfi/sdk')
const { Meson } = require('@mesonfi/contract-abis')

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

  const meson = adaptor.getContract(address, Meson.abi, wallet)
  const { tokens: coins } = await meson.getSupportedTokens() // Named consistently with solidity contracts
  
  const tx = await wallet.sendTransaction({
    function: `${address}::MesonStates::initialize`,
    type_arguments: [],
    arguments: []
  })
  console.log(`initialize: ${tx.hash}`)
  await tx.wait()

  for (const coin of coins) {
    const tx = await wallet.sendTransaction({
      function: `${address}::MesonStates::add_support_coin`,
      type_arguments: [coin],
      arguments: []
    })
    console.log(`add_support_coin (${coin.split('::')[1]}): ${tx.hash}`)
    await tx.wait()
  }

  if (APTOS_LP_PRIVATE_KEY && AMOUNT_TO_DEPOSIT) {
    const lp = adaptor.getWallet(APTOS_LP_PRIVATE_KEY, client)
    for (const coin of coins) {
      const tx = await lp.sendTransaction({
        function: `${address}::MesonPools::deposit_and_register`,
        type_arguments: [coin],
        arguments: [BigInt(AMOUNT_TO_DEPOSIT), 1]
      })
      console.log(`depositAndRegister (${coin.split('::')[1]}): ${tx.hash}`)
      await tx.wait()
    }
  }
}