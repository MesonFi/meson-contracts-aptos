module Meson::MesonSwap {
    /* ---------------------------- References ---------------------------- */

    use std::table;
    use std::signer;
    use std::timestamp;
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
    public entry fun postSwap(initiator: &signer, encodedSwap: EncodedSwap, poolIndex: u64) acquires StoredContentOfSwap {
        // Ensure that the `encodedSwap` doesn't exist.
        let _storedContentOfSwap = borrow_global_mut<StoredContentOfSwap>(DEPLOYER);
        let _postedSwaps = &mut _storedContentOfSwap._postedSwaps;
        let _cachedToken = &mut _storedContentOfSwap._cachedToken;
        assert!(!table::contains(_postedSwaps, encodedSwap), ESWAP_ALREADY_EXISTS);
        
        let inTokenId = MesonHelpers::inTokenIndexFrom(encodedSwap);
        let amount = MesonHelpers::amountFrom(encodedSwap);
        let delta = MesonHelpers::expireTsFrom(encodedSwap) - timestamp::now_seconds();
        assert!(delta > MesonConfig::get_MIN_BOND_TIME_PERIOD(), EEXPIRE_TOO_EARLY);
        assert!(delta < MesonConfig::get_MAX_BOND_TIME_PERIOD(), EEXPIRE_TOO_LATE);

        // Withdraw token entity from the initiator.
        let tokenId = MesonTokens::tokenForIndex(inTokenId);
        let withdrew_token = token::withdraw_token(initiator, tokenId, amount);

        // Store the `postedSwap` in contract.
        let postingValue = MesonHelpers::newPostedSwap(signer::address_of(initiator), poolIndex);
        table::add(_postedSwaps, encodedSwap, postingValue);
        table::add(_cachedToken, encodedSwap, withdrew_token);

        /* ============================ To be added ============================ */
        // Emit `postedSwap` event!
        /* ===================================================================== */
    }

    
}