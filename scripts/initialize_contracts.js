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
  const { tokens } = await meson.getSupportedTokens()

  for (const module of ['MesonPools', 'MesonSwap', 'MesonStates']) {
    for (const token of tokens) {
      const tx = await wallet.sendTransaction({
        function: `${address}::${module}::initializeTable`,
        type_arguments: [token],
        arguments: []
      })
      console.log(`${module}::initializeTable (${token.split('::')[1]}): ${tx.hash}`)
      await tx.wait()
    }
  }

  if (APTOS_LP_PRIVATE_KEY && AMOUNT_TO_DEPOSIT) {
    const lp = adaptor.getWallet(APTOS_LP_PRIVATE_KEY, client)
    for (const token of tokens) {
      const tx = await lp.sendTransaction({
        function: `${address}::MesonPools::depositAndRegister`,
        type_arguments: [token],
        arguments: [BigInt(AMOUNT_TO_DEPOSIT)]
      })
      console.log(`depositAndRegister (${token.split('::')[1]}): ${tx.hash}`)
      await tx.wait()
    }
  }
}