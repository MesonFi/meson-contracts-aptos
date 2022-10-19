const dotenv = require('dotenv')
const fs = require('fs')
const path = require('path')
const { AptosClient } = require('aptos')
const { adaptor } = require('@mesonfi/sdk')
const { Meson } = require('@mesonfi/contract-abis')

dotenv.config()

const {
  APTOS_NODE_URL,
  APTOS_PRIVATE_KEY,
} = process.env

register()

async function register() {
  if (!APTOS_PRIVATE_KEY) {
    throw new Error('Please set APTOS_PRIVATE_KEY in .env')
  }

  const configYaml = fs.readFileSync(path.join(__dirname, '../.aptos/config.yaml'))
  const match = /account: (.*)\s/.exec(configYaml)
  if (!match) {
    throw new Error('Failed to parse config.yaml')
  }
  const address = `0x${match[1]}`

  const client = new AptosClient(APTOS_NODE_URL)
  const wallet = adaptor.getWallet(APTOS_PRIVATE_KEY, client)
  const meson = adaptor.getContract(address, Meson.abi, wallet)


  const { tokens: coins } = await meson.getSupportedTokens() // Named consistently with solidity contracts
  for (const coin of coins) {
    const tx = await wallet.sendTransaction({
      function: '0x1::managed_coin::register',
      type_arguments: [coin],
      arguments: []
    })
    console.log(`Register coin (${coin.split('::')[1]}): ${tx.hash}`)
    await tx.wait()
  }
}
