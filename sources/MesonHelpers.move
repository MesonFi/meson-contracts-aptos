module Meson::MesonHelpers {
    /* ---------------------------- References ---------------------------- */

    use std::bcs;
    use aptos_std::aptos_hash;

    friend Meson::MesonSwap;
    friend Meson::MesonPools;

    const DEPLOYER: address = @Meson;
    const ENOT_DEPLOYER: u64 = 0;
    const ESWAP_ALREADY_EXISTS: u64 = 2;



    /* ---------------------------- Struct & Constructor ---------------------------- */

    // `EncodedSwap` is in format of `amount:uint48|salt:uint80|fee:uint40|expireTs:uint40|outChain:uint16|outToken:uint8|inChain:uint16|inToken:uint8` in solidity.
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
        lockHash: vector<u8>,
    }

    // This struct is only for the function `getSwapHash`.
    struct EncodedSwapAndInitiator has drop {
        encodedSwap: EncodedSwap,
        initiator: address,
    }

    // `PostedSwap` is in format of `initiator:address|poolIndex:uint40` in solidity.
    struct PostedSwap has store {
        initiator: address,
        recipient: address,
    }

    // `LockedSwap` is in format of `until:uint40|poolIndex:uint40` in solidity.
    struct LockedSwap has store {
        until: u64,
        recipient: address,
    }

    // Create a new `EncodedSwap` instance
    public(friend) fun newEncodedSwap(amount: u64, salt: vector<u8>, fee: u64, expireTs: u64, outChain: u64, outToken: u64, inChain: u64, inToken: u64, lockHash: vector<u8>): EncodedSwap {
        EncodedSwap { amount, salt, fee, expireTs, outChain, outToken, inChain, inToken, lockHash }
    }

    // Create a new `PostedSwap` instance
    public(friend) fun newPostedSwap(initiator: address, recipient: address): PostedSwap {
        PostedSwap { initiator, recipient }
    }

    // Create a new `LockedSwap` instance
    public(friend) fun newLockedSwap(until: u64, recipient: address): LockedSwap {
        LockedSwap { until, recipient }
    }



    /* ---------------------------- Main Function ---------------------------- */



    /* ---------------------------- Utils Function ---------------------------- */

    // The swap ID in explorer
    public(friend) fun getSwapId(encodedSwap: EncodedSwap, initiator: address): vector<u8> {
        let encodeContent = EncodedSwapAndInitiator { encodedSwap, initiator };
        let serializedContent = bcs::to_bytes(&encodeContent);
        aptos_hash::keccak256(serializedContent)
    }

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

    public(friend) fun hashValueFrom(encodedSwap: EncodedSwap): vector<u8> {
        encodedSwap.lockHash
    }

    public(friend) fun destructPosted(postingValue: PostedSwap): (address, address) {
        let PostedSwap { initiator, recipient } = postingValue;
        (initiator, recipient)
    }

    public(friend) fun destructLocked(lockedSwap: LockedSwap): (u64, address) {
        let LockedSwap { until, recipient } = lockedSwap;
        (until, recipient)
    }

}