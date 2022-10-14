const { AptosClient, AptosAccount, CoinClient, TokenClient, FaucetClient } = require("aptos");
const { readFileSync } = require("fs");

const NODE_URL = "https://fullnode.devnet.aptoslabs.com";
const FAUCET_URL = "https://faucet.devnet.aptoslabs.com";

const USDC_Struct = "0x01015ace920c716794445979be68d402d28b2805b7beaae935d7fe369fa7cfa0::aUSDC::TypeUSDC"
const USDT_Struct = "0xaaefd8848cb707617bf82894e2d7af6214b3f3a8e3fc32e91bc026f05f5b10bb::aUSDT::TypeUSDT"
const Meson_Address = "0x00085738d646709608dd7a429c32e147ecbd06741fec64399b9282a3a599a83e"


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
    const userWallet = AptosAccount.fromAptosAccountObject(
        JSON.parse(readFileSync("wallet_for_test/wallet_2.json", "utf-8"))
    )

    const lpWallet = AptosAccount.fromAptosAccountObject(
        JSON.parse(readFileSync("wallet_for_test/wallet_3.json", "utf-8"))
    )

    const client = new AptosClient(NODE_URL)
    const coinClient = new CoinClient(client);
    const faucetClient = new FaucetClient(NODE_URL, FAUCET_URL)
    // await faucetClient.fundAccount(lpWallet.address(), 200000)

    console.log(`Balance of user ${userWallet.address()}: ${await coinClient.checkBalance(userWallet)}`)
    console.log(`Balance of LP ${lpWallet.address()}: ${await coinClient.checkBalance(lpWallet)}`)


}