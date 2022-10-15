module Meson::MesonPools {
    /* ---------------------------- References ---------------------------- */

    use std::table;
    use std::signer;
    use std::timestamp;
    use std::aptos_hash;
    use aptos_framework::coin;
    use aptos_framework::coin::{Coin};
    use Meson::MesonConfig;
    use Meson::MesonHelpers;
    use Meson::MesonStates;

    const DEPLOYER: address = @Meson;
    const ENOT_DEPLOYER: u64 = 0;
    const ESWAP_ALREADY_EXISTS: u64 = 2;
    const EEXIPRE_TS_IS_SOON: u64 = 6;
    const ELP_POOL_NOT_EXISTS: u64 = 7;
    const EHASH_VALUE_NOT_MATCH: u64 = 8;
    const ESWAP_NOT_EXISTS: u64 = 9;
    const EALREADY_EXPIRED: u64 = 10;



    /* ---------------------------- Struct & Constructor ---------------------------- */

    // Contains all the related tables (mappings).
    struct StoredContentOfPools<phantom CoinType> has key {
        _lockedSwaps: table::Table<vector<u8>, MesonHelpers::LockedSwap>,
        _cachedCoin: table::Table<vector<u8>, Coin<CoinType>>,
    }



    /* ---------------------------- Initialize ---------------------------- */

    public entry fun initializeTable<CoinType>(deployer: &signer) {
        let deployerAddress = signer::address_of(deployer);
        assert!(deployerAddress == DEPLOYER, ENOT_DEPLOYER);
        let newContent = StoredContentOfPools<CoinType> {
            _lockedSwaps: table::new<vector<u8>, MesonHelpers::LockedSwap>(),
            _cachedCoin: table::new<vector<u8>, Coin<CoinType>>(),
        };
        move_to<StoredContentOfPools<CoinType>>(deployer, newContent);
    }



    /* ---------------------------- Main Function ---------------------------- */

    public entry fun depositAndRegister<CoinType>(lpAccount: &signer, amount: u64) {
        let withdrewCoin = coin::withdraw<CoinType>(lpAccount, amount);
        MesonStates::addLiquidityFirstTime<CoinType>(lpAccount, withdrewCoin);
    }

    public entry fun deposit<CoinType>(lpAccount: &signer, amount: u64) {
        let lpAddress = signer::address_of(lpAccount);
        let withdrewCoin = coin::withdraw<CoinType>(lpAccount, amount);
        MesonStates::addLiquidity<CoinType>(lpAddress, withdrewCoin);
    }

    public entry fun withdraw<CoinType>(lpAccount: &signer, amount: u64) {
        let lpAddress = signer::address_of(lpAccount);
        let withdrewCoin = MesonStates::removeLiquidity<CoinType>(lpAddress, amount);
        coin::deposit<CoinType>(lpAddress, withdrewCoin);
    }

    // Notice: We don't need add or remove authorized address. So there's no function `addAuthorizedAddr` and `removeAuthorizedAddr`.


    // Step 2: Lock
    public entry fun lock<CoinType>(
        poolOwnerAccount: &signer,
        initiator: address,
        amount: u64, expireTs: u64, outChain: u64, inChain: u64,
        lockHash: vector<u8>
    ) acquires StoredContentOfPools {
        // Ensure that the `lockedSwap` doesn't exist.
        let encodedSwap = MesonHelpers::newEncodedSwap(amount, expireTs, outChain, inChain, lockHash);  // To fixed!!
        let _storedContentOfPools = borrow_global_mut<StoredContentOfPools<CoinType>>(DEPLOYER);
        let _lockedSwaps = &mut _storedContentOfPools._lockedSwaps;
        let _cachedCoin = &mut _storedContentOfPools._cachedCoin;
        let swapId = MesonHelpers::getSwapId(encodedSwap, initiator);
        assert!(!table::contains(_lockedSwaps, swapId), ESWAP_ALREADY_EXISTS);

        // Assertion about time-lock and LP pool.
        let poolOwner = signer::address_of(poolOwnerAccount);    // Equals to LP Address
        let amount = MesonHelpers::amountFrom(encodedSwap);
        let until = timestamp::now_seconds() + MesonConfig::get_LOCK_TIME_PERIOD();
        assert!(MesonStates::lpCoinExists<CoinType>(poolOwner), ELP_POOL_NOT_EXISTS);
        assert!(until < MesonHelpers::expireTsFrom(encodedSwap) - 300, EEXIPRE_TS_IS_SOON);

        // Withdraw coin entity from the LP pool.
        let withdrewCoin = MesonStates::removeLiquidity<CoinType>(poolOwner, amount);

        // Store the `lockingValue` in contract.
        let lockingValue = MesonHelpers::newLockedSwap(until, poolOwner);
        table::add(_lockedSwaps, swapId, lockingValue);
        table::add(_cachedCoin, swapId, withdrewCoin);

        /* ============================ To be added ============================ */
        // Emit `postedSwap` event!
        /* ===================================================================== */
    }


    // Step 3: Release
    // The priciple of Hash-Time Locked Contract: `keyString` is the key of `lockHash`!
    public entry fun release<CoinType>(
        signerAccount: &signer, // signer could be anyone
        initiator: address,
        recipient: address, // recipient is given on release
        keyString: vector<u8>, 
        amount: u64, expireTs: u64, outChain: u64, inChain: u64,
        lockHash: vector<u8>
    ) acquires StoredContentOfPools {
        // Just for clearing the unusing variable warning
        assert!(signer::address_of(signerAccount)!=@0x00, 0);

        // Ensure that the transaction exists.
        let encodedSwap = MesonHelpers::newEncodedSwap(amount, expireTs, outChain, inChain, lockHash);  // To fixed!!
        let _storedContentOfPools = borrow_global_mut<StoredContentOfPools<CoinType>>(DEPLOYER);
        let _lockedSwaps = &mut _storedContentOfPools._lockedSwaps;
        let _cachedCoin = &mut _storedContentOfPools._cachedCoin;
        let swapId = MesonHelpers::getSwapId(encodedSwap, initiator);
        assert!(table::contains(_lockedSwaps, swapId), ESWAP_NOT_EXISTS);

        // Ensure that the `keyString` works.
        let calculateHash = aptos_hash::keccak256(keyString);
        let expectedHash = MesonHelpers::hashValueFrom(encodedSwap);
        assert!(calculateHash == expectedHash, EHASH_VALUE_NOT_MATCH);

        // Assertion about time-lock.
        let lockingValue = table::remove(_lockedSwaps, swapId);
        let (until, _) = MesonHelpers::destructLocked(lockingValue);
        assert!(until > timestamp::now_seconds(), EALREADY_EXPIRED);

        // Release the coin.
        let fetchedCoin = table::remove(_cachedCoin, swapId);
        coin::deposit<CoinType>(recipient, fetchedCoin);
        
        /* ============================ To be added ============================ */
        // Emit `postedSwap` event!
        /* ===================================================================== */
    }
}