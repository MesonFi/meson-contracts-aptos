const { AptosClient, AptosAccount, CoinClient, FaucetClient } = require("aptos");
const { readFileSync, writeFileSync } = require("fs");

const NODE_URL = "https://fullnode.devnet.aptoslabs.com";
const FAUCET_URL = "https://faucet.devnet.aptoslabs.com";

main = async () => {
    const mesonWallet = new AptosAccount()
    let privateKeyObject = mesonWallet.toPrivateKeyObject()
    writeFileSync(`./wallet_for_test/wallet_1.json`, JSON.stringify(privateKeyObject))
    writeFileSync(`./wallet_for_test/save_to_yaml.log`, `    private_key: "${privateKeyObject.privateKeyHex}"
    public_key: "${privateKeyObject.publicKeyHex}"
    account: ${privateKeyObject.address.slice(2)}`)

    const coinClient = new CoinClient(new AptosClient(NODE_URL));
    const faucetClient = new FaucetClient(NODE_URL, FAUCET_URL)
    await faucetClient.fundAccount(mesonWallet.address(), 100_000_000)

    console.log(`Balance of ${mesonWallet.address()}: ${await coinClient.checkBalance(mesonWallet)}`)
}

main()

// Then run: aptos move publish --package-dir ../meson-contracts-move