const dotenv = require('dotenv')
const { adaptors } = require('@mesonfi/sdk')
const presets = require('@mesonfi/presets').default

dotenv.config()

const {
  TESTNET_MODE,
} = process.env

const testnetMode = Boolean(TESTNET_MODE)
const networkId = testnetMode ? 'aptos-testnet' : 'aptos'
presets.useTestnet(testnetMode)

register(process.env.PRIVATE_KEY)

async function register(privateKey) {
  const network = presets.getNetwork(networkId)
  const client = presets.createNetworkClient(networkId, [network.url])
  const wallet = adaptors.getWallet(privateKey, client)
  console.log(wallet.address)

  for (const coin of network.tokens) {
    console.log(`Registering ${coin.addr}...`)
    const tx = await wallet.sendTransaction({
      function: '0x1::managed_coin::register',
      type_arguments: [coin.addr],
      arguments: []
    })
    await tx.wait()
  }
}
