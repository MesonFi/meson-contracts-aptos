module Meson::MesonSwap {
    /* ---------------------------- References ---------------------------- */

    use std::table;
    use std::signer;
    use Meson::MesonHelpers::{EncodedSwap, PostedSwap};

    const DEPLOYER: address = @Meson;
    const ENOT_DEPLOYER: u64 = 0;
    
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
    public entry fun postSwap(encodedSwap: EncodedSwap, postingValue: PostedSwap) {
        // let storedContent = borrow_global_mut<MesonHelpers::StoredContent>(DEPLOYER);
        // assert!(table::contains())
    }
}