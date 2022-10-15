const { AptosClient, AptosAccount, CoinClient, TokenClient, FaucetClient } = require("aptos");
const { readFileSync, writeFileSync } = require("fs");

const NODE_URL = "https://fullnode.devnet.aptoslabs.com";

const USDC_Struct = "0x01015ace920c716794445979be68d402d28b2805b7beaae935d7fe369fa7cfa0::aUSDC::TypeUSDC"
const USDT_Struct = "0xaaefd8848cb707617bf82894e2d7af6214b3f3a8e3fc32e91bc026f05f5b10bb::aUSDT::TypeUSDT"


async function executeTransaction(client, wallet, function_name, type_arguments, arguments) {
  payload = {
    function: function_name, type_arguments: type_arguments, arguments: arguments
  }
  const rawTxn = await client.generateTransaction(wallet.address(), payload);
  const bcsTxn = await client.signTransaction(wallet, rawTxn);
  const pendingTxn = await client.submitTransaction(bcsTxn);
  await client.waitForTransaction(pendingTxn.hash, { checkSuccess: true });
}


main = async () => {
  const mesonWallet = AptosAccount.fromAptosAccountObject(
    JSON.parse(readFileSync("wallet_for_test/wallet_contract.json", "utf-8"))
  )
  const Meson_Address = mesonWallet.address()

  const lpWallet = AptosAccount.fromAptosAccountObject(
    JSON.parse(readFileSync("wallet_for_test/wallet_lp.json", "utf-8"))
  )

  const client = new AptosClient(NODE_URL)
  const coinClient = new CoinClient(client)

  let balance = await coinClient.checkBalance(mesonWallet)
  console.log(`Balance of mesonWallet: ${balance}`)


  // `Initializing` process only execute once.

  console.log('=================== Initializing Contract ===================')
  for (var struct_name of [USDT_Struct, USDC_Struct]) {
    for (var module_name of ['MesonPools', 'MesonSwap', 'MesonStates']) {
      await executeTransaction(
        client, mesonWallet,
        `${Meson_Address}::${module_name}::initializeTable`, [struct_name], []
      )
      console.log(`\t${module_name}<${struct_name}> initialized!`)
    }
  }


  // For liquidity provider

  console.log('=================== Initializing liquidity provider ===================')
  const deposit_amount = 500_000_000
  for (var struct_name of [USDT_Struct, USDC_Struct]) {
    await executeTransaction(
      client, lpWallet,
      `${Meson_Address}::MesonPools::depositAndRegister`, [struct_name], [deposit_amount] // (Just the first time)
      // `${Meson_Address}::MesonPools::deposit`, [struct_name], [deposit_amount]
    )
    console.log(`Deposit ${deposit_amount / 1_000_000} USDT(USDC) success!`)
  }

}

main()