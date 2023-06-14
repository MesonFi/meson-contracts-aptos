const dotenv = require('dotenv')
const fs = require('fs')
const path = require('path')
const { AptosClient, FaucetClient } = require('aptos')
const { utils } = require('ethers')
const { adaptors } = require('@mesonfi/sdk')

dotenv.config()

const {
  APTOS_NODE_URL,
  APTOS_FAUCET_URL,
} = process.env

prepare(process.env.PRIVATE_KEY)

async function prepare(privateKey) {
  const client = new AptosClient(APTOS_NODE_URL)
  const wallet = adaptors.getWallet(privateKey, client)

  const key = wallet.account.toPrivateKeyObject()
  console.log(`Address created: ${key.address}`)

  if (APTOS_FAUCET_URL) {
    const faucetClient = new FaucetClient(APTOS_NODE_URL, APTOS_FAUCET_URL)
    await faucetClient.fundAccount(wallet.address, 1 * 1e8)
  }

  const balance = await wallet.getBalance(wallet.address)
  console.log(`Balance: ${utils.formatUnits(balance, 8)} APT`)

  const configYaml = `---
profiles:
  default:
    private_key: "${key.privateKeyHex}"
    public_key: "${key.publicKeyHex}"
    account: ${key.address.substring(2)}
    rest_url: "${APTOS_NODE_URL}/v1"
`
  const aptosConfigDir = path.join(__dirname, '../.aptos')
  if (!fs.existsSync(aptosConfigDir)){
    fs.mkdirSync(aptosConfigDir)
  }
  fs.writeFileSync(path.join(aptosConfigDir, 'config.yaml'), configYaml)

  const moveTomlFile = path.join(__dirname, '../Move.toml')
  const moveToml = fs.readFileSync(moveTomlFile, 'utf8')
  const newMoveToml = moveToml.replace(/(?<=Meson = ")0x.*(?=")/, key.address)
  fs.writeFileSync(moveTomlFile, newMoveToml)
}
