module Meson::test_sign {
    use std::ed25519;

    public entry fun justForTest() {
        let signature_bytes = x"62d6be393b8ec77fb2c12ff44ca8b5bd8bba83b805171bc99f0af3bdc619b20b8bd529452fe62dac022c80752af2af02fb610c20f01fb67a4d72789db2b8b703";
        let pubkey_bytes = x"7013b6ed7dde3cfb1251db1b04ae9cd7853470284085693590a75def645a926d";
        let message = x"0000000000000000000000000000000000000000000000000000000000000000";

        let signature: ed25519::Signature = ed25519::new_signature_from_bytes(signature_bytes);
        let pubkey: ed25519::UnvalidatedPublicKey = ed25519::new_unvalidated_public_key_from_bytes(pubkey_bytes);

        assert!(ed25519::signature_verify_strict(&signature, &pubkey, message), 9001);
    }

    public entry fun justForTest2() {
        let valid_signature = x"62d6be393b8ec77fb2c12ff44ca8b5bd8bba83b805171bc99f0af3bdc619b20b8bd529452fe62dac022c80752af2af02fb610c20f01fb67a4d72789db2b8b703";
        assert!(valid_signature!=x"", 0);
    }
    
    // #[test]
    // fun SignatureTest() {
    //     // from RFC 8032
    //     let valid_pubkey = x"3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c";
    //     let short_pubkey = x"0100";
    //     // concatenation of the two above
    //     let long_pubkey = x"01003d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c";
    //     let invalid_pubkey = x"0000000000000000000000000000000000000000000000000000000000000000";

    //     let short_signature = x"0100";
    //     let long_signature = x"0062d6be393b8ec77fb2c12ff44ca8b5bd8bba83b805171bc99f0af3bdc619b20b8bd529452fe62dac022c80752af2af02fb610c20f01fb67a4d72789db2b8b703";
    //     let valid_signature = x"62d6be393b8ec77fb2c12ff44ca8b5bd8bba83b805171bc99f0af3bdc619b20b8bd529452fe62dac022c80752af2af02fb610c20f01fb67a4d72789db2b8b703";

    //     let message = x"0000000000000000000000000000000000000000000000000000000000000000";
    //     let pubkey = x"7013b6ed7dde3cfb1251db1b04ae9cd7853470284085693590a75def645a926d";

    //     assert!(ed25519::public_key_validate_internal(copy valid_pubkey), 9003);
    //     assert!(!ed25519::public_key_validate_internal(copy short_pubkey), 9004);
    //     assert!(!ed25519::public_key_validate_internal(copy long_pubkey), 9005);
    //     assert!(!ed25519::public_key_validate_internal(copy invalid_pubkey), 9006);


    //     // now check that ed25519::signature_verify_strict_internal works with well- and ill-formed data and never aborts
    //     // valid signature, invalid pubkey (too short, too long, bad small subgroup)
    //     assert!(!ed25519::signature_verify_strict_internal(copy valid_signature, copy short_pubkey, x""), 9004);
    //     assert!(!ed25519::signature_verify_strict_internal(copy valid_signature, copy long_pubkey, x""), 9005);
    //     assert!(!ed25519::signature_verify_strict_internal(copy valid_signature, copy invalid_pubkey, x""), 9006);
    //     // invalid signature, valid pubkey
    //     assert!(!ed25519::signature_verify_strict_internal(copy short_signature, copy valid_pubkey, x""), 9007);
    //     assert!(!ed25519::signature_verify_strict_internal(copy long_signature, copy valid_pubkey, x""), 9008);

    //     // valid (lengthwise) signature, valid pubkey, but signature doesn't match message
    //     assert!(!ed25519::signature_verify_strict_internal(copy valid_signature, copy valid_pubkey, x""), 9009);

    //     // all three valid
    //     assert!(ed25519::signature_verify_strict_internal(valid_signature, pubkey, message), 9010);
    // }
}