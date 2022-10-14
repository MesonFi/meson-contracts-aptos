module Meson::MesonSwap {
    /* ---------------------------- References ---------------------------- */

    use std::table;
    use std::signer;
    use std::timestamp;
    use std::aptos_hash;
    use aptos_framework::coin;
    use aptos_framework::coin::{Coin};
    use Meson::MesonConfig;
    use Meson::MesonHelpers;
    use Meson::MesonHelpers::{EncodedSwap, PostedSwap};

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
    // Each unique coin has a related `StoredContentOfSwap`.
    struct StoredContentOfSwap<phantom CoinType> has key {
        _postedSwaps: table::Table<EncodedSwap, PostedSwap>,
        _cachedCoin: table::Table<EncodedSwap, Coin<CoinType>>,
    }



    /* ---------------------------- Initialize ---------------------------- */

    public entry fun initializeTable<CoinType>(deployer: &signer) {
        let deployerAddress = signer::address_of(deployer);
        assert!(deployerAddress == DEPLOYER, ENOT_DEPLOYER);
        let newContent = StoredContentOfSwap<CoinType> {
            _postedSwaps: table::new<EncodedSwap, PostedSwap>(),
            _cachedCoin: table::new<EncodedSwap, Coin<CoinType>>(),
        };
        move_to<StoredContentOfSwap<CoinType>>(deployer, newContent);
    }



    /* ---------------------------- Main Function ---------------------------- */

    // Step 1: postSwap
    public entry fun postSwap<CoinType>(initiatorAccount: &signer, recipient: address, amount: u64, expireTs: u64, outChain: u64, inChain: u64, lockHash: vector<u8>) acquires StoredContentOfSwap {
        // Ensure that the `encodedSwap` doesn't exist.
        let encodedSwap = MesonHelpers::newEncodedSwap(amount, expireTs, outChain, inChain, lockHash);  // To fixed!!
        let _storedContentOfSwap = borrow_global_mut<StoredContentOfSwap<CoinType>>(DEPLOYER);
        let _postedSwaps = &mut _storedContentOfSwap._postedSwaps;
        let _cachedCoin = &mut _storedContentOfSwap._cachedCoin;
        assert!(!table::contains(_postedSwaps, encodedSwap), ESWAP_ALREADY_EXISTS);
        
        // Assertion about time-lock.
        let amount = MesonHelpers::amountFrom(encodedSwap);
        let delta = MesonHelpers::expireTsFrom(encodedSwap) - timestamp::now_seconds();
        assert!(delta > MesonConfig::get_MIN_BOND_TIME_PERIOD(), EEXPIRE_TOO_EARLY);
        assert!(delta < MesonConfig::get_MAX_BOND_TIME_PERIOD(), EEXPIRE_TOO_LATE);

        // Withdraw coin entity from the initiator.
        let withdrewCoin = coin::withdraw<CoinType>(initiatorAccount, amount);

        // Store the `postingValue` in contract.
        let postingValue = MesonHelpers::newPostedSwap(signer::address_of(initiatorAccount), recipient);
        table::add(_postedSwaps, encodedSwap, postingValue);
        table::add(_cachedCoin, encodedSwap, withdrewCoin);

        /* ============================ To be added ============================ */
        // Emit `postedSwap` event!
        /* ===================================================================== */
    }


    // Step 4. executeSwap
    public entry fun executeSwap<CoinType>(recipientAccount: &signer, keyString: vector<u8>, amount: u64, expireTs: u64, outChain: u64, inChain: u64, lockHash: vector<u8>) acquires StoredContentOfSwap {
        // Ensure that the transaction exists.
        let encodedSwap = MesonHelpers::newEncodedSwap(amount, expireTs, outChain, inChain, lockHash);  // To fixed!!
        let _storedContentOfSwap = borrow_global_mut<StoredContentOfSwap<CoinType>>(DEPLOYER);
        let _postedSwaps = &mut _storedContentOfSwap._postedSwaps;
        let _cachedCoin = &mut _storedContentOfSwap._cachedCoin;
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

        // Release the coin.
        let fetchedCoin = table::remove(_cachedCoin, encodedSwap);
        coin::deposit<CoinType>(initiator, fetchedCoin);
        
        /* ============================ To be added ============================ */
        // Emit `postedSwap` event!
        /* ===================================================================== */
    }

    
}