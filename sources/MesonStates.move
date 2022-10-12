module Meson::MesonStates {
    /* ---------------------------- References ---------------------------- */

    use std::table;
    use std::signer;
    use aptos_token::token::{Token, get_token_amount};

    const DEPLOYER: address = @Meson;
    const ENOT_DEPLOYER: u64 = 0;



    /* ---------------------------- Struct & Constructor ---------------------------- */

    // We discard `poolIndex` because the mapping between lp address and pool index cannot save gas fee.
    struct TokenIdAndLP has copy, drop {
        tokenId: u64,
        lp: address,
    }

    // Contains all the related tables (mappings).
    struct StoredContentOfStates has key {
        tokenEntityPool: table::Table<TokenIdAndLP, Token>,
    }

    public(friend) fun newTokenIdAndLP(tokenId: u64, lp: address): TokenIdAndLP {
        TokenIdAndLP { tokenId, lp }
    }

    

    /* ---------------------------- Initialize ---------------------------- */

    public entry fun initializeTable(deployer: &signer) {
        let deployerAddress = signer::address_of(deployer);
        assert!(deployerAddress == DEPLOYER, ENOT_DEPLOYER);
        if(!exists<StoredContentOfStates>(deployerAddress)) move_to<StoredContentOfStates>(deployer, StoredContentOfStates {
            tokenEntityPool: table::new<TokenIdAndLP, Token>(),
        });
    }



    /* ---------------------------- Utils Function ---------------------------- */

    public fun LPTokenBalance(tokenId: u64, lp: address): u64 acquires StoredContentOfStates {
        let storedContentOfStates = borrow_global<StoredContentOfStates>(DEPLOYER);
        let tokenEntityRef = table::borrow(&storedContentOfStates.tokenEntityPool, TokenIdAndLP { tokenId, lp });
        get_token_amount(tokenEntityRef)
    }

}