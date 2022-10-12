module Meson::MesonStates {
    /* ---------------------------- References ---------------------------- */

    use std::table;
    use std::signer;
    use aptos_token::token::{Token, get_token_amount, merge, split};
    // use Meson::MesonTokens::{tokenForIndex}; // See the Warning below

    const DEPLOYER: address = @Meson;
    const ENOT_DEPLOYER: u64 = 0;
    const ETOKEN_TYPE_ERROR: u64 = 5;

    friend Meson::MesonPools;



    /* ---------------------------- Struct & Constructor ---------------------------- */

    // We discard `poolIndex` because the mapping between lp address and pool index cannot save gas fee.
    struct TokenIndexAndLP has copy, drop {
        tokenIndex: u64,
        lp: address,
    }

    // Contains all the related tables (mappings).
    struct StoredContentOfStates has key {
        tokenEntityPool: table::Table<TokenIndexAndLP, Token>,
    }

    public(friend) fun newTokenIndexAndLP(tokenIndex: u64, lp: address): TokenIndexAndLP {
        TokenIndexAndLP { tokenIndex, lp }
    }

    

    /* ---------------------------- Initialize ---------------------------- */

    public entry fun initializeTable(deployer: &signer) {
        let deployerAddress = signer::address_of(deployer);
        assert!(deployerAddress == DEPLOYER, ENOT_DEPLOYER);
        if(!exists<StoredContentOfStates>(deployerAddress)) move_to<StoredContentOfStates>(deployer, StoredContentOfStates {
            tokenEntityPool: table::new<TokenIndexAndLP, Token>(),
        });
    }



    /* ---------------------------- Utils Function ---------------------------- */

    public fun lpTokenBalance(tokenIndex: u64, lp: address): u64 acquires StoredContentOfStates {
        let storedContentOfStates = borrow_global<StoredContentOfStates>(DEPLOYER);
        let tokenEntityRef = table::borrow(&storedContentOfStates.tokenEntityPool, TokenIndexAndLP { tokenIndex, lp });
        get_token_amount(tokenEntityRef)
    }

    public fun lpTokenExists(tokenIndex: u64, lp: address): bool acquires StoredContentOfStates {
        let storedContentOfStates = borrow_global<StoredContentOfStates>(DEPLOYER);
        table::contains(&storedContentOfStates.tokenEntityPool, TokenIndexAndLP { tokenIndex, lp })
    }

    public(friend) fun addLiquidityFirstTime(tokenIndex: u64, lp: address, tokenToAdd: Token) acquires StoredContentOfStates {
        /* ==================== Warning! ==================== */
        // The function token_token_id cannot be used *due to an unknown error*. Therefore, this assert sentence cannot run, and we should deannotated this sentence when the unknown error is fixed.
        // assert!(tokenForIndex(tokenIndex) == get_token_id(&tokenToAdd), ETOKEN_TYPE_ERROR);
        
        let storedContentOfStates = borrow_global_mut<StoredContentOfStates>(DEPLOYER);
        table::add(&mut storedContentOfStates.tokenEntityPool, TokenIndexAndLP { tokenIndex, lp }, tokenToAdd);   // If the tokenIndexAndLP already exists, this sentence will not execute successly because the existed Token doesn't have ability `drop`. So we don't have to add an assert sentence.
    }

    public(friend) fun addLiquidity(tokenIndex: u64, lp: address, tokenToMerge: Token) acquires StoredContentOfStates {
        let storedContentOfStates = borrow_global_mut<StoredContentOfStates>(DEPLOYER);
        let tokenEntityMutRef = table::borrow_mut(&mut storedContentOfStates.tokenEntityPool, TokenIndexAndLP { tokenIndex, lp });
        merge(tokenEntityMutRef, tokenToMerge);
    }

    public(friend) fun removeLiquidity(tokenIndex: u64, lp: address, amountToRemove: u64): Token acquires StoredContentOfStates {
        let storedContentOfStates = borrow_global_mut<StoredContentOfStates>(DEPLOYER);
        let tokenEntityMutRef = table::borrow_mut(&mut storedContentOfStates.tokenEntityPool, TokenIndexAndLP { tokenIndex, lp });
        split(tokenEntityMutRef, amountToRemove)
    }

}