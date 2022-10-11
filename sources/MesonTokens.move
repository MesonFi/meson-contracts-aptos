module Meson::MesonTokens {
    /* ---------------------------- References ---------------------------- */

    use std::signer;
    use std::vector;
    use std::string::String;
    use aptos_token::token::{TokenId, create_token_id_raw};

    const ENOT_DEPLOYER: u64 = 0;
    const EALREADY_IN_TOKEN_LIST: u64 = 1;

    // Contains all the related tables (mappings).
    struct StoredContentOfToken has key {
        _tokenList: vector<TokenId>,
    }



    /* ---------------------------- Main Function ---------------------------- */
    // Add new supported token into meson contract.
    public entry fun addSupportToken(
        deployerAccount: &signer,
        creator: address,
        collection: String,
        name: String,
        property_version: u64,
    ): u64 acquires StoredContentOfToken {
        let deployerAddress = signer::address_of(deployerAccount);
        assert!(deployerAddress == @Meson, ENOT_DEPLOYER);

        if(!exists<StoredContentOfToken>(deployerAddress)) move_to<StoredContentOfToken>(deployerAccount, StoredContentOfToken {
            _tokenList: vector::empty<TokenId>(),
        });

        // Add new token to the supported list, and returns the corresponding ID.
        let tokenId: TokenId = create_token_id_raw(creator, collection, name, property_version);
        let tokenList = &mut borrow_global_mut<StoredContentOfToken>(deployerAddress)._tokenList;
        let i = 0;
        while (i < vector::length(tokenList)) {
            assert!(tokenId != *vector::borrow(tokenList, i), EALREADY_IN_TOKEN_LIST);
        };
        vector::push_back(tokenList, tokenId);
        vector::length(tokenList)
    }



    /* ---------------------------- Utils Function ---------------------------- */
    public fun tokenForIndex(tokenIndex: u64): TokenId acquires StoredContentOfToken {
        *vector::borrow(&borrow_global<StoredContentOfToken>(@Meson)._tokenList, tokenIndex)
    }

}