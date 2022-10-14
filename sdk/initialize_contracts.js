const { AptosClient, AptosAccount, CoinClient, TokenClient, FaucetClient } = require("aptos");
const { readFileSync } = require("fs");

const NODE_URL = "https://fullnode.devnet.aptoslabs.com";
const FAUCET_URL = "https://faucet.devnet.aptoslabs.com";

async function executeTransaction(function_name, type_arguments, arguments, wallet) {
    const rawTxn = await this.generateTransaction(wallet.address(), {
        function_name, type_arguments, arguments
    });
    const bcsTxn = await this.signTransaction(wallet, rawTxn);
    const pendingTxn = await this.submitTransaction(bcsTxn);
    await client.waitForTransaction(pendingTxn.hash, { checkSuccess: true });
}

main = async () => {
    const contractWallet = AptosAccount.fromAptosAccountObject(
        JSON.parse(readFileSync("wallet_for_test/wallet_1.json", "utf-8"))
    )
    const client = new AptosClient(NODE_URL)
    const coinClient = new CoinClient(client);
    const faucetClient = new FaucetClient(NODE_URL, FAUCET_URL)
    await faucetClient.fundAccount(contractWallet.address(), 200000)

    let balance = await coinClient.checkBalance(contractWallet)
    console.log(`Balance of contract wallet: ${balance}`)

    

}

main()