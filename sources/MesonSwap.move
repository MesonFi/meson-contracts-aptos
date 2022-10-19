/// @title MesonSwap
/// @notice The class to receive and process swap requests on the initial chain side.
/// Methods in this class will be executed by swap initiators or LPs
/// on the initial chain of swaps.
module Meson::MesonSwap {
    use std::signer;
    use std::vector;
    use std::timestamp;
    use aptos_framework::coin;
    use Meson::MesonHelpers;
    use Meson::MesonStates;

    const EEXPIRE_TOO_EARLY: u64 = 3;
    const EEXPIRE_TOO_LATE: u64 = 4;
    const ESTILL_IN_LOCK: u64 = 11;


    // Named consistently with solidity contracts
    /// `encoded_swap` in format of `version:uint8|amount:uint40|salt:uint80|fee:uint40|expire_ts:uint40|out_chain:uint16|out_coin:uint8|in_chain:uint16|in_coin:uint8`
    ///   version: Version of encoding
    ///   amount: The amount of coins of this swap, always in decimal 6. The amount of a swap is capped at $100k so it can be safely encoded in uint48;
    ///   salt: The salt value of this swap, carrying some information below:
    ///     salt & 0x80000000000000000000 == true => will release to an owa address, otherwise a smart contract;
    ///     salt & 0x40000000000000000000 == true => will waive *service fee*;
    ///     salt & 0x08000000000000000000 == true => use *non-typed signing* (some wallets such as hardware wallets don't support EIP-712v1);
    ///     salt & 0x0000ffffffffffffffff: customized data that can be passed to integrated 3rd-party smart contract;
    ///   fee: The fee given to LPs (liquidity providers). An extra service fee maybe charged afterwards;
    ///   expire_ts: The expiration time of this swap on the initial chain. The LP should `executeSwap` and receive his funds before `expire_ts`;
    ///   out_chain: The target chain of a cross-chain swap (given by the last 2 bytes of SLIP-44);
    ///   out_coin: Also named `out_token` for EVM chains. The index of the coin on the target chain;
    ///   in_chain: The initial chain of a cross-chain swap (given by the last 2 bytes of SLIP-44);
    ///   in_coin: Also named `out_token` for EVM chains. The index of the coin on the initial chain.
    public entry fun postSwap<CoinType>(
        account: &signer,
        encoded_swap: vector<u8>,
        signature: vector<u8>, // must be signed by `initiator`
        initiator: vector<u8>, // an eth address of (20 bytes), the signer to sign for release
        pool_index: u64,
    ) {
        MesonHelpers::is_encoded_valid(encoded_swap);
        MesonHelpers::for_initial_chain(encoded_swap);
        MesonStates::match_coin_type<CoinType>(MesonHelpers::in_coin_index_from(encoded_swap));
        MesonHelpers::is_eth_addr(initiator);

        let amount = MesonHelpers::amount_from(encoded_swap);
        MesonHelpers::assert_amount_within_max(amount);

        // Assertion about time-lock.
        let delta = MesonHelpers::expire_ts_from(encoded_swap) - timestamp::now_seconds();
        assert!(delta > MesonHelpers::get_MIN_BOND_TIME_PERIOD(), EEXPIRE_TOO_EARLY);
        assert!(delta < MesonHelpers::get_MAX_BOND_TIME_PERIOD(), EEXPIRE_TOO_LATE);

        MesonHelpers::check_request_signature(encoded_swap, signature, initiator);

        MesonStates::add_posted_swap(encoded_swap, pool_index, initiator, signer::address_of(account));
        
        let coins = coin::withdraw<CoinType>(account, amount);
        vector::push_back(&mut encoded_swap, 0xff); // so it cannot be identical to a swap_id
        MesonStates::coins_to_pending(encoded_swap, coins);
    }


    // Named consistently with solidity contracts
    public entry fun cancelSwap<CoinType>(_account: &signer, encoded_swap: vector<u8>) {
        let expire_ts = MesonHelpers::expire_ts_from(encoded_swap);
        assert!(expire_ts < timestamp::now_seconds(), ESTILL_IN_LOCK);

        let (_, _, from_address) = MesonStates::remove_posted_swap(encoded_swap);

        vector::push_back(&mut encoded_swap, 0xff); // so it cannot be identical to a swap_id
        let coins = MesonStates::coins_from_pending(encoded_swap);
        coin::deposit<CoinType>(from_address, coins);
    }


    // Named consistently with solidity contracts
    public entry fun executeSwap<CoinType>(
        _account: &signer, // signer could be anyone
        encoded_swap: vector<u8>,
        signature: vector<u8>,
        recipient: vector<u8>,
        deposit_to_pool: bool,
    ) {
        let (pool_index, initiator, _) = MesonStates::remove_posted_swap(encoded_swap);
        assert!(pool_index != 0, 1);

        MesonHelpers::check_release_signature(encoded_swap, recipient, signature, initiator);

        vector::push_back(&mut encoded_swap, 0xff); // so it cannot be identical to a swap_id
        let coins = MesonStates::coins_from_pending(encoded_swap);
        if (deposit_to_pool) {
            MesonStates::coins_to_pool<CoinType>(pool_index, coins);
        } else {
            coin::deposit<CoinType>(MesonStates::owner_of_pool(pool_index), coins);
        }
    }
}
