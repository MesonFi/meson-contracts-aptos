const { readFileSync } = require("fs");
const { keccak256 } = require("js-sha3");
const { AptosClient, AptosAccount, CoinClient, FaucetClient, BCS } = require("aptos");

const NODE_URL = "https://fullnode.devnet.aptoslabs.com";

const USDC_Struct = "0x01015ace920c716794445979be68d402d28b2805b7beaae935d7fe369fa7cfa0::aUSDC::TypeUSDC"
const USDT_Struct = "0xaaefd8848cb707617bf82894e2d7af6214b3f3a8e3fc32e91bc026f05f5b10bb::aUSDT::TypeUSDT"


async function executeTransaction(client, wallet, function_name, type_arguments, arguments) {
  const payload = {
    function: function_name, type_arguments: type_arguments, arguments: arguments
  }
  const rawTxn = await client.generateTransaction(wallet.address(), payload);
  const bcsTxn = await client.signTransaction(wallet, rawTxn);
  const pendingTxn = await client.submitTransaction(bcsTxn);
  console.log(pendingTxn.hash)
  await client.waitForTransaction(pendingTxn.hash, { checkSuccess: true });
}


main = async () => {
  const mesonWallet = AptosAccount.fromAptosAccountObject(
    JSON.parse(readFileSync("wallet_for_test/wallet_contract.json", "utf-8"))
  )
  const Meson_Address = mesonWallet.address()

  const userWallet = AptosAccount.fromAptosAccountObject(
    JSON.parse(readFileSync("wallet_for_test/wallet_user.json", "utf-8"))
  )
  const lpWallet = AptosAccount.fromAptosAccountObject(
    JSON.parse(readFileSync("wallet_for_test/wallet_lp.json", "utf-8"))
  )

  const client = new AptosClient(NODE_URL)
  const coinClient = new CoinClient(client);

  console.log(`Atpos Balance of user ${userWallet.address()}: ${await coinClient.checkBalance(userWallet)}`)
  console.log(`Atpos Balance of LP ${lpWallet.address()}: ${await coinClient.checkBalance(lpWallet)}`)


  // PostSwap

  console.log('=================== Starting the swap ===================')
  let swapNum = 155
  const timeExpired = parseInt(Date.now() / 1000 + 7100)
  const keyString = "phil"

  await executeTransaction(
    client, userWallet,      // Step 1. (On source chain (In-chain))
    `${Meson_Address}::MesonSwap::postSwap`, [USDC_Struct], [
    lpWallet.address(), swapNum, timeExpired, 0, 0,
    BCS.bcsSerializeBytes(keccak256.digest(keyString)).slice(1)
  ]
  )
  console.log(`User postSwap finished! Deposit ${swapNum / 1e6} USDC.`)


  await executeTransaction(
    client, lpWallet,        // Step 2. (On target chain (Out-chain))
    `${Meson_Address}::MesonPools::lock`, [USDT_Struct], [
    userWallet.address(), swapNum, timeExpired, 0, 0,
    BCS.bcsSerializeBytes(keccak256.digest(keyString)).slice(1)
  ]
  )
  console.log(`LP lock finished! Deposit ${swapNum / 1e6} USDT.`)


  await executeTransaction(
    client, userWallet,        // Step 3. (On target chain (Out-chain))
    `${Meson_Address}::MesonPools::release`, [USDT_Struct], [
    userWallet.address(), lpWallet.address(),
    BCS.bcsSerializeStr(keyString).slice(1), swapNum, timeExpired, 0, 0,
    BCS.bcsSerializeBytes(keccak256.digest(keyString)).slice(1)
  ]
  )
  console.log(`User release finished! Release ${swapNum / 1e6} USDT.`)


  await executeTransaction(
    client, lpWallet,        // Step 4. (On source chain (In-chain))
    `${Meson_Address}::MesonSwap::executeSwap`, [USDC_Struct], [
    BCS.bcsSerializeStr(keyString).slice(1), swapNum, timeExpired, 0, 0,
    BCS.bcsSerializeBytes(keccak256.digest(keyString)).slice(1), true
  ]
  )
  console.log(`LP release finished! Release ${swapNum / 1e6} USDC.`)
}

main()