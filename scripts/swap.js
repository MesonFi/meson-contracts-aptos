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
const { ERC20, Meson } = require('@mesonfi/contract-abis')

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
  const lp = adaptor.getWallet(APTOS_LP_PRIVATE_KEY, client)
  const meson = adaptor.getContract(address, Meson.abi, lp)
  const { tokens: coins } = await meson.getSupportedTokens()

  const lpAddress = lp.address
  console.log(`LP address: ${lpAddress}`)
  await logWalletInfo(lp, coins, meson)

  const userAddress = user.address
  console.log(`User address: ${userAddress}`)
  await logWalletInfo(user, coins)

  // Aptos private key can be used as an Ethereum private key
  const mesonClient = await MesonClient.Create(meson)
  const swapSigner = new EthersWalletSwapSigner(new Wallet(APTOS_PRIVATE_KEY))
  const mesonClientForUser = await MesonClient.Create(meson.connect(user), swapSigner)


  const swapData = {
    amount: '10000000',
    fee: '1000',
    inToken: 1,
    outToken: 2,
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
  await logPoolBalance(lp, coins[1], meson)


  const release = await swap.signForRelease(userAddress, true)
  const signedRelease = new SignedSwapRelease(release)

  const tx2 = await mesonClient.release(signedRelease)
  console.log(`Released: \t${tx2.hash}`)
  await tx2.wait()
  await logCoinBalance(user, coins[1])


  const swapData2 = {
    amount: '5000000',
    fee: '0',
    inToken: 1,
    outToken: 2,
    recipient: userAddress,
    salt: '0x80'
  }
  const swap2 = mesonClientForUser.requestSwap(swapData2, aptosShortCoinType)
  const request2 = await swap2.signForRequest(true)
  const signedRequest2 = new SignedSwapRequest(request2)

  const tx3 = await mesonClientForUser.postSwap(signedRequest2, 1)
  console.log(`Posted: \t${tx3.hash}`)
  await tx3.wait()
  await logCoinBalance(user, coins[0])


  const release2 = await swap2.signForRelease(userAddress, true)
  const signedRelease2 = new SignedSwapRelease(release2)

  const tx4 = await mesonClient.executeSwap(signedRelease2, true)
  console.log(`Executed: \t${tx4.hash}`)
  await tx4.wait()
  await logPoolBalance(lp, coins[0], meson)
}


async function logWalletInfo(wallet, coins, meson) {
  console.log(`  Balance: ${utils.formatUnits(await wallet.getBalance(wallet.address), 8)} APT`)
  for (let i = 0; i < coins.length; i++) {
    await logCoinBalance(wallet, coins[i])
  }
  if (meson) {
    for (let i = 0; i < coins.length; i++) {
      await logPoolBalance(wallet, coins[i], meson)
    }
  }
}

async function logCoinBalance(wallet, coin) {
  const coinContract = adaptor.getContract(coin, ERC20.abi, wallet)
  const decimals = await coinContract.decimals()
  const balance = await coinContract.balanceOf(wallet.address)
  console.log(`  Coin: ${utils.formatUnits(balance, decimals)} ${coin.split('::')[2]}`)
}

async function logPoolBalance(wallet, coin, meson) {
  const balance = await meson.poolTokenBalance(coin, wallet.address)
  console.log(`  Pool: ${utils.formatUnits(balance, 6)} ${coin.split('::')[2]}`)
}