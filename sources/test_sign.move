module Meson::test_sign {
    use std::signer;
    use std::ed25519;
    use std::timestamp;

    const ERESOURCE_NOT_EXIST: u64 = 0;
    const ETIME_EXPIRED: u64 = 1;

    struct TimeRecord has key, drop, copy {
        time_record: u64
    }

    public entry fun testSign() {
        let signature_bytes = x"62d6be393b8ec77fb2c12ff44ca8b5bd8bba83b805171bc99f0af3bdc619b20b8bd529452fe62dac022c80752af2af02fb610c20f01fb67a4d72789db2b8b703";
        let pubkey_bytes = x"7013b6ed7dde3cfb1251db1b04ae9cd7853470284085693590a75def645a926d";
        let message = x"0000000000000000000000000000000000000000000000000000000000000000";

        let signature: ed25519::Signature = ed25519::new_signature_from_bytes(signature_bytes);
        let pubkey: ed25519::UnvalidatedPublicKey = ed25519::new_unvalidated_public_key_from_bytes(pubkey_bytes);

        assert!(ed25519::signature_verify_strict(&signature, &pubkey, message), 9001);
    }

    public entry fun testTimeNow(): u64 {
        timestamp::now_seconds()
    }

    public entry fun setTimeNow(account: &signer) acquires TimeRecord {
        if(!exists<TimeRecord>(signer::address_of(account))) {
            move_to<TimeRecord>(account, TimeRecord { time_record: timestamp::now_seconds() });
        }
        else {
            *borrow_global_mut<TimeRecord>(signer::address_of(account)) = TimeRecord { time_record: timestamp::now_seconds() };
        }
    }

    public entry fun testTimeExpire(account: &signer) acquires TimeRecord {
        assert!(exists<TimeRecord>(signer::address_of(account)), ERESOURCE_NOT_EXIST);
        assert!(timestamp::now_seconds() < (*borrow_global<TimeRecord>(signer::address_of(account))).time_record + 60, ETIME_EXPIRED);
    }

    #[test]
    public fun test() {
        assert!(0==0, 0);
    }
}