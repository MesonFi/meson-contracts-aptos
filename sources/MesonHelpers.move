/// @title MesonHelpers
/// @notice The class that provides helper functions for Meson protocol
module Meson::MesonHelpers {
    use std::vector;
    use std::option;
    use std::bcs;
    use aptos_std::aptos_hash;
    use aptos_std::secp256k1;

    friend Meson::MesonSwap;
    friend Meson::MesonPools;

    const DEPLOYER: address = @Meson;
    const ENOT_DEPLOYER: u64 = 0;
    const ESWAP_ALREADY_EXISTS: u64 = 2;

    const MESON_PROTOCOL_VERSION: u8 = 1;
    const SHORT_COIN_TYPE: vector<u8> = x"027d";

    const REQUEST_TYPE: vector<u8> = b"bytes32 Sign to request a swap on Meson (Testnet)";
    const RELEASE_TYPE: vector<u8> = b"bytes32 Sign to release a swap on Meson (Testnet)address Recipient";

    // TODO: cannot use module call in constants
    // const REQUEST_TYPE_HASH: vector<u8> = aptos_hash::keccak256(b"bytes32 Sign to request a swap on Meson (Testnet)");
    // const RELEASE_TYPE_HASH: vector<u8> = aptos_hash::keccak256(b"bytes32 Sign to release a swap on Meson (Testnet)address Recipient");


    public(friend) fun match_protocol_version(encoded_swap: vector<u8>) {
        assert!(version_from(encoded_swap) == MESON_PROTOCOL_VERSION, 1);
    }

    public(friend) fun for_initial_chain(encoded_swap: vector<u8>) {
        assert!(in_chain_from(encoded_swap) == SHORT_COIN_TYPE, 1);
    }

    public(friend) fun for_target_chain(encoded_swap: vector<u8>) {
        assert!(out_chain_from(encoded_swap) == SHORT_COIN_TYPE, 1);
    }

    public(friend) fun get_swap_id(encoded_swap: vector<u8>, initiator: vector<u8>): vector<u8> {
        let buf = copy encoded_swap;
        vector::append(&mut buf, initiator);
        aptos_hash::keccak256(buf)
    }

    #[test]
    public(friend) fun test_get_swap_id() {
        let swap_id = get_swap_id(
            x"01001dcd6500c00000000000f677815c000000000000634dcb98027d0102ca21",
            x"2ef8a51f8ff129dbb874a0efb021702f59c1b211"
        );
        assert!(swap_id == x"e3a84cd4912a01989c6cd24e41d3d94baf143242fbf1da26eb7eac08c347b638", 1);
    }

    // Functions to obtain values from encoded
    public(friend) fun version_from(encoded_swap: vector<u8>): u8 {
        *vector::borrow(&encoded_swap, 0)
    }

    public(friend) fun amount_from(encoded_swap: vector<u8>): u64 {
        let amount = (*vector::borrow(&encoded_swap, 1) as u64);
        let i = 2;
        while (i < 6) {
            let byte = *vector::borrow(&encoded_swap, i);
            amount = (amount << 1) + (byte as u64);
        };
        amount
    }

    public(friend) fun service_fee(encoded_swap: vector<u8>): u64 {
        let amount = amount_from(encoded_swap);
        amount * 10 / 10000 // Default to 0.1% * `amount`
    }

    public(friend) fun fee_for_lp(encoded_swap: vector<u8>): u64 {
        let fee = (*vector::borrow(&encoded_swap, 16) as u64);
        let i = 17;
        while (i < 21) {
            let byte = *vector::borrow(&encoded_swap, i);
            fee = (fee << 1) + (byte as u64);
        };
        fee
    }

    public(friend) fun salt_from(encoded_swap: vector<u8>): vector<u8> {
        vector[
            *vector::borrow(&encoded_swap, 6),
            *vector::borrow(&encoded_swap, 7),
            *vector::borrow(&encoded_swap, 8),
            *vector::borrow(&encoded_swap, 9),
            *vector::borrow(&encoded_swap, 10),
            *vector::borrow(&encoded_swap, 11),
            *vector::borrow(&encoded_swap, 12),
            *vector::borrow(&encoded_swap, 13),
            *vector::borrow(&encoded_swap, 14),
            *vector::borrow(&encoded_swap, 15)
        ]
    }

    public(friend) fun salt_data_from(encoded_swap: vector<u8>): vector<u8> {
        vector[
            *vector::borrow(&encoded_swap, 8),
            *vector::borrow(&encoded_swap, 9),
            *vector::borrow(&encoded_swap, 10),
            *vector::borrow(&encoded_swap, 11),
            *vector::borrow(&encoded_swap, 12),
            *vector::borrow(&encoded_swap, 13),
            *vector::borrow(&encoded_swap, 14),
            *vector::borrow(&encoded_swap, 15)
        ]
    }

    public(friend) fun will_transfer_to_contract(encoded_swap: vector<u8>): bool {
        *vector::borrow(&encoded_swap, 6) & 0x80 == 0x80
    }

    public(friend) fun fee_waived(encoded_swap: vector<u8>): bool {
        *vector::borrow(&encoded_swap, 6) & 0x40 == 0x40
    }

    public(friend) fun sign_non_typed(encoded_swap: vector<u8>): bool {
        *vector::borrow(&encoded_swap, 6) & 0x08 == 0x08
    }

    public(friend) fun expire_ts_from(encoded_swap: vector<u8>): u64 {
        let expire_ts = (*vector::borrow(&encoded_swap, 21) as u64);
        let i = 22;
        while (i < 26) {
            let byte = *vector::borrow(&encoded_swap, i);
            expire_ts = (expire_ts << 1) + (byte as u64);
        };
        expire_ts
    }

    public(friend) fun in_chain_from(encoded_swap: vector<u8>): vector<u8> {
        vector[*vector::borrow(&encoded_swap, 29), *vector::borrow(&encoded_swap, 30)]
    }

    public(friend) fun in_token_index_from(encoded_swap: vector<u8>): u8 {
        *vector::borrow(&encoded_swap, 31)
    }

    public(friend) fun out_chain_from(encoded_swap: vector<u8>): vector<u8> {
        vector[*vector::borrow(&encoded_swap, 26), *vector::borrow(&encoded_swap, 27)]
    }

    public(friend) fun out_token_index_from(encoded_swap: vector<u8>): u8 {
        *vector::borrow(&encoded_swap, 28)
    }



    public(friend) fun check_request_signature(
        encoded_swap: vector<u8>,
        signature: vector<u8>,
        signer_eth_addr: vector<u8>
    ) {
        assert!(signer_eth_addr != x"", 1);

        let msg_hash = aptos_hash::keccak256(encoded_swap);

        // TODO: How to store the hash as constant?
        let with_header = aptos_hash::keccak256(REQUEST_TYPE);
        vector::append(&mut with_header, msg_hash);
        let digest = aptos_hash::keccak256(with_header);

        let recovered = recover_eth_address(digest, signature);
        assert!(recovered == signer_eth_addr, 1);
    }

    #[test]
    fun test_check_request_signature() {
        let encoded_swap = x"01001dcd6500c00000000000f677815c000000000000634dcb98027d0102ca21";
        let signature = x"b3184c257cf973069250eefd849a74d27250f8343cbda7615191149dd3c1b61d5d4e2b5ecc76a59baabf10a8d5d116edb95a5b2055b9b19f71524096975b29c2";
        let eth_addr = x"2ef8a51f8ff129dbb874a0efb021702f59c1b211";
        check_request_signature(encoded_swap, signature, eth_addr);
    }

    public(friend) fun check_release_signature(
        encoded_swap: vector<u8>,
        recipient: vector<u8>,
        signature: vector<u8>,
        signer_eth_addr: vector<u8>,
    ) {
        assert!(signer_eth_addr != x"", 1);

        let msg = copy encoded_swap;
        vector::append(&mut msg, recipient);
        let msg_hash = aptos_hash::keccak256(msg);

        // TODO: How to store the hash as constant?
        let with_header = aptos_hash::keccak256(RELEASE_TYPE);
        vector::append(&mut with_header, msg_hash);
        let digest = aptos_hash::keccak256(with_header);

        let recovered = recover_eth_address(digest, signature);
        assert!(recovered == signer_eth_addr, 1);
    }

    #[test]
    fun test_check_release_signature() {
        let encoded_swap = x"01001dcd6500c00000000000f677815c000000000000634dcb98027d0102ca21";
        let recipient = x"01015ace920c716794445979be68d402d28b2805";
        let signature = x"1205361aabc89e5b30592a2c95592ddc127050610efe92ff6455c5cfd43bdd825853edcf1fa72f10992b46721d17cb3191a85cefd2f8325b1ac59c7d498fa212";
        let eth_addr = x"2ef8a51f8ff129dbb874a0efb021702f59c1b211";
        check_release_signature(encoded_swap, recipient, signature, eth_addr);
    }

    public(friend) fun eth_address_from_aptos_address(addr: address): vector<u8> {
        let addr_bytes = bcs::to_bytes(&addr);
        let eth_addr = vector::empty<u8>();
        let i = 0;
        while (i < 20) {
            vector::push_back(&mut eth_addr, *vector::borrow(&addr_bytes, i));
            i = i + 1;
        };
        eth_addr
    }

    #[test]
    fun test_eth_address_from_aptos_address() {
        let aptos_addr = @0x01015ace920c716794445979be68d402d28b2805b7beaae935d7fe369fa7cfa0;
        let eth_addr = eth_address_from_aptos_address(aptos_addr);
        assert!(eth_addr == x"01015ace920c716794445979be68d402d28b2805", 1);
    }

    public fun eth_address_from_pubkey(pk: vector<u8>): vector<u8> {
        // Public key `pk` should be uncompressed 
        // Notice that Ethereum pubkey has an extra 0x04 prefix (specifies uncompressed)
        assert!(vector::length(&pk) == 64, 1);
        let hash = aptos_hash::keccak256(pk);
        let eth_addr = vector::empty<u8>();
        let i = 12;
        while (i < 32) {
            vector::push_back(&mut eth_addr, *vector::borrow(&hash, i));
            i = i + 1;
        };
        eth_addr
    }

    #[test]
    fun test_eth_address_from_pubkey() {
        let pk = x"5139c6f948e38d3ffa36df836016aea08f37a940a91323f2a785d17be4353e382b488d0c543c505ec40046afbb2543ba6bb56ca4e26dc6abee13e9add6b7e189";
        let eth_addr = eth_address_from_pubkey(pk);
        assert!(eth_addr == x"052c7707093534035fc2ed60de35e11bebb6486b", 1);
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
    fun test_recover_eth_address() {
        let eth_addr = recover_eth_address(
            x"ea83cdcdd06bf61e414054115a551e23133711d0507dcbc07a4bab7dc4581935",
            x"2bd03a0d8edfcbe82e56ffede5a94f49635c802364630bc3bc9b17ba85baadfab8b733437f0ad897aa246d011122570c6c9943ead86252d4f16952495380a31e"
        );
        assert!(eth_addr == x"052c7707093534035fc2ed60de35e11bebb6486b", 1);
    }
}
