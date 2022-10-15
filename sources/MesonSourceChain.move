module Meson::MesonSwap {
    /* ---------------------------- References ---------------------------- */

    use std::vector;
    use std::table;
    use std::signer;
    use std::timestamp;
    use std::aptos_hash;
    use aptos_framework::coin;
    use aptos_framework::coin::{Coin};
    use Meson::MesonConfig;
    use Meson::MesonHelpers;
    use Meson::MesonHelpers::{ PostedSwap};
    use Meson::MesonStates;

    const DEPLOYER: address = @Meson;
    const ENOT_DEPLOYER: u64 = 0;
    const ESWAP_ALREADY_EXISTS: u64 = 2;
    const EEXPIRE_TOO_EARLY: u64 = 3;
    const EEXPIRE_TOO_LATE: u64 = 4;
    const EHASH_VALUE_NOT_MATCH: u64 = 8;
    const ESWAP_NOT_EXISTS: u64 = 9;
    const EALREADY_EXPIRED: u64 = 10;
    const ERECIPENT_NOT_MATCH: u64 = 11;

    
    const EINVALID_ENCODED_LENGTH: u64 = 33;
    const EINVALID_ENCODED_DECODING_0: u64 = 35;
    const EINVALID_ENCODED_DECODING_1: u64 = 36;

    /* ---------------------------- Struct & Constructor ---------------------------- */

    // Contains all the related tables (mappings).
    // Each unique coin has a related `StoredContentOfSwap`.
    struct StoredContentOfSwap<phantom CoinType> has key {
        _postedSwaps: table::Table<vector<u128>, PostedSwap>,
        _cachedCoin: table::Table<vector<u128>, Coin<CoinType>>,
    }



    /* ---------------------------- Initialize ---------------------------- */

    public entry fun initializeTable<CoinType>(deployer: &signer) {
        let deployerAddress = signer::address_of(deployer);
        assert!(deployerAddress == DEPLOYER, ENOT_DEPLOYER);
        let newContent = StoredContentOfSwap<CoinType> {
            _postedSwaps: table::new<vector<u128>, PostedSwap>(),
            _cachedCoin: table::new<vector<u128>, Coin<CoinType>>(),
        };
        move_to<StoredContentOfSwap<CoinType>>(deployer, newContent);
    }



    /* ---------------------------- Main Function ---------------------------- */

    // Step 1: postSwap
    // `encoded` is in format of `amount:uint48|salt:uint80|fee:uint40|expireTs:uint40|outChain:uint16|outToken:uint8|inChain:uint16|inToken:uint8` in solidity.
    public entry fun postSwap<CoinType>(
        initiatorAccount: &signer,
        encoded: vector<u128>,
        poolOwner: address,
        _lockHash: vector<u8>
    ) acquires StoredContentOfSwap {
        assert!(vector::length(&encoded) == 2, EINVALID_ENCODED_LENGTH);

        // Ensure that the `encoded` doesn't exist.
        let _storedContentOfSwap = borrow_global_mut<StoredContentOfSwap<CoinType>>(DEPLOYER);
        let _postedSwaps = &mut _storedContentOfSwap._postedSwaps;
        let _cachedCoin = &mut _storedContentOfSwap._cachedCoin;
        assert!(!table::contains(_postedSwaps, encoded), ESWAP_ALREADY_EXISTS);
        
        // Assertion about time-lock.
        let expireTs = MesonHelpers::expireTsFrom(encoded);
        let delta = expireTs - timestamp::now_seconds();
        assert!(delta > MesonConfig::get_MIN_BOND_TIME_PERIOD(), EEXPIRE_TOO_EARLY);
        assert!(delta < MesonConfig::get_MAX_BOND_TIME_PERIOD(), EEXPIRE_TOO_LATE);

        // Withdraw coin entity from the initiator.
        let amount = MesonHelpers::amountFrom(encoded);

        // If initiatorAccount is not the signer, can we withdraw coins from it?
        let withdrewCoin = coin::withdraw<CoinType>(initiatorAccount, amount);

        // Store the `postingValue` in contract.
        let postingValue = MesonHelpers::newPostedSwap(signer::address_of(initiatorAccount), poolOwner);
        table::add(_postedSwaps, encoded, postingValue);
        table::add(_cachedCoin, encoded , withdrewCoin);

        /* ============================ To be added ============================ */
        // Emit `postedSwap` event!
        /* ===================================================================== */
    }


    // Step 4. executeSwap
    public entry fun executeSwap<CoinType>(
        _signerAccount: &signer, // signer could be anyone
        encoded: vector<u128>,
        _initiator: vector<u8>, // this is used when check signature
        _recipient: address, // this is used when check signature
        keyString: vector<u8>,
        lockHash: vector<u8>,
        depositToPool: bool,
    ) acquires StoredContentOfSwap {
        // Ensure that the transaction exists.
        let _storedContentOfSwap = borrow_global_mut<StoredContentOfSwap<CoinType>>(DEPLOYER);
        let _postedSwaps = &mut _storedContentOfSwap._postedSwaps;
        let _cachedCoin = &mut _storedContentOfSwap._cachedCoin;
        assert!(table::contains(_postedSwaps, encoded), ESWAP_NOT_EXISTS);

        let postingValue = table::remove(_postedSwaps, encoded);
        let (_initiatorAddr, poolOwner) = MesonHelpers::destructPosted(postingValue);

        // Ensure that the `keyString` works.
        let calculateHash = aptos_hash::keccak256(keyString);
        assert!(calculateHash == lockHash, EHASH_VALUE_NOT_MATCH);

        // Assertion about time-lock.
        let expireTs = MesonHelpers::expireTsFrom(encoded);
        assert!(expireTs < timestamp::now_seconds() + MesonConfig::get_MIN_BOND_TIME_PERIOD(), EALREADY_EXPIRED);

        // Release the coin.
        let fetchedCoin = table::remove(_cachedCoin, encoded);

        if (depositToPool) {
            MesonStates::addLiquidity<CoinType>(poolOwner, fetchedCoin);
        } else {
            coin::deposit<CoinType>(poolOwner, fetchedCoin);
        }
        
        /* ============================ To be added ============================ */
        // Emit `postedSwap` event!
        /* ===================================================================== */
    }

}