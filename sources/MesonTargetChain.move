module Meson::MesonPools {
    /* ---------------------------- References ---------------------------- */

    use std::table;
    use std::signer;
    use std::timestamp;
    use std::aptos_hash;
    use Meson::MesonConfig;
    use Meson::MesonHelpers;
    use Meson::MesonHelpers::{EncodedSwap, LockedSwap};
    use Meson::MesonStates;
    use Meson::MesonTokens::{tokenForIndex};
    use aptos_token::token;
    use aptos_token::token::{Token};

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
    struct StoredContentOfPools has key {
        _lockedSwaps: table::Table<vector<u8>, LockedSwap>,
        _cachedToken: table::Table<vector<u8>, Token>,
    }



    /* ---------------------------- Initialize ---------------------------- */

    public entry fun initializeTable(deployer: &signer) {
        let deployerAddress = signer::address_of(deployer);
        assert!(deployerAddress == DEPLOYER, ENOT_DEPLOYER);
        if(!exists<StoredContentOfPools>(deployerAddress)) move_to<StoredContentOfPools>(deployer, StoredContentOfPools {
            _lockedSwaps: table::new<vector<u8>, LockedSwap>(),
            _cachedToken: table::new<vector<u8>, Token>(),
        });
    }



    /* ---------------------------- Main Function ---------------------------- */

    public entry fun depositAndRegister(lpAccount: &signer, amount: u64, tokenIndex: u64) {
        // Notice the difference between `tokenIndex` and `tokenId`. `tokenIndex` can be {0, 1, 2, 3, ...} and `tokenId` can be { TokenId(USDC), TokenId(USDT), ...}. `TokenId` is a struct defined in aptos_token::token::TokenId.
        let tokenId = tokenForIndex(tokenIndex); 
        let lpAddress = signer::address_of(lpAccount);
        let withdrewToken = token::withdraw_token(lpAccount, tokenId, amount);
        MesonStates::addLiquidityFirstTime(tokenIndex, lpAddress, withdrewToken);
    }

    public entry fun deposit(lpAccount: &signer, amount: u64, tokenIndex: u64) {
        let tokenId = tokenForIndex(tokenIndex); 
        let lpAddress = signer::address_of(lpAccount);
        let withdrewToken = token::withdraw_token(lpAccount, tokenId, amount);
        MesonStates::addLiquidity(tokenIndex, lpAddress, withdrewToken);
    }

    public entry fun withdraw(lpAccount: &signer, amount: u64, tokenIndex: u64) {
        let lpAddress = signer::address_of(lpAccount);
        let withdrewToken = MesonStates::removeLiquidity(tokenIndex, lpAddress, amount);
        token::deposit_token(lpAccount, withdrewToken);
    }

    // Notice: We don't need add or remove authorized address. So there's no function `addAuthorizedAddr` and `removeAuthorizedAddr`.


    // Step 2: Lock
    public entry fun lock(recipientAccount: &signer, encodedSwap: EncodedSwap, initiator: address) acquires StoredContentOfPools {
        // Ensure that the `lockedSwap` doesn't exist.
        let _storedContentOfPools = borrow_global_mut<StoredContentOfPools>(DEPLOYER);
        let _lockedSwaps = &mut _storedContentOfPools._lockedSwaps;
        let _cachedToken = &mut _storedContentOfPools._cachedToken;
        let swapId = MesonHelpers::getSwapId(encodedSwap, initiator);
        assert!(!table::contains(_lockedSwaps, swapId), ESWAP_ALREADY_EXISTS);

        // Assertion about time-lock and LP pool.
        let recipient = signer::address_of(recipientAccount);    // Equals to LP Address
        let outTokenId = MesonHelpers::outTokenIndexFrom(encodedSwap);
        let amount = MesonHelpers::amountFrom(encodedSwap);
        let until = timestamp::now_seconds() + MesonConfig::get_LOCK_TIME_PERIOD();
        assert!(MesonStates::lpTokenExists(outTokenId, recipient), ELP_POOL_NOT_EXISTS);
        assert!(until < MesonHelpers::expireTsFrom(encodedSwap) - 300, EEXIPRE_TS_IS_SOON);

        // Withdraw token entity from the LP pool.
        let withdrewToken = MesonStates::removeLiquidity(outTokenId, recipient, amount);

        // Store the `lockingValue` in contract.
        let lockingValue = MesonHelpers::newLockedSwap(until, recipient);
        table::add(_lockedSwaps, swapId, lockingValue);
        table::add(_cachedToken, swapId, withdrewToken);

        /* ============================ To be added ============================ */
        // Emit `postedSwap` event!
        /* ===================================================================== */
    }


    // Step 3: Release
    // The priciple of Hash-Time Locked Contract: `keyString` is the key of `lockHash`!
    public entry fun release(initiatorAccount: &signer, encodedSwap: EncodedSwap, keyString: vector<u8>) acquires StoredContentOfPools {
        // Ensure that the transaction exists.
        let _storedContentOfPools = borrow_global_mut<StoredContentOfPools>(DEPLOYER);
        let _lockedSwaps = &mut _storedContentOfPools._lockedSwaps;
        let _cachedToken = &mut _storedContentOfPools._cachedToken;
        let initiator = signer::address_of(initiatorAccount);
        let swapId = MesonHelpers::getSwapId(encodedSwap, initiator);
        assert!(table::contains(_lockedSwaps, swapId), ESWAP_NOT_EXISTS);

        // Ensure that the `keyString` works.
        let calculateHash = aptos_hash::keccak256(keyString);
        let expectedHash = MesonHelpers::hashValueFrom(encodedSwap);
        assert!(calculateHash == expectedHash, EHASH_VALUE_NOT_MATCH);

        // Assertion about time-lock.
        let lockingValue = table::remove(_lockedSwaps, swapId);
        let (until, recipient) = MesonHelpers::destructLocked(lockingValue);
        assert!(until > timestamp::now_seconds(), EALREADY_EXPIRED);

        // Release the token.
        let outTokenId = MesonHelpers::outTokenIndexFrom(encodedSwap);
        let fetchedToken = table::remove(_cachedToken, swapId);
        MesonStates::addLiquidity(outTokenId, recipient, fetchedToken);
        
        /* ============================ To be added ============================ */
        // Emit `postedSwap` event!
        /* ===================================================================== */
    }
}