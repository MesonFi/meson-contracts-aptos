const dotenv = require('dotenv')
const fs = require('fs')
const path = require('path')
const { AptosClient } = require('aptos')
const { Wallet, utils } = require('ethers')

const {
  adaptor,
  MesonClient,
  EthersWalletSwapSigner,
  SignedSwapRequest,
  SignedSwapRelease,
} = require('@mesonfi/sdk')
const { Meson } = require('@mesonfi/contract-abis')

dotenv.config()

const {
  APTOS_NODE_URL,
  APTOS_PRIVATE_KEY,
  APTOS_LP_PRIVATE_KEY,
} = process.env

swap()

async function swap() {
  if (!APTOS_LP_PRIVATE_KEY) {
    throw new Error('Please set APTOS_LP_PRIVATE_KEY in .env')
  } else if (!APTOS_LP_PRIVATE_KEY) {
    throw new Error('Please set APTOS_LP_PRIVATE_KEY in .env')
  }

  const configYaml = fs.readFileSync(path.join(__dirname, '../.aptos/config.yaml'))
  const match = /account: (.*)\s/.exec(configYaml)
  if (!match) {
    throw new Error('Failed to parse config.yaml')
  }
  const address = `0x${match[1]}`

  const client = new AptosClient(APTOS_NODE_URL)
  const user = adaptor.getWallet(APTOS_PRIVATE_KEY, client)
  const userAddress = await user.getAddress()
  console.log(`User address: ${userAddress}`)
  console.log(`Balance: ${utils.formatUnits(await user.getBalance(userAddress), 8)} APT`)

  const lp = adaptor.getWallet(APTOS_LP_PRIVATE_KEY, client)
  const lpAddress = await lp.getAddress()
  console.log(`LP address: ${lpAddress}`)
  console.log(`Balance: ${utils.formatUnits(await lp.getBalance(lpAddress), 8)} APT`)

  const meson = adaptor.getContract(address, Meson.abi, lp)

  // Aptos private key can be used as an Ethereum private key
  const mesonClient = await MesonClient.Create(meson)
  const swapSigner = new EthersWalletSwapSigner(new Wallet(APTOS_PRIVATE_KEY))
  const mesonClientForUser = await MesonClient.Create(meson.connect(user), swapSigner)


  const swapData = {
    amount: '1000000',
    fee: '1000',
    inToken: 1,
    outToken: 1,
    recipient: userAddress,
    salt: '0x80'
  }
  const aptosShortCoinType = await meson.getShortCoinType()
  const swap = mesonClientForUser.requestSwap(swapData, aptosShortCoinType)
  const request = await swap.signForRequest(true)
  const signedRequest = new SignedSwapRequest(request)

  const tx1 = await mesonClient.lock(signedRequest, userAddress)
  console.log(`Locked: \t${tx1.hash}`)
  await tx1.wait()

  const release = await swap.signForRelease(userAddress, true)
  const signedRelease = new SignedSwapRelease(release)

  const tx2 = await mesonClient.release(signedRelease)
  console.log(`Released: \t${tx2.hash}`)
  await tx2.wait()


  const swapData2 = {
    amount: '500000',
    fee: '0',
    inToken: 1,
    outToken: 1,
    recipient: userAddress,
    salt: '0x80'
  }
  const swap2 = mesonClientForUser.requestSwap(swapData2, aptosShortCoinType)
  const request2 = await swap2.signForRequest(true)
  const signedRequest2 = new SignedSwapRequest(request2)

  const tx3 = await mesonClientForUser.postSwap(signedRequest2, lpAddress)
  console.log(`Posted: \t${tx3.hash}`)
  await tx3.wait()

  const release2 = await swap2.signForRelease(userAddress, true)
  const signedRelease2 = new SignedSwapRelease(release2)

  const tx4 = await mesonClient.executeSwap(signedRelease2)
  console.log(`Executed: \t${tx4.hash}`)
  await tx4.wait()
}
