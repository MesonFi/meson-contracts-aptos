module Meson::MesonSwap {
    /* ---------------------------- References ---------------------------- */

    use std::table;
    use std::signer;
    use std::timestamp;
    use std::aptos_hash;
    use Meson::MesonConfig;
    use Meson::MesonTokens;
    use Meson::MesonHelpers;
    use Meson::MesonHelpers::{EncodedSwap, PostedSwap};
    use aptos_token::token;
    use aptos_token::token::{Token};

    const DEPLOYER: address = @Meson;
    const ENOT_DEPLOYER: u64 = 0;
    const ESWAP_ALREADY_EXISTS: u64 = 2;
    const EEXPIRE_TOO_EARLY: u64 = 3;
    const EEXPIRE_TOO_LATE: u64 = 4;
    const EHASH_VALUE_NOT_MATCH: u64 = 8;
    const ESWAP_NOT_EXISTS: u64 = 9;
    const EALREADY_EXPIRED: u64 = 10;
    const ERECIPENT_NOT_MATCH: u64 = 11;

    

    /* ---------------------------- Struct & Constructor ---------------------------- */

    // Contains all the related tables (mappings).
    struct StoredContentOfSwap has key {
        _postedSwaps: table::Table<EncodedSwap, PostedSwap>,
        _cachedToken: table::Table<EncodedSwap, Token>,
    }



    /* ---------------------------- Initialize ---------------------------- */

    public entry fun initializeTable(deployer: &signer) {
        let deployerAddress = signer::address_of(deployer);
        assert!(deployerAddress == DEPLOYER, ENOT_DEPLOYER);
        if(!exists<StoredContentOfSwap>(deployerAddress)) move_to<StoredContentOfSwap>(deployer, StoredContentOfSwap {
            _postedSwaps: table::new<EncodedSwap, PostedSwap>(),
            _cachedToken: table::new<EncodedSwap, Token>(),
        });
    }



    /* ---------------------------- Main Function ---------------------------- */

    // Step 1: postSwap
    public entry fun postSwap(initiatorAccount: &signer, encodedSwap: EncodedSwap, recipient: address) acquires StoredContentOfSwap {
        // Ensure that the `encodedSwap` doesn't exist.
        let _storedContentOfSwap = borrow_global_mut<StoredContentOfSwap>(DEPLOYER);
        let _postedSwaps = &mut _storedContentOfSwap._postedSwaps;
        let _cachedToken = &mut _storedContentOfSwap._cachedToken;
        assert!(!table::contains(_postedSwaps, encodedSwap), ESWAP_ALREADY_EXISTS);
        
        // Assertion about time-lock.
        let inTokenId = MesonHelpers::inTokenIndexFrom(encodedSwap);
        let amount = MesonHelpers::amountFrom(encodedSwap);
        let delta = MesonHelpers::expireTsFrom(encodedSwap) - timestamp::now_seconds();
        assert!(delta > MesonConfig::get_MIN_BOND_TIME_PERIOD(), EEXPIRE_TOO_EARLY);
        assert!(delta < MesonConfig::get_MAX_BOND_TIME_PERIOD(), EEXPIRE_TOO_LATE);

        // Withdraw token entity from the initiator.
        let tokenId = MesonTokens::tokenForIndex(inTokenId);
        let withdrewToken = token::withdraw_token(initiatorAccount, tokenId, amount);

        // Store the `postingValue` in contract.
        let postingValue = MesonHelpers::newPostedSwap(signer::address_of(initiatorAccount), recipient);
        table::add(_postedSwaps, encodedSwap, postingValue);
        table::add(_cachedToken, encodedSwap, withdrewToken);

        /* ============================ To be added ============================ */
        // Emit `postedSwap` event!
        /* ===================================================================== */
    }


    // Step 4. executeSwap
    public entry fun executeSwap(recipientAccount: &signer, encodedSwap: EncodedSwap, keyString: vector<u8>) acquires StoredContentOfSwap {
        // Ensure that the transaction exists.
        let _storedContentOfSwap = borrow_global_mut<StoredContentOfSwap>(DEPLOYER);
        let _postedSwaps = &mut _storedContentOfSwap._postedSwaps;
        let _cachedToken = &mut _storedContentOfSwap._cachedToken;
        assert!(table::contains(_postedSwaps, encodedSwap), ESWAP_NOT_EXISTS);

        // Ensure that the recipient is correct.
        let postingValue = table::remove(_postedSwaps, encodedSwap);
        let (initiator, expectedRecipient) = MesonHelpers::destructPosted(postingValue);
        let recipient = signer::address_of(recipientAccount);
        assert!(recipient==expectedRecipient, ERECIPENT_NOT_MATCH);

        // Ensure that the `keyString` works.
        let calculateHash = aptos_hash::keccak256(keyString);
        let expectedHash = MesonHelpers::hashValueFrom(encodedSwap);
        assert!(calculateHash == expectedHash, EHASH_VALUE_NOT_MATCH);

        // Assertion about time-lock.
        let expireTs = MesonHelpers::expireTsFrom(encodedSwap);
        assert!(expireTs < timestamp::now_seconds() + MesonConfig::get_MIN_BOND_TIME_PERIOD(), EALREADY_EXPIRED);

        // Release the token.
        let fetchedToken = table::remove(_cachedToken, encodedSwap);
        token::direct_deposit_with_opt_in(initiator, fetchedToken);
        
        /* ============================ To be added ============================ */
        // Emit `postedSwap` event!
        /* ===================================================================== */
    }

    
}