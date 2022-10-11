module Meson::MesonPools {
    /* ---------------------------- References ---------------------------- */

    use std::table;
    use std::signer;
    use Meson::MesonHelpers::{EncodedSwap, PostedSwap, LockedSwap};
    use Meson::MesonStates::{newTokenIdAndPoolId, poolTokenBalance};

    const DEPLOYER: address = @Meson;
    const ENOT_DEPLOYER: u64 = 0;



    /* ---------------------------- Struct & Constructor ---------------------------- */

    // Contains all the related tables (mappings).
    struct StoredContentOfPools has key {
        _lockedSwaps: table::Table<vector<u8>, LockedSwap>,
    }



    /* ---------------------------- Initialize ---------------------------- */

    public entry fun initializeTable(deployer: &signer) {
        let deployerAddress = signer::address_of(deployer);
        assert!(deployerAddress == DEPLOYER, ENOT_DEPLOYER);
        if(!exists<StoredContentOfPools>(deployerAddress)) move_to<StoredContentOfPools>(deployer, StoredContentOfPools {
            _lockedSwaps: table::new<vector<u8>, LockedSwap>(),
        });
    }



    /* ---------------------------- Main Function ---------------------------- */

    // public fun depositAndRegister(lp: &signer, amount: u64, tokenId: u64, poolId: u64) {
    //     let poolOwner = signer::address_of(lp);
    //     let tokenIdAndPoolId = newTokenIdAndPoolId(tokenId, poolId);
    // }

    // Step 2: Lock
    // public entry fun lock(recipient: &signer, encodedSwap: EncodedSwap, initiatorAddress: address) acquires StoredContentOfPools {

    // } 

}