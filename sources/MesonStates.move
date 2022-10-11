module Meson::MesonStates {
    /* ---------------------------- References ---------------------------- */

    use std::table;
    // use std::signer;
    // use std::vector;
    // use std::string::String;
    // use aptos_token::token::{TokenId, create_token_id_raw};

    // Contains all the related tables (mappings).
    struct StoredContentOfStates has key {
        poolOfAuthorizedAddr: table::Table<address, u64>,
        ownerOfPool: table::Table<u64, address>,
    }

    

    /* ---------------------------- Main Function ---------------------------- */



    /* ---------------------------- Utils Function ---------------------------- */


}