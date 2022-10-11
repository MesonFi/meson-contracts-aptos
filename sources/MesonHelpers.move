
module Meson::MesonHelpers {
    /* ---------------------------- References ---------------------------- */

    // We merge the `MesonSwap` file into `MesonHelpers`.
    use aptos_token::token::{Token};

    friend Meson::MesonSwap;

    const DEPLOYER: address = @Meson;
    const ENOT_DEPLOYER: u64 = 0;
    const ESWAP_ALREADY_EXISTS: u64 = 2;



    /* ---------------------------- Struct & Constructor ---------------------------- */

    // `encodedSwap` is in format of `amount:uint48|salt:uint80|fee:uint40|expireTs:uint40|outChain:uint16|outToken:uint8|inChain:uint16|inToken:uint8` in solidity.
    // However, it's not convenient in Move to obtain a slice in bytes and convert it to uint. So we use a struct `EncodedSwap` to store the transaction information.
    struct EncodedSwap has copy, drop {
        amount: u64,
        salt: vector<u8>,
        fee: u64,
        expireTs: u64,
        outChain: u64,
        outToken: u64,      // `u8` cannot be the index of a vector.
        inChain: u64,
        inToken: u64,
    }

    // We discard `poolIndex` in solidity, because we don't need a `pool` in move language. Instead, we stored the Token Entity in the PostedSwap, together with the initiator's address and liquidity provider's address.
    struct PostedSwap has store {
        initiator: address,
        lp: address,
        tokenEntity: Token,
    }

    // Create a new `EncodedSwap` instance
    public(friend) fun newEncodedSwap(amount: u64, salt: vector<u8>, fee: u64, expireTs: u64, outChain: u64, outToken: u64, inChain: u64, inToken: u64): EncodedSwap {
        EncodedSwap { amount, salt, fee, expireTs, outChain, outToken, inChain, inToken }
    }

    // Create a new `PostedSwap` instance
    public(friend) fun newPostedSwap(initiator: address, lp: address, tokenEntity: Token): PostedSwap {
        PostedSwap { initiator, lp, tokenEntity }
    }



    /* ---------------------------- Main Function ---------------------------- */



    /* ---------------------------- Utils Function ---------------------------- */

    // Functions to obtain values from EncodedSwap
    public(friend) fun amountFrom(encodedSwap: EncodedSwap): u64 {
        encodedSwap.amount
    }

    public(friend) fun expireTsFrom(encodedSwap: EncodedSwap): u64 {
        encodedSwap.expireTs
    }

    public(friend) fun inTokenIndexFrom(encodedSwap: EncodedSwap): u64 {
        encodedSwap.inToken
    }

    public(friend) fun outTokenIndexFrom(encodedSwap: EncodedSwap): u64 {
        encodedSwap.outToken
    }

    // public(friend) fun initiatorFromPosted(postingValue: PostedSwap): address {
    //     postingValue.initiator
    // }

    // public(friend) fun poolIndexFromPosted(postingValue: PostedSwap): u64 {
    //     postingValue.poolIndex
    // }

}