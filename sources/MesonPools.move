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

    const EPOOL_INDEX_CANNOT_BE_ZERO: u64 = 16;
    const EPOOL_INDEX_MISMATCH: u64 = 17;
   
    const ESWAP_EXIPRE_TS_IS_SOON: u64 = 46;
    const ESWAP_STILL_IN_LOCK: u64 = 47;
    const ESWAP_PASSED_LOCK_PERIOD: u64 = 48;


    // Named consistently with solidity contracts
    public entry fun depositAndRegister<CoinType>(sender: &signer, amount: u64, pool_index: u64) {
        let sender_addr = signer::address_of(sender);
        MesonStates::register_pool_index(pool_index, sender_addr);
        let coins = coin::withdraw<CoinType>(sender, amount);
        MesonStates::coins_to_pool<CoinType>(pool_index, coins);
    }

    // Named consistently with solidity contracts
    public entry fun deposit<CoinType>(sender: &signer, amount: u64, pool_index: u64) {
        let sender_addr = signer::address_of(sender);
        assert!(pool_index == MesonStates::pool_index_of(sender_addr), EPOOL_INDEX_MISMATCH);
        let coins = coin::withdraw<CoinType>(sender, amount);
        MesonStates::coins_to_pool<CoinType>(pool_index, coins);
    }

    // Named consistently with solidity contracts
    public entry fun withdraw<CoinType>(sender: &signer, amount: u64, pool_index: u64) {
        let sender_addr = signer::address_of(sender);
        assert!(pool_index == MesonStates::pool_index_if_owner(sender_addr), EPOOL_INDEX_MISMATCH);
        let coins = MesonStates::coins_from_pool<CoinType>(pool_index, amount);
        coin::deposit<CoinType>(sender_addr, coins);
    }

    // Named consistently with solidity contracts
    public entry fun addAuthorizedAddr(sender: &signer, addr: address) {
        let sender_addr = signer::address_of(sender);
        let pool_index = MesonStates::pool_index_if_owner(sender_addr);
        MesonStates::add_authorized(pool_index, addr);
    }

    // Named consistently with solidity contracts
    public entry fun removeAuthorizedAddr(sender: &signer, addr: address) {
        let sender_addr = signer::address_of(sender);
        let pool_index = MesonStates::pool_index_if_owner(sender_addr);
        MesonStates::remove_authorized(pool_index, addr);
    }

    // Named consistently with solidity contracts
    public entry fun transferPoolOwner(sender: &signer, addr: address) {
        let sender_addr = signer::address_of(sender);
        let pool_index = MesonStates::pool_index_if_owner(sender_addr);
        MesonStates::transfer_pool_owner(pool_index, addr);
    }


    // Named consistently with solidity contracts
    public entry fun lock<CoinType>(
        sender: &signer,
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
        assert!(until < MesonHelpers::expire_ts_from(encoded_swap) - 300, ESWAP_EXIPRE_TS_IS_SOON);

        let pool_index = MesonStates::pool_index_of(signer::address_of(sender));
        assert!(pool_index != 0, EPOOL_INDEX_CANNOT_BE_ZERO);

        MesonHelpers::check_request_signature(encoded_swap, signature, initiator);

        let swap_id = MesonHelpers::get_swap_id(encoded_swap, initiator);
        let amount = MesonHelpers::amount_from(encoded_swap) - MesonHelpers::fee_for_lp(encoded_swap);

        let coins = MesonStates::coins_from_pool<CoinType>(pool_index, amount);
        MesonStates::coins_to_pending<CoinType>(swap_id, coins);

        MesonStates::add_locked_swap(swap_id, pool_index, until, recipient);
    }


    // Named consistently with solidity contracts
    public entry fun unlock<CoinType>(
        _sender: &signer, // signer could be anyone
        encoded_swap: vector<u8>,
        initiator: vector<u8>,
    ) {
        MesonHelpers::is_eth_addr(initiator);
        
        let swap_id = MesonHelpers::get_swap_id(encoded_swap, initiator);
        let (pool_index, until, _) = MesonStates::remove_locked_swap(swap_id);
        assert!(until < timestamp::now_seconds(), ESWAP_STILL_IN_LOCK);

        let coins = MesonStates::coins_from_pending<CoinType>(swap_id);
        MesonStates::coins_to_pool<CoinType>(pool_index, coins);
    }


    // Named consistently with solidity contracts
    public entry fun release<CoinType>(
        sender: &signer,
        encoded_swap: vector<u8>,
        signature: vector<u8>,
        initiator: vector<u8>,
    ) {
        MesonHelpers::is_eth_addr(initiator);

        let waived = MesonHelpers::fee_waived(encoded_swap);
        if (waived) {
            // for fee waived swap, signer needs to be the premium manager
            MesonStates::assert_is_premium_manager(signer::address_of(sender));
        }; // otherwise, signer could be anyone

        let swap_id = MesonHelpers::get_swap_id(encoded_swap, initiator);
        let (_, until, recipient) = MesonStates::remove_locked_swap(swap_id);
        assert!(until > timestamp::now_seconds(), ESWAP_PASSED_LOCK_PERIOD);

        MesonHelpers::check_release_signature(
            encoded_swap,
            MesonHelpers::eth_address_from_aptos_address(recipient),
            signature,
            initiator
        );

        // Release to recipient
        let coins = MesonStates::coins_from_pending<CoinType>(swap_id);
        if (!waived) {
            let service_fee = coin::extract<CoinType>(&mut coins, MesonHelpers::service_fee(encoded_swap));
            MesonStates::coins_to_pool<CoinType>(0, service_fee);
        };
        coin::deposit<CoinType>(recipient, coins);
    }
}
