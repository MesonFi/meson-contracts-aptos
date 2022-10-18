/// @title MesonPools
/// @notice The class to manage pools for LPs, and perform swap operations on the target 
/// chain side.
/// Methods in this class will be executed when a user wants to swap into this chain.
/// LP pool operations are also provided in this class.
module Meson::MesonPools {
    use std::vector;
    use std::table;
    use std::signer;
    use std::timestamp;
    use aptos_framework::coin;
    use aptos_framework::coin::{Coin};
    use Meson::MesonConfig;
    use Meson::MesonHelpers;
    use Meson::MesonStates;

    const DEPLOYER: address = @Meson;
    const ENOT_DEPLOYER: u64 = 0;
    const ESWAP_ALREADY_EXISTS: u64 = 2;
    const EEXIPRE_TS_IS_SOON: u64 = 6;
    const ELP_POOL_NOT_EXISTS: u64 = 7;
    const EHASH_VALUE_NOT_MATCH: u64 = 8;
    const ESWAP_NOT_EXISTS: u64 = 9;
    const EALREADY_EXPIRED: u64 = 10;


    struct StoredContentOfPools<phantom CoinType> has key {
        _lockedSwaps: table::Table<vector<u8>, LockedSwap>,
        _cachedCoin: table::Table<vector<u8>, Coin<CoinType>>,
    }

    struct LockedSwap has store {
        until: u64,
        poolOwner: address,
        recipient: address,
    }

    fun newLockedSwap(until: u64, poolOwner: address, recipient: address): LockedSwap {
        LockedSwap { until, poolOwner, recipient }
    }

    fun destructLocked(lockedSwap: LockedSwap): (u64, address, address) {
        let LockedSwap { until, poolOwner, recipient } = lockedSwap;
        (until, poolOwner, recipient)
    }

    public entry fun initializeTable<CoinType>(deployer: &signer) {
        let deployerAddress = signer::address_of(deployer);
        assert!(deployerAddress == DEPLOYER, ENOT_DEPLOYER);
        let newContent = StoredContentOfPools<CoinType> {
            _lockedSwaps: table::new<vector<u8>, LockedSwap>(),
            _cachedCoin: table::new<vector<u8>, Coin<CoinType>>(),
        };
        move_to<StoredContentOfPools<CoinType>>(deployer, newContent);
    }


    public entry fun depositAndRegister<CoinType>(lpAccount: &signer, amount: u64) {
        let withdrewCoin = coin::withdraw<CoinType>(lpAccount, amount);
        MesonStates::addLiquidityFirstTime<CoinType>(lpAccount, withdrewCoin);
    }

    public entry fun deposit<CoinType>(lpAccount: &signer, amount: u64) {
        let lpAddress = signer::address_of(lpAccount);
        let withdrewCoin = coin::withdraw<CoinType>(lpAccount, amount);
        MesonStates::addLiquidity<CoinType>(lpAddress, withdrewCoin);
    }

    public entry fun withdraw<CoinType>(lpAccount: &signer, amount: u64) {
        let lpAddress = signer::address_of(lpAccount);
        let withdrewCoin = MesonStates::removeLiquidity<CoinType>(lpAddress, amount);
        coin::deposit<CoinType>(lpAddress, withdrewCoin);
    }


    // Step 2: Lock
    public entry fun lock<CoinType>(
        signerAccount: &signer,
        encoded_swap: vector<u8>,
        recipient: address,
        signature: vector<u8>,
        initiator: vector<u8>
    ) acquires StoredContentOfPools {
        assert!(vector::length(&encoded_swap) == 32, 1);
        assert!(vector::length(&initiator) == 20, 1);
        MesonHelpers::match_protocol_version(encoded_swap);
        MesonHelpers::for_target_chain(encoded_swap);

        // Ensure that the `lockedSwap` doesn't exist
        let swap_id = MesonHelpers::get_swap_id(encoded_swap, initiator);
        let _storedContentOfPools = borrow_global_mut<StoredContentOfPools<CoinType>>(DEPLOYER);
        let _lockedSwaps = &mut _storedContentOfPools._lockedSwaps;
        let _cachedCoin = &mut _storedContentOfPools._cachedCoin;
        assert!(!table::contains(_lockedSwaps, swap_id), ESWAP_ALREADY_EXISTS);

        MesonHelpers::check_request_signature(encoded_swap, signature, initiator);

        let poolOwner = signer::address_of(signerAccount);
        assert!(MesonStates::lpCoinExists<CoinType>(poolOwner), ELP_POOL_NOT_EXISTS);

        let until = timestamp::now_seconds() + MesonConfig::get_LOCK_TIME_PERIOD();
        assert!(until < MesonHelpers::expire_ts_from(encoded_swap) - 300, EEXIPRE_TS_IS_SOON);

        let amount = MesonHelpers::amount_from(encoded_swap)- MesonHelpers::fee_for_lp(encoded_swap);
        let withdrewCoin = MesonStates::removeLiquidity<CoinType>(poolOwner, amount);
        table::add(_cachedCoin, swap_id, withdrewCoin);

        let lockingValue = newLockedSwap(until, poolOwner, recipient);
        table::add(_lockedSwaps, swap_id, lockingValue);
    }


    // Step 3: Release
    public entry fun release<CoinType>(
        _signerAccount: &signer, // signer could be anyone
        encoded_swap: vector<u8>,
        signature: vector<u8>,
        initiator: vector<u8>
    ) acquires StoredContentOfPools {
        assert!(vector::length(&encoded_swap) == 32, 1);
        assert!(vector::length(&initiator) == 20, 1);

        // Ensure that the swap exists
        let swap_id = MesonHelpers::get_swap_id(encoded_swap, initiator);
        let _storedContentOfPools = borrow_global_mut<StoredContentOfPools<CoinType>>(DEPLOYER);
        let _lockedSwaps = &mut _storedContentOfPools._lockedSwaps;
        let _cachedCoin = &mut _storedContentOfPools._cachedCoin;
        assert!(table::contains(_lockedSwaps, swap_id), ESWAP_NOT_EXISTS);

        let lockingValue = table::remove(_lockedSwaps, swap_id);
        let (until, _poolOwner, recipient) = destructLocked(lockingValue);
        assert!(until > timestamp::now_seconds(), EALREADY_EXPIRED);

        MesonHelpers::check_release_signature(encoded_swap, recipient, signature, initiator);

        // Release to recipient
        let fetchedCoin = table::remove(_cachedCoin, swap_id);
        // TODO: subtract service fee
        coin::deposit<CoinType>(recipient, fetchedCoin);
    }
}