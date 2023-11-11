const dotenv = require('dotenv')
const { utils } = require('ethers')
const { adaptors } = require('@mesonfi/sdk')
const presets = require('@mesonfi/presets').default
const { Meson } = require('@mesonfi/contract-abis')

dotenv.config()

const {
  TESTNET_MODE,
  PRIVATE_KEY,
  LP_PRIVATE_KEY,
  AMOUNT_TO_DEPOSIT,
} = process.env

const testnetMode = Boolean(TESTNET_MODE)
const networkId = testnetMode ? 'aptos-testnet' : 'aptos'
presets.useTestnet(testnetMode)

initialize()

async function initialize() {
  const network = presets.getNetwork(networkId)
  const client = presets.createNetworkClient(networkId, [network.url])
  const wallet = adaptors.getWallet(PRIVATE_KEY, client)

  const mesonAddress = wallet.address
  console.log('Deployed to:', mesonAddress)
  let mesonInstance = adaptors.getContract(mesonAddress, Meson.abi, wallet)

  const coins = testnetMode
    ? [{ symbol: 'USDC', tokenIndex: 1 }, { symbol: 'USDT', tokenIndex: 2 }]
    : network.tokens

  for (const coin of coins) {
    if (testnetMode) {
      coin.addr = `${mesonAddress}::Coins::${coin.symbol}`
    }
    console.log(`addSupportToken (${coin.symbol})`)
    const tx = await mesonInstance.addSupportToken(coin.addr, coin.tokenIndex)
    await tx.wait()
  }

  if (!LP_PRIVATE_KEY) {
    return
  }

  const lp = adaptors.getWallet(LP_PRIVATE_KEY, client)

  console.log(`transferPremiumManager: ${lp.address}`)
  const tx = await wallet.sendTransaction({
    function: `${mesonAddress}::MesonStates::transferPremiumManager`,
    type_arguments: [],
    arguments: [lp.address],
  })
  await tx.wait()

  mesonInstance = mesonInstance.connect(lp)

  if (!AMOUNT_TO_DEPOSIT) {
    return
  }

  for (const coin of coins) {
    const value = utils.parseUnits(AMOUNT_TO_DEPOSIT, 6)

    console.log(`Registering ${coin.symbol}...`)
    const tx1 = await lp.sendTransaction({
      function: `0x1::managed_coin::register`,
      type_arguments: [coin.addr],
      arguments: []
    })
    await tx1.wait()

    console.log(`Minting ${AMOUNT_TO_DEPOSIT} ${coin.symbol}...`)
    const tx2 = await wallet.sendTransaction({
      function: `0x1::managed_coin::mint`,
      type_arguments: [coin.addr],
      arguments: [lp.address, value.toNumber()]
    })
    await tx2.wait()

    console.log(`Depositing ${AMOUNT_TO_DEPOSIT} ${coin.symbol}...`)
    const poolIndex = await mesonInstance.poolOfAuthorizedAddr(lp.address)
    const needRegister = poolIndex == 0
    const poolTokenIndex = coin.tokenIndex * 2**40 + (needRegister ? 1 : poolIndex)

    let tx
    if (needRegister) {
      tx = await mesonInstance.depositAndRegister(value, poolTokenIndex)
    } else {
      tx = await mesonInstance.deposit(value, poolTokenIndex)
    }
    await tx.wait()
  }
}
