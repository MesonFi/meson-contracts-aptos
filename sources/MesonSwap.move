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
    use aptos_token::token::{TokenId, Token};

    const DEPLOYER: address = @Meson;
    const ENOT_DEPLOYER: u64 = 0;
    const ESWAP_ALREADY_EXISTS: u64 = 2;
    const EEXPIRE_TOO_EARLY: u64 = 3;
    const EEXPIRE_TOO_LATE: u64 = 4;

    
    // Contains all the related tables (mappings).
    struct StoredContentOfSwap has key {
        _postedSwaps: table::Table<EncodedSwap, PostedSwap>,
    }



    /* ---------------------------- Main Function ---------------------------- */

    public entry fun initializeTable(account: &signer) {
        let deployer = signer::address_of(account);
        assert!(deployer == DEPLOYER, ENOT_DEPLOYER);

        if(!exists<StoredContentOfSwap>(deployer)) move_to<StoredContentOfSwap>(account, StoredContentOfSwap {
            _postedSwaps: table::new<EncodedSwap, PostedSwap>(),
        });
    }

    // Step 1: postSwap
    public entry fun postSwap(initiator: &signer, encodedSwap: EncodedSwap, lp: address) acquires StoredContentOfSwap {
        // Ensure that the `encodedSwap` doesn't exist.
        let _postedSwaps = &mut borrow_global_mut<StoredContentOfSwap>(DEPLOYER)._postedSwaps;
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
        let postingValue = MesonHelpers::newPostedSwap(signer::address_of(initiator), lp, withdrew_token);
        table::add(_postedSwaps, encodedSwap, postingValue);

        /* ============================ To be added ============================ */
        // Emit `postedSwap` event!
        /* ===================================================================== */
    }
}