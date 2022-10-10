
module Meson::MesonHelpers {
    /* ---------------------------- References ---------------------------- */

    // We merge the `MesonSwap` file into `MesonHelpers`.
    use std::signer;
    use std::vector;
    use std::string::String;
    use aptos_token::token::{TokenId, create_token_id_raw};
    
    friend Meson::MesonSwap;

    const DEPLOYER: address = @Meson;
    const ENOT_DEPLOYER: u64 = 0;
    const EALREADY_IN_TOKEN_LIST: u64 = 1;



    /* ---------------------------- Struct & Constructor ---------------------------- */

    // `encodedSwap` is in format of `amount:uint48|salt:uint80|fee:uint40|expireTs:uint40|outChain:uint16|outToken:uint8|inChain:uint16|inToken:uint8` in solidity.
    // However, it's not convenient in Move to obtain a slice in bytes and convert it to uint. So we use a struct `EncodedSwap` to store the transaction information.
    struct EncodedSwap has copy, drop {
        amount: u64,
        salt: vector<u8>,
        fee: u64,
        expireTs: u64,
        outChain: u64,
        outToken: u8,
        inChain: u64,
        inToken: u8,
    }

    // `postedSwap` is in format of `initiator:address|poolIndex:uint40` in solidity.
    struct PostedSwap has store, drop {
        initiator: address,
        poolIndex: u64,
    }

    // Contains all the related tables (mappings).
    struct StoredContentOfToken has key {
        _tokenList: vector<TokenId>,
    }

    // Create a new `EncodedSwap` instance
    public(friend) fun newEncodedSwap(amount: u64, salt: vector<u8>, fee: u64, expireTs: u64, outChain: u64, outToken: u8, inChain: u64, inToken: u8): EncodedSwap {
        EncodedSwap { amount, salt, fee, expireTs, outChain, outToken, inChain, inToken }
    }

    // Create a new `PostedSwap` instance
    public(friend) fun newPostedSwap(initiator: address, poolIndex: u64): PostedSwap {
        PostedSwap { initiator, poolIndex }
    }



    /* ---------------------------- Main Function ---------------------------- */

    // Add new supported token into meson contract.
    public entry fun addSupportToken(
        account: &signer,
        creator: address,
        collection: String,
        name: String,
        property_version: u64,
    ): u64 acquires StoredContentOfToken {
        let deployer = signer::address_of(account);
        assert!(deployer == DEPLOYER, ENOT_DEPLOYER);

        if(!exists<StoredContentOfToken>(deployer)) move_to<StoredContentOfToken>(account, StoredContentOfToken {
            _tokenList: vector::empty<TokenId>(),
        });

        // Add new token to the supported list, and returns the corresponding ID.
        let tokenId: TokenId = create_token_id_raw(creator, collection, name, property_version);
        let tokenList = &mut borrow_global_mut<StoredContentOfToken>(deployer)._tokenList;
        let i = 0;
        while (i < vector::length(tokenList)) {
            assert!(tokenId != *vector::borrow(tokenList, i), EALREADY_IN_TOKEN_LIST);
        };
        vector::push_back(tokenList, tokenId);
        vector::length(tokenList)
    }



    /* ---------------------------- Utils Function ---------------------------- */

    // Functions to obtain values from EncodedSwap
    public(friend) fun amountFrom(encodedSwap: EncodedSwap): u64 {
        encodedSwap.amount
    }

    public(friend) fun expireTsFrom(encodedSwap: EncodedSwap): u64 {
        encodedSwap.expireTs
    }

    public(friend) fun inTokenIndexFrom(encodedSwap: EncodedSwap): u8 {
        encodedSwap.inToken
    }

    public(friend) fun outTokenIndexFrom(encodedSwap: EncodedSwap): u8 {
        encodedSwap.outToken
    }

    public(friend) fun initiatorFromPosted(postingValue: PostedSwap): address {
        postingValue.initiator
    }

    public(friend) fun poolIndexFromPosted(postingValue: PostedSwap): u64 {
        postingValue.poolIndex
    }

}