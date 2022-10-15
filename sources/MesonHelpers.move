module Meson::MesonHelpers {
    /* ---------------------------- References ---------------------------- */

    use std::bcs;
    use std::vector;
    use aptos_std::aptos_hash;

    friend Meson::MesonSwap;
    friend Meson::MesonPools;

    const DEPLOYER: address = @Meson;
    const ENOT_DEPLOYER: u64 = 0;
    const ESWAP_ALREADY_EXISTS: u64 = 2;



    /* ---------------------------- Struct & Constructor ---------------------------- */

    // struct EncodedSwap has copy, drop {
    //     amount: u64,
    //     expireTs: u64,
    //     outChain: u64,
    //     inChain: u64,
    //     lockHash: vector<u8>,
    // }

    // This struct is only for the function `getSwapHash`.
    struct EncodedAndInitiator has drop {
        encoded: vector<u128>,
        initiator: vector<u8>,
    }

    // `PostedSwap` is in format of `initiatorAddr:address|poolIndex:uint40` in solidity.
    struct PostedSwap has store {
        initiatorAddr: address,
        poolOwner: address,
    }

    // `LockedSwap` is in format of `until:uint40|poolIndex:uint40` in solidity.
    struct LockedSwap has store {
        until: u64,
        poolOwner: address,
    }

    // Create a new `EncodedSwap` instance
    // public(friend) fun newEncodedSwap(amount: u64, expireTs: u64, outChain: u64, inChain: u64, lockHash: vector<u8>): EncodedSwap {
    //     EncodedSwap { amount, expireTs, outChain, inChain, lockHash }
    // }

    // Create a new `PostedSwap` instance
    public(friend) fun newPostedSwap(initiatorAddr: address, poolOwner: address): PostedSwap {
        PostedSwap { initiatorAddr, poolOwner }
    }

    // Create a new `LockedSwap` instance
    public(friend) fun newLockedSwap(until: u64, poolOwner: address): LockedSwap {
        LockedSwap { until, poolOwner }
    }



    /* ---------------------------- Utils Function ---------------------------- */

    // The swap ID in explorer
    public(friend) fun getSwapId(encoded: vector<u128>, initiator: vector<u8>): vector<u8> {
        let encodeContent = EncodedAndInitiator { encoded, initiator };
        let serializedContent = bcs::to_bytes(&encodeContent);
        aptos_hash::keccak256(serializedContent)
    }

    // Functions to obtain values from encoded
    public(friend) fun versionFrom(encoded: vector<u128>): u8 {
        let encoded0 = *vector::borrow(&encoded, 0);
        ((encoded0 >> 120) as u8)
        // let inChain = (((encoded1 >> 8) & 0xFFFF) as u64);
        // let outChain = (((encoded1 >> 32) & 0xFFFF) as u64);
    }

    public(friend) fun amountFrom(encoded: vector<u128>): u64 {
        let encoded0 = *vector::borrow(&encoded, 0);
        (((encoded0 >> 80) & 0xFFFFFFFFFF) as u64)
    }

    public(friend) fun expireTsFrom(encoded: vector<u128>): u64 {
        let encoded1 = *vector::borrow(&encoded, 0);
        (((encoded1 >> 48) & 0xFFFFFFFFFF) as u64)
    }

    // TODO
    // public(friend) fun hashValueFrom(encodedSwap: EncodedSwap): vector<u8> {
    //     encodedSwap.lockHash
    // }

    public(friend) fun destructPosted(postingValue: PostedSwap): (address, address) {
        let PostedSwap { initiatorAddr, poolOwner } = postingValue;
        (initiatorAddr, poolOwner)
    }

    public(friend) fun destructLocked(lockedSwap: LockedSwap): (u64, address) {
        let LockedSwap { until, poolOwner } = lockedSwap;
        (until, poolOwner)
    }

    // public(friend) fun getEthAddress(pk: vector<u8>): vector<u8> {
    //     string::internal_sub_string(aptos_hash::keccak256(string::internal_sub_string(pk, 1, 64)), 12, 64)
    // }
}