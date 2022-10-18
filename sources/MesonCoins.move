module Meson::MesonCoins {
    /* ---------------------------- References ---------------------------- */

    use std::signer;
    use std::vector;
    use aptos_std::type_info::{TypeInfo, type_of};

    const ENOT_DEPLOYER: u64 = 0;
    const EALREADY_IN_COIN_LIST: u64 = 1;

    struct StoredContentOfCoin has key {
        _coinList: vector<TypeInfo>,
    }



    /* ---------------------------- Main Function ---------------------------- */

    // Add new supported coin into meson contract.
    public entry fun addSupportCoin<CoinType>(deployerAccount: &signer): u64 acquires StoredContentOfCoin {
        let deployerAddress = signer::address_of(deployerAccount);
        assert!(deployerAddress == @Meson, ENOT_DEPLOYER);

        if(!exists<StoredContentOfCoin>(deployerAddress)) move_to<StoredContentOfCoin>(deployerAccount, StoredContentOfCoin {
            _coinList: vector::empty<TypeInfo>(),
        });

        // Add new coin information to the supported list, and returns the corresponding ID.
        let coinInfo = type_of<CoinType>();
        let coinList = &mut borrow_global_mut<StoredContentOfCoin>(deployerAddress)._coinList;
        let i = 0;
        while (i < vector::length(coinList)) {
            assert!(coinInfo != *vector::borrow(coinList, i), EALREADY_IN_COIN_LIST);
            i = i + 1;
        };
        vector::push_back(coinList, coinInfo);
        vector::length(coinList)
    }



    /* ---------------------------- Utils Function ---------------------------- */
    
    public fun coinForIndex(coinIndex: u64): TypeInfo acquires StoredContentOfCoin {
        *vector::borrow(&borrow_global<StoredContentOfCoin>(@Meson)._coinList, coinIndex)
    }

}