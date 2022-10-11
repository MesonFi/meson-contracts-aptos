module Meson::MesonStates {
    /* ---------------------------- References ---------------------------- */

    use std::table;
    use std::signer;
    use aptos_token::token::{Token, get_token_amount};

    const DEPLOYER: address = @Meson;
    const ENOT_DEPLOYER: u64 = 0;



    /* ---------------------------- Struct & Constructor ---------------------------- */

    struct TokenIdAndPoolId has copy, drop {
        tokenId: u64,
        poolId: u64,
    }

    // Contains all the related tables (mappings).
    struct StoredContentOfStates has key {
        poolOfAuthorizedAddr: table::Table<address, u64>,
        ownerOfPool: table::Table<u64, address>,
        tokenEntityPool: table::Table<TokenIdAndPoolId, Token>,
    }

    public(friend) fun newTokenIdAndPoolId(tokenId: u64, poolId: u64): TokenIdAndPoolId {
        TokenIdAndPoolId { tokenId, poolId }
    }

    

    /* ---------------------------- Initialize ---------------------------- */

    public entry fun initializeTable(deployer: &signer) {
        let deployerAddress = signer::address_of(deployer);
        assert!(deployerAddress == DEPLOYER, ENOT_DEPLOYER);
        if(!exists<StoredContentOfStates>(deployerAddress)) move_to<StoredContentOfStates>(deployer, StoredContentOfStates {
            poolOfAuthorizedAddr: table::new<address, u64>(),
            ownerOfPool: table::new<u64, address>(),
            tokenEntityPool: table::new<TokenIdAndPoolId, Token>(),
        });
    }



    /* ---------------------------- Utils Function ---------------------------- */

    public fun poolTokenBalance(tokenId: u64, lp: address): u64 acquires StoredContentOfStates {
        let storedContentOfStates = borrow_global<StoredContentOfStates>(DEPLOYER);
        let poolId = *table::borrow(&storedContentOfStates.poolOfAuthorizedAddr, lp);
        let tokenIdAndPoolId = TokenIdAndPoolId { tokenId, poolId };
        let tokenEntityRef = table::borrow(&storedContentOfStates.tokenEntityPool, tokenIdAndPoolId);
        get_token_amount(tokenEntityRef)
    }

}