module Meson::MesonConfig {
    // See https://github.com/satoshilabs/slips/blob/master/slip-0044.md.
    const CHAIN_ID: u64 = 0x027d;        // Chain ID (SLIP44) of Aptos is "0x027d".

    const ENOT_DEPLOYER: u64 = 0;
    const EALREADY_IN_TOKEN_LIST: u64 = 1;
    const ESWAP_ALREADY_EXISTS: u64 = 2;
    const EEXPIRE_TOO_EARLY: u64 = 3;
    const EEXPIRE_TOO_LATE: u64 = 4;

    const MIN_BOND_TIME_PERIOD: u64 = 3600;     // 1 hour
    const MAX_BOND_TIME_PERIOD: u64 = 7200;     // 2 hours
    const LOCK_TIME_PERIOD: u64 = 2400;         // 40 minutes

    public fun get_MIN_BOND_TIME_PERIOD(): u64 {
        MIN_BOND_TIME_PERIOD
    }

    public fun get_MAX_BOND_TIME_PERIOD(): u64 {
        MAX_BOND_TIME_PERIOD
    }

    public fun get_LOCK_TIME_PERIOD(): u64 {
        LOCK_TIME_PERIOD
    }

}