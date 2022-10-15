module Meson::MesonSwap {
    /* ---------------------------- References ---------------------------- */

    use std::string;
    use std::table;
    use std::signer;
    use std::timestamp;
    use std::aptos_hash;
    use aptos_std::from_bcs // not sure
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

    
    const EINVALID_ENCODED_LENGTH_32: u64 = 33;
    const EINVALID_ENCODED_LENGTH_16: u64 = 34;
    const EINVALID_ENCODED_DECODING: u64 = 35;

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
    public entry fun postSwap<CoinType>(
        initiatorAccount: &signer,
        poolOwner: address,
        encoded0: u128,
        encoded1: u128,
        encoded: vector<u8>,
        lockHash: vector<u8>
    ) acquires StoredContentOfSwap {
        assert!(length(encoded) == 32, EINVALID_ENCODED_LENGTH_32);

        let x = from_bcs::to_u128(encoded);
        assert!(x == encoded0, EINVALID_ENCODED_DECODING_0);

        let part = string::internal_sub_string(encoded, 16, 32);
        assert!(length(part) == 16, EINVALID_ENCODED_LENGTH_16);
        let y = from_bcs::to_u128(part);
        assert!(y == encoded1, EINVALID_ENCODED_DECODING_1);

        // as will take lower bits and disregard upper bits
        let version: u8 = (encoded0 >> 120) as u8;
        let amount: u64 = (encoded0 >> 80) as u64 & 0xFFFFFFFFFFu64;
        let expireTs: u64 = (encoded1 >> 48) as u64 & 0xFFFFFFFFFFu64;
        let inChain: u16 = (encoded1 >> 8) as u16;
        let outChain: u16 = (encoded1 >> 32) as u16;

        // Ensure that the `encodedSwap` doesn't exist.
        let encodedSwap = MesonHelpers::newEncodedSwap(amount, expireTs, outChain, inChain, lockHash);  // To fixed!!
        let _storedContentOfSwap = borrow_global_mut<StoredContentOfSwap<CoinType>>(DEPLOYER);
        let _postedSwaps = &mut _storedContentOfSwap._postedSwaps;
        let _cachedCoin = &mut _storedContentOfSwap._cachedCoin;
        assert!(!table::contains(_postedSwaps, encodedSwap), ESWAP_ALREADY_EXISTS);
        
        // Assertion about time-lock.
        let delta = MesonHelpers::expireTsFrom(encodedSwap) - timestamp::now_seconds();
        assert!(delta > MesonConfig::get_MIN_BOND_TIME_PERIOD(), EEXPIRE_TOO_EARLY);
        assert!(delta < MesonConfig::get_MAX_BOND_TIME_PERIOD(), EEXPIRE_TOO_LATE);

        // Withdraw coin entity from the initiator.
        // If initiatorAccount is not the signer, can we withdraw coins from it?
        let withdrewCoin = coin::withdraw<CoinType>(initiatorAccount, amount);

        // Store the `postingValue` in contract.
        let postingValue = MesonHelpers::newPostedSwap(signer::address_of(initiatorAccount), poolOwner);
        table::add(_postedSwaps, encodedSwap, postingValue);
        table::add(_cachedCoin, encodedSwap, withdrewCoin);

        /* ============================ To be added ============================ */
        // Emit `postedSwap` event!
        /* ===================================================================== */
    }


    // Step 4. executeSwap
    public entry fun executeSwap<CoinType>(
        signerAccount: &signer, // signer could be anyone
        initiator: address,
        recipient: address, // this is used when check signature
        keyString: vector<u8>,
        amount: u64, expireTs: u64, outChain: u16, inChain: u16,
        lockHash: vector<u8>,
        depositToPool: bool
    ) acquires StoredContentOfSwap {
        // Ensure that the transaction exists.
        let encodedSwap = MesonHelpers::newEncodedSwap(amount, expireTs, outChain, inChain, lockHash);  // To fixed!!
        let _storedContentOfSwap = borrow_global_mut<StoredContentOfSwap<CoinType>>(DEPLOYER);
        let _postedSwaps = &mut _storedContentOfSwap._postedSwaps;
        let _cachedCoin = &mut _storedContentOfSwap._cachedCoin;
        assert!(table::contains(_postedSwaps, encodedSwap), ESWAP_NOT_EXISTS);

        let postingValue = table::remove(_postedSwaps, encodedSwap);
        let (initiator, poolOwner) = MesonHelpers::destructPosted(postingValue);

        // Ensure that the `keyString` works.
        let calculateHash = aptos_hash::keccak256(keyString);
        let expectedHash = MesonHelpers::hashValueFrom(encodedSwap);
        assert!(calculateHash == expectedHash, EHASH_VALUE_NOT_MATCH);

        // Assertion about time-lock.
        let expireTs = MesonHelpers::expireTsFrom(encodedSwap);
        assert!(expireTs < timestamp::now_seconds() + MesonConfig::get_MIN_BOND_TIME_PERIOD(), EALREADY_EXPIRED);

        // Release the coin.
        let fetchedCoin = table::remove(_cachedCoin, encodedSwap);

        if depositToPool {
            MesonStates::addLiquidity<CoinType>(poolOwner, fetchedCoin);
        } else {
            coin::deposit<CoinType>(poolOwner, fetchedCoin);        // To fixed!
        }
        
        /* ============================ To be added ============================ */
        // Emit `postedSwap` event!
        /* ===================================================================== */
    }


}