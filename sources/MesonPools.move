/// @title MesonPools
/// @notice The class to manage pools for LPs, and perform swap operations on the target 
/// chain side.
/// Methods in this class will be executed when a user wants to swap into this chain.
/// LP pool operations are also provided in this class.
module Meson::MesonPools {
    use std::signer;
    use std::timestamp;
    use aptos_framework::coin;
    use Meson::MesonHelpers;
    use Meson::MesonStates;

    const EEXIPRE_TS_IS_SOON: u64 = 6;
    const EALREADY_EXPIRED: u64 = 10;
    const ESTILL_IN_LOCK: u64 = 11;


    // Named consistently with solidity contracts
    public entry fun depositAndRegister<CoinType>(account: &signer, amount: u64, pool_index: u64) {
        MesonStates::register_pool_index(pool_index, signer::address_of(account));
        let coins = coin::withdraw<CoinType>(account, amount);
        MesonStates::coins_to_pool<CoinType>(pool_index, coins);
    }

    // Named consistently with solidity contracts
    public entry fun deposit<CoinType>(account: &signer, amount: u64) {
        let pool_index = MesonStates::pool_index_of(signer::address_of(account));
        let coins = coin::withdraw<CoinType>(account, amount);
        MesonStates::coins_to_pool<CoinType>(pool_index, coins);
    }

    // Named consistently with solidity contracts
    public entry fun withdraw<CoinType>(account: &signer, amount: u64) {
        let account_address = signer::address_of(account);
        let pool_index = MesonStates::pool_index_if_owner(signer::address_of(account));
        let coins = MesonStates::coins_from_pool<CoinType>(pool_index, amount);
        coin::deposit<CoinType>(account_address, coins);
    }


    // Step 2: Lock
    // Named consistently with solidity contracts
    public entry fun lock<CoinType>(
        account: &signer,
        encoded_swap: vector<u8>,
        signature: vector<u8>, // must be signed by `initiator`
        initiator: vector<u8>, // an eth address of (20 bytes), the signer to sign for release
        recipient: address,
    ) {
        MesonHelpers::is_encoded_valid(encoded_swap);
        MesonHelpers::for_target_chain(encoded_swap);
        MesonStates::match_coin_type<CoinType>(MesonHelpers::out_coin_index_from(encoded_swap));
        MesonHelpers::is_eth_addr(initiator);

        let until = timestamp::now_seconds() + MesonHelpers::get_LOCK_TIME_PERIOD();
        assert!(until < MesonHelpers::expire_ts_from(encoded_swap) - 300, EEXIPRE_TS_IS_SOON);

        let pool_index = MesonStates::pool_index_of(signer::address_of(account));

        MesonHelpers::check_request_signature(encoded_swap, signature, initiator);

        let swap_id = MesonHelpers::get_swap_id(encoded_swap, initiator);
        let amount = MesonHelpers::amount_from(encoded_swap)- MesonHelpers::fee_for_lp(encoded_swap);
        MesonStates::lock_coins<CoinType>(pool_index, amount, swap_id);
        MesonStates::add_locked_swap(swap_id, pool_index, until, recipient);
    }


    // Named consistently with solidity contracts
    public entry fun unlock<CoinType>(
        _account: &signer,
        encoded_swap: vector<u8>,
        initiator: vector<u8>,
    ) {
        MesonHelpers::is_eth_addr(initiator);
        
        let swap_id = MesonHelpers::get_swap_id(encoded_swap, initiator);
        let (pool_index, until, _) = MesonStates::remove_locked_swap(swap_id);
        assert!(until < timestamp::now_seconds(), ESTILL_IN_LOCK);

        let coins = MesonStates::coins_from_pending<CoinType>(swap_id);
        MesonStates::coins_to_pool<CoinType>(pool_index, coins);
    }


    // Step 3: Release
    // Named consistently with solidity contracts
    public entry fun release<CoinType>(
        _account: &signer, // signer could be anyone
        encoded_swap: vector<u8>,
        signature: vector<u8>,
        initiator: vector<u8>,
    ) {
        MesonHelpers::is_eth_addr(initiator);

        let swap_id = MesonHelpers::get_swap_id(encoded_swap, initiator);
        let (_, until, recipient) = MesonStates::remove_locked_swap(swap_id);
        assert!(until > timestamp::now_seconds(), EALREADY_EXPIRED);

        MesonHelpers::check_release_signature(
            encoded_swap,
            MesonHelpers::eth_address_from_aptos_address(recipient),
            signature,
            initiator
        );

        // Release to recipient
        let coins = MesonStates::coins_from_pending<CoinType>(swap_id);
        // TODO: subtract service fee
        coin::deposit<CoinType>(recipient, coins);
    }
}
