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

    // This struct is only for the function `getSwapHash`.
    struct EncodedAndInitiator has drop {
        encoded: vector<u128>,
        initiator: vector<u8>,
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

    // public(friend) fun getEthAddress(pk: vector<u8>): vector<u8> {
    //     string::internal_sub_string(aptos_hash::keccak256(string::internal_sub_string(pk, 1, 64)), 12, 64)
    // }
}