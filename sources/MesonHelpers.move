module Meson::MesonHelpers {
    /* ---------------------------- References ---------------------------- */

    use std::vector;
    use std::option;
    use aptos_std::aptos_hash;
    use aptos_std::secp256k1;

    friend Meson::MesonSwap;
    friend Meson::MesonPools;

    const DEPLOYER: address = @Meson;
    const ENOT_DEPLOYER: u64 = 0;
    const ESWAP_ALREADY_EXISTS: u64 = 2;

    /* ---------------------------- Struct & Constructor ---------------------------- */

    /* ---------------------------- Utils Function ---------------------------- */

    // The swap ID in explorer
    public(friend) fun getSwapId(_encoded: vector<u128>, initiator: vector<u8>): vector<u8> {
        // TODO: encoded => buf
        let buf = vector::empty<u8>();
        vector::append<u8>(&mut buf, initiator);
        aptos_hash::keccak256(buf)
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

    public fun eth_address_from_pubkey(pk: vector<u8>): vector<u8> {
        // Public key `pk` should be uncompressed 
        // Notice that Ethereum pubkey has an extra 0x04 prefix (specifies uncompressed)
        assert!(vector::length(&pk) == 64, 1);
        let hash = aptos_hash::keccak256(pk);
        let eth_addr = vector::empty<u8>();
        let i = 12;
        while (i < 32) {
            vector::push_back(&mut eth_addr, *vector::borrow<u8>(&hash, i));
            i = i + 1;
        };
        eth_addr
    }

    public fun recover_eth_address(digest: vector<u8>, signature: vector<u8>): vector<u8> {
        // EIP-2098: recovery_id is stored in first bit of sig.s
        let first_bit_of_s = vector::borrow_mut(&mut signature, 32);
        let recovery_id = *first_bit_of_s >> 7;
        *first_bit_of_s = *first_bit_of_s & 0x7f;

        let ecdsa_sig = secp256k1::ecdsa_signature_from_bytes(signature);
        let pk = secp256k1::ecdsa_recover(digest, recovery_id, &ecdsa_sig);
        if (option::is_some(&pk)) {
            let extracted = option::extract(&mut pk);
            let raw_pk = secp256k1::ecdsa_raw_public_key_to_bytes(&extracted);
            eth_address_from_pubkey(raw_pk)
        } else {
            vector::empty<u8>()
        }
    }

    #[test]
    fun test_eth_address_from_pubkey() {
        let pk = x"5139c6f948e38d3ffa36df836016aea08f37a940a91323f2a785d17be4353e382b488d0c543c505ec40046afbb2543ba6bb56ca4e26dc6abee13e9add6b7e189";
        let eth_addr = eth_address_from_pubkey(pk);
        assert!(eth_addr == x"052c7707093534035fc2ed60de35e11bebb6486b", 1);
    }

    #[test]
    fun test_recover_eth_address() {
        let eth_addr = recover_eth_address(
            x"ea83cdcdd06bf61e414054115a551e23133711d0507dcbc07a4bab7dc4581935",
            x"2bd03a0d8edfcbe82e56ffede5a94f49635c802364630bc3bc9b17ba85baadfab8b733437f0ad897aa246d011122570c6c9943ead86252d4f16952495380a31e"
        );
        assert!(eth_addr == x"052c7707093534035fc2ed60de35e11bebb6486b", 1);
    }
}
