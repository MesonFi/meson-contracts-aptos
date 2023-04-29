# Meson Contract on Move

## Introducing Meson

Meson (https://meson.fi) is the faster and safer way to execute low-cost, zero-slippage stablecoin **cross-chain swaps** across all leading blockchains and layer-2 rollups. As Aptos' mainnet launched on October, Meson is also preparing for launching on Aptos and other Move-based layer-1 blockchain, such as Sui and Starcoin.

As shown in the figure below, Meson is now ready on Aptos Devnet!

![image](./figure/Meson-Testnet-Support-Aptos.png)

See [Introducing Meson : the boundless highway for cross-chain stablecoins swap
](https://medium.com/@mesonfi/introducing-meson-the-boundless-freeway-for-cross-chain-stablecoins-movements-a30d07255519) to learn more about Meson. If you want to dive into the technical details, you can also read our documentation on [Meson Docs](https://docs.meson.fi/).

<br/>



## How To Use

### Directly using Meson on browser

If you wants to try using Meson on Aptos Devnet, enter [Meson Testnet App](https://meson-testnet.herokuapp.com/) to make a transaction and find it on the [Meson Testnet Explorer](https://testnet-explorer.meson.fi/).

If you wants to use Meson on other EVM chains to swap your real stablecoin assets, enter [Meson App](https://meson.fi/) to make a transaction and find it on the [Meson Explorer](https://explorer.meson.fi/). Meson now supports 11 blockchains on mainnet.

<br/>

### Running Meson protocol in this project

Follow the steps to deploy a new Meson protocol on Aptos Devnet:

```
yarn install
yarn deploy
```

After that, the Meson protocol should already be published on a new address and well initialized. For convenience, we use two deployed fake coins to simulate USDC and USDT: `0x1015ace920c716794445979be68d402d28b2805b7beaae935d7fe369fa7cfa0::aUSDC::TypeUSDC` and `0xaaefd8848cb707617bf82894e2d7af6214b3f3a8e3fc32e91bc026f05f5b10bb::aUSDT::TypeUSDT`. 

The address and the private key (just for test) of the liquidity provider is given in environment variables file `.env`, and it has enough fake USDC and fake USDT to deposit into the liquidity pool in contracts.

Then, you can see a cross-chain swap demo by running:

```
yarn swap
```

And you will see the swap process.



<br/>

### Introducing meson code structure

Meson contracts on move contains the module below: 

- `MesonCoins.move`: The contract about the supported stablecoins. We use the coin standard `aptos_framework::coin` on Aptos to support stablecoins.

- `MesonConfig.move`: The constant variables used in the contracts.

- `MesonHelpers.move`: Contains some utils functions used in other contracts.

- `MesonStates`: Contains some utils functions about LP (Liquidity Provider) related functions.

- `MesonSourceChain.move`: The contract for cross-chain swaps when Aptos is the source chain. The main entry function is `postSwap` and `executeSwap`, which is the implementation of **Step 2 (Post and bond a swap)** and **Step 6 (Receive initial funds)** in [Meson Swap Process](https://docs.meson.fi/protocol/meson/process).

- `MesonTargetChain.move`: The contract for cross-chain swaps when Aptos is the target chain. The main entry function is `lock` and `release`, which is the implementation of **Step 3 (Lock the swap)** and **Step 5 (Release fund)** in [Meson Swap Process](https://docs.meson.fi/protocol/meson/process).

<br/>


## Acknowledgement

Project Author: [wyf-ACCEPT](https://github.com/wyf-ACCEPT)

This project was originally created by wyf-ACCEPT and has since been taken over and maintained by [MesonFi](https://github.com/mesonfi). We would like to thank wyf-ACCEPT for his professional assistance in completing the work for Aptos. If you have any questions or suggestions, please feel free to contact MesonFi in [discord](https://discord.gg/meson) or [wyf-ACCEPT](https://github.com/wyf-ACCEPT).
