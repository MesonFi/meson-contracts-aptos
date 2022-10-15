# meson-contracts-move

## Deploy

### Install move and aptos client

1. Follow the guidance in [Move Tutorial](https://github.com/move-language/move/tree/main/language/documentation/tutorial#step-0-installation) by Move official documention to install the move CLI(Command Line Interface). Run ```move -V``` to check the version.

2. Follow the guidance of [Installing Aptos CLI](https://aptos.dev/cli-tools/aptos-cli-tool/install-aptos-cli) by Aptos official documention to install the Atpos CLI(Command Line Interface). Run ```aptos -V``` to check the version.

### Compile the move contract

A Move package source directory contains a ```Move.toml``` package manifest file along with a set of subdirectories:

```
a_move_package
├── Move.toml      (required)
├── sources        (required)
├── examples       (optional, test & dev mode)
├── scripts        (optional)
├── doc_templates  (optional)
└── tests          (optional, test mode)
```

You can run command ```move build``` or ```aptos move compile``` under the move package dir to compile a move package (such as the root dir of this project). See ```move --help``` or ```aptos move --help``` for more.


### Deploy the contract on Atpos using Aptos CLI

Run ```aptos init``` to prepare for deploying. The account information will be saved in ```.aptos/config.yaml```. See [Initialize local configuration and create an account](https://aptos.dev/cli-tools/aptos-cli-tool/use-aptos-cli/#initialize-local-configuration-and-create-an-account) for more.

Then run the command to deploy the contract:

```bash
aptos move publish --package-dir <package-dir> --named-addresses <address-name>=<address> --private-key <private-key>
``` 

The given ```<address-name>``` should be mentioned in ```Move.toml``` like this:

```toml
[addresses]
std = "0x1"
aptos_token = "0x3"
Meson = "_"
``` 

However, if you've already initialized the account and the account address is, for example, ```0x5566```, then you can replace the address in ```Move.toml``` by ```Meson = "0x5566"``` and directly run the command below:

```bash
aptos move publish --package-dir <package-dir>
```

See [Publish the HelloBlockchain module with the Aptos CLI](https://aptos.dev/tutorials/your-first-dapp/#publish-the-helloblockchain-module-with-the-aptos-cli) for more.

### Deploy the contract on Aptos using Aptos SDK in javascript/typescript

Follow the guidance and run [yourcoin.ts](https://github.com/aptos-labs/aptos-core/blob/main/ecosystem/typescript/sdk/examples/typescript/your_coin.ts) to learn the deployment method in SDK. Simply put, compile the move package and run the command below:

```typescript
const packageMetadata = fs.readFileSync(path.join(modulePath, "build", "Examples", "package-metadata.bcs"));
const moduleData = fs.readFileSync(path.join(modulePath, "build", "Examples", "bytecode_modules", `${moduleName}.mv`));
```

See [yourcoin.ts](https://github.com/aptos-labs/aptos-core/blob/main/ecosystem/typescript/sdk/examples/typescript/your_coin.ts#L97) for more.
