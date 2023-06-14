const dotenv = require('dotenv')
const {
  adaptors,
  SignedSwapRequest,
  SignedSwapRelease,
  NonEcdsaRemoteSwapSigner,
} = require('@mesonfi/sdk')
const presets = require('@mesonfi/presets').default

dotenv.config()

const {
  TESTNET_MODE,
  PRIVATE_KEY,
  LP_PRIVATE_KEY,
} = process.env

const testnetMode = Boolean(TESTNET_MODE)
const networkId = testnetMode ? 'aptos-testnet' : 'aptos'
presets.useTestnet(testnetMode)

swap()

async function swap() {
  if (!PRIVATE_KEY) {
    throw new Error('Please set PRIVATE_KEY in .env')
  } else if (!LP_PRIVATE_KEY) {
    throw new Error('Please set LP_PRIVATE_KEY in .env')
  }

  const network = presets.getNetwork(networkId)
  const client = presets.createNetworkClient(networkId, [network.url])
  const wallet = adaptors.getWallet(PRIVATE_KEY, client)
  console.log(`Wallet address: ${wallet.address}`)
  const lp = adaptors.getWallet(LP_PRIVATE_KEY, client)
  console.log(`LP address: ${lp.address}`)

  const mesonClient = presets.createMesonClient(networkId, wallet)
  const signer = {
    getAddress: () => wallet.address,
    signMessage: async msg => wallet.signMessage(msg),
    signTypedData: async () => '0x',
  }
  const swapSigner = new NonEcdsaRemoteSwapSigner(signer)
  mesonClient.setSwapSigner(swapSigner)


  const swapData = {
    amount: '1000000',
    fee: '1000',
    inToken: 1,
    outToken: 2,
    recipient: wallet.address,
    salt: '0x80'
  }
  const swap = mesonClient.requestSwap(swapData, network.shortSlip44)
  const request = await swap.signForRequest(testnetMode)
  const signedRequest = new SignedSwapRequest(request)
  signedRequest.checkSignature(testnetMode)

  const release = await swap.signForRelease(swapData.recipient, testnetMode)
  const signedRelease = new SignedSwapRelease(release)
  signedRelease.checkSignature(testnetMode)


  // postSwap
  const postSwapTx = await mesonClient.postSwap(signedRequest, 1)
  console.log('postSwap', postSwapTx.hash)
  await postSwapTx.wait(1)

  mesonClient.switchWallet(lp)

  // lock
  const lockTx = await mesonClient.lock(signedRequest, swapData.recipient)
  console.log('lock', lockTx.hash)
  await lockTx.wait()

  // release
  const releaseTx = await mesonClient.release(signedRelease)
  console.log('release', releaseTx.hash)

  // executeSwap
  const executeTx = await mesonClient.executeSwap(signedRelease, true)
  console.log('execute', executeTx.hash)
}
