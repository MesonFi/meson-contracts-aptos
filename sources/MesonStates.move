module Meson::MesonStates {
    /* ---------------------------- References ---------------------------- */

    use std::table;
    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::coin::{Coin};
    // use Meson::MesonCoins::{coinForIndex}; // See the Warning below

    const DEPLOYER: address = @Meson;
    const ENOT_DEPLOYER: u64 = 0;
    const ECOIN_TYPE_ERROR: u64 = 5;

    friend Meson::MesonPools;



    /* ---------------------------- Struct & Constructor ---------------------------- */

    // Contains all the related tables (mappings).
    struct StoredContentOfStates<phantom CoinType> has key {
        coinEntityPool: table::Table<address, Coin<CoinType>>,
    }



    /* ---------------------------- Initialize ---------------------------- */

    public entry fun initializeTable<CoinType>(deployer: &signer) {
        let deployerAddress = signer::address_of(deployer);
        assert!(deployerAddress == DEPLOYER, ENOT_DEPLOYER);

        let newContent = StoredContentOfStates<CoinType> {
            coinEntityPool: table::new<address, Coin<CoinType>>(),
        };
        move_to<StoredContentOfStates<CoinType>>(deployer, newContent);

    }



    /* ---------------------------- Utils Function ---------------------------- */

    public fun lpCoinBalance<CoinType>(lp: address): u64 acquires StoredContentOfStates {
        let storedContentOfStates = borrow_global<StoredContentOfStates<CoinType>>(DEPLOYER);
        let coinEntityRef = table::borrow(&storedContentOfStates.coinEntityPool, lp);
        coin::value<CoinType>(coinEntityRef)
    }

    public fun lpCoinExists<CoinType>(lp: address): bool acquires StoredContentOfStates {
        let storedContentOfStates = borrow_global<StoredContentOfStates<CoinType>>(DEPLOYER);
        table::contains(&storedContentOfStates.coinEntityPool, lp)
    }

    public(friend) fun addLiquidityFirstTime<CoinType>(lp: address, coinToAdd: Coin<CoinType>) acquires StoredContentOfStates {
        let storedContentOfStates = borrow_global_mut<StoredContentOfStates<CoinType>>(DEPLOYER);
        table::add(&mut storedContentOfStates.coinEntityPool, lp, coinToAdd);   // If the lp already exists, this sentence will not execute successly because the existed Coin doesn't have ability `drop`. So we don't have to add an assert sentence.
    }

    public(friend) fun addLiquidity<CoinType>(lp: address, coinToMerge: Coin<CoinType>) acquires StoredContentOfStates {
        let storedContentOfStates = borrow_global_mut<StoredContentOfStates<CoinType>>(DEPLOYER);
        let coinEntityMutRef = table::borrow_mut(&mut storedContentOfStates.coinEntityPool, lp);
        coin::merge<CoinType>(coinEntityMutRef, coinToMerge);
    }

    public(friend) fun removeLiquidity<CoinType>(lp: address, amountToRemove: u64): Coin<CoinType> acquires StoredContentOfStates {
        let storedContentOfStates = borrow_global_mut<StoredContentOfStates<CoinType>>(DEPLOYER);
        let coinEntityMutRef = table::borrow_mut(&mut storedContentOfStates.coinEntityPool, lp);
        coin::extract<CoinType>(coinEntityMutRef, amountToRemove)
    }

}