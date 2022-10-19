module Meson::MesonStates {
    use std::signer;
    use std::table;
    use aptos_std::type_info;
    use aptos_framework::coin;
    use aptos_framework::coin::{Coin};

    const DEPLOYER: address = @Meson;
    const ENOT_DEPLOYER: u64 = 0;
    const ENOT_MANAGER: u64 = 0;
    const EALREADY_IN_COIN_LIST: u64 = 1;
    const ESWAP_ALREADY_EXISTS: u64 = 2;
    const ECOIN_TYPE_ERROR: u64 = 5;
    const ESWAP_NOT_EXISTS: u64 = 9;

    const EPOOL_INDEX_CANNOT_BE_ZERO: u64 = 16;
    const EPOOL_NOT_REGISTERED: u64 = 17;
    const EPOOL_ALREADY_REGISTERED: u64 = 18;
    const EPOOL_NOT_POOL_OWNER: u64 = 19;
    const EPOOL_ADDR_NOT_AUTHORIZED: u64 = 20;
    const EPOOL_ADDR_ALREADY_AUTHORIZED: u64 = 21;
    const EPOOL_ADDR_AUTHORIZED_TO_ANOTHER: u64 = 22;

    friend Meson::MesonSwap;
    friend Meson::MesonPools;

    struct GeneralStore has key {
        supported_coins: table::Table<u8, type_info::TypeInfo>,     // coin_index => CoinType
        pool_owners: table::Table<u64, address>,                    // pool_index => owner_addr
        pool_of_authorized_addr: table::Table<address, u64>,        // authorized_addr => pool_index
        posted_swaps: table::Table<vector<u8>, PostedSwap>,         // encoded_swap => posted_swap
        locked_swaps: table::Table<vector<u8>, LockedSwap>,         // swap_id => locked_swap
    }

    // Contains all the related tables (mappings).
    struct StoreForCoin<phantom CoinType> has key {
        in_pool_coins: table::Table<u64, Coin<CoinType>>,           // pool_index => Coins
        pending_coins: table::Table<vector<u8>, Coin<CoinType>>,    // swap_id / [encoded_swap|ff] => Coins
    }

    struct PostedSwap has store {
        pool_index: u64,
        initiator: vector<u8>,
        from_address: address,
    }

    struct LockedSwap has store {
        pool_index: u64,
        until: u64,
        recipient: address,
    }

    public entry fun initialize(deployer: &signer, premium_manager: address) {
        let deployerAddress = signer::address_of(deployer);
        assert!(deployerAddress == DEPLOYER, ENOT_DEPLOYER);

        let store = GeneralStore {
            supported_coins: table::new<u8, type_info::TypeInfo>(),
            pool_owners: table::new<u64, address>(),
            pool_of_authorized_addr: table::new<address, u64>(),
            posted_swaps: table::new<vector<u8>, PostedSwap>(),
            locked_swaps: table::new<vector<u8>, LockedSwap>(),
        };
        // pool_index = 0 is manager
        table::add(&mut store.pool_owners, 0, premium_manager);
        move_to<GeneralStore>(deployer, store);
    }

    // Named consistently with solidity contracts
    public entry fun addSupportToken<CoinType>(
        signer_account: &signer,
        coin_index: u8,
    ) acquires GeneralStore {
        let signerAddress = signer::address_of(signer_account);
        assert!(signerAddress == DEPLOYER, ENOT_DEPLOYER);

        let store = borrow_global_mut<GeneralStore>(DEPLOYER);
        let supported_coins = &mut store.supported_coins;
        assert!(!table::contains(supported_coins, coin_index), 1);
        table::add(supported_coins, coin_index, type_info::type_of<CoinType>());

        let coin_store = StoreForCoin<CoinType> {
            in_pool_coins: table::new<u64, Coin<CoinType>>(),
            pending_coins: table::new<vector<u8>, Coin<CoinType>>(),
        };
        move_to<StoreForCoin<CoinType>>(signer_account, coin_store);
    }

    public(friend) fun coin_type_for_index(coin_index: u8): type_info::TypeInfo acquires GeneralStore {
        let store = borrow_global<GeneralStore>(DEPLOYER);
        *table::borrow(&store.supported_coins, coin_index)
    }

    public(friend) fun match_coin_type<CoinType>(coin_index: u8) acquires GeneralStore {
        let type1 = type_info::type_of<CoinType>();
        let type2 = coin_type_for_index(coin_index);

        assert!(
            type_info::account_address(&type1) == type_info::account_address(&type2) &&
            type_info::module_name(&type1) == type_info::module_name(&type2) &&
            type_info::struct_name(&type1) == type_info::struct_name(&type2),
            1
        );
    }

    public(friend) fun owner_of_pool(pool_index: u64): address acquires GeneralStore {
        let pool_owners = &borrow_global<GeneralStore>(DEPLOYER).pool_owners;
        assert!(table::contains(pool_owners, pool_index), EPOOL_NOT_REGISTERED);
        *table::borrow(pool_owners, pool_index)
    }

    public(friend) fun get_premium_manager(): address acquires GeneralStore {
        owner_of_pool(0)
    }

    public(friend) fun pool_index_of(authorized_addr: address): u64 acquires GeneralStore {
        let pool_of_authorized_addr = &borrow_global<GeneralStore>(DEPLOYER).pool_of_authorized_addr;
        assert!(table::contains(pool_of_authorized_addr, authorized_addr), EPOOL_ADDR_NOT_AUTHORIZED);
        *table::borrow(pool_of_authorized_addr, authorized_addr)
    }

    public(friend) fun pool_index_if_owner(addr: address): u64 acquires GeneralStore {
        let pool_index = pool_index_of(addr);
        assert!(addr == owner_of_pool(pool_index), EPOOL_NOT_POOL_OWNER);
        pool_index
    }

    public(friend) fun register_pool_index(pool_index: u64, owner_addr: address) acquires GeneralStore {
        assert!(pool_index != 0, EPOOL_INDEX_CANNOT_BE_ZERO);
        let store = borrow_global_mut<GeneralStore>(DEPLOYER);
        assert!(!table::contains(&store.pool_owners, pool_index), EPOOL_ALREADY_REGISTERED);
        assert!(!table::contains(&store.pool_of_authorized_addr, owner_addr), EPOOL_ADDR_ALREADY_AUTHORIZED);
        table::add(&mut store.pool_owners, pool_index, owner_addr);
        table::add(&mut store.pool_of_authorized_addr, owner_addr, pool_index);
    }

    public(friend) fun add_authorized(pool_index: u64, addr: address) acquires GeneralStore {
        assert!(pool_index != 0, EPOOL_INDEX_CANNOT_BE_ZERO);
        let store = borrow_global_mut<GeneralStore>(DEPLOYER);
        assert!(!table::contains(&store.pool_of_authorized_addr, addr), EPOOL_ADDR_ALREADY_AUTHORIZED);
        table::add(&mut store.pool_of_authorized_addr, addr, pool_index);
    }

    public(friend) fun remove_authorized(pool_index: u64, addr: address) acquires GeneralStore {
        let store = borrow_global_mut<GeneralStore>(DEPLOYER);
        assert!(pool_index == table::remove(&mut store.pool_of_authorized_addr, addr), EPOOL_ADDR_AUTHORIZED_TO_ANOTHER);
    }


    public(friend) fun coins_to_pool<CoinType>(pool_index: u64, coins_to_add: Coin<CoinType>) acquires StoreForCoin {
        let store = borrow_global_mut<StoreForCoin<CoinType>>(DEPLOYER);
        let in_pool_coins = &mut store.in_pool_coins;
        if (table::contains(in_pool_coins, pool_index)) {
            let current_coins = table::borrow_mut(in_pool_coins, pool_index);
            coin::merge<CoinType>(current_coins, coins_to_add);
        } else {
            table::add(in_pool_coins, pool_index, coins_to_add);
        };
    }

    public(friend) fun coins_from_pool<CoinType>(pool_index: u64, amount: u64): Coin<CoinType> acquires StoreForCoin {
        let store = borrow_global_mut<StoreForCoin<CoinType>>(DEPLOYER);
        let current_coins = table::borrow_mut(&mut store.in_pool_coins, pool_index);
        coin::extract<CoinType>(current_coins, amount)
    }

    public(friend) fun coins_to_pending<CoinType>(key: vector<u8>, coins: Coin<CoinType>) acquires StoreForCoin {
        let store = borrow_global_mut<StoreForCoin<CoinType>>(DEPLOYER);
        table::add(&mut store.pending_coins, key, coins);
    }

    public(friend) fun coins_from_pending<CoinType>(key: vector<u8>): Coin<CoinType> acquires StoreForCoin {
        let store = borrow_global_mut<StoreForCoin<CoinType>>(DEPLOYER);
        table::remove(&mut store.pending_coins, key)
    }


    public(friend) fun add_posted_swap(
        encoded_swap: vector<u8>,
        pool_index: u64,
        initiator: vector<u8>,
        from_address: address,
    ) acquires GeneralStore {
        let store = borrow_global_mut<GeneralStore>(DEPLOYER);
        let posted_swaps = &mut store.posted_swaps;
        assert!(!table::contains(posted_swaps, encoded_swap), ESWAP_ALREADY_EXISTS);

        table::add(posted_swaps, encoded_swap, PostedSwap { pool_index, initiator, from_address });
    }

    public(friend) fun remove_posted_swap(
        encoded_swap: vector<u8>
    ): (u64, vector<u8>, address) acquires GeneralStore  {
        let store = borrow_global_mut<GeneralStore>(DEPLOYER);
        let posted_swaps = &mut store.posted_swaps;
        assert!(table::contains(posted_swaps, encoded_swap), ESWAP_NOT_EXISTS);

        let PostedSwap { pool_index, initiator, from_address } = table::remove(posted_swaps, encoded_swap);
        // TODO: need to set a value in `_postedSwaps` to prevent double spending

        (pool_index, initiator, from_address)
    }

    public(friend) fun add_locked_swap(
        swap_id: vector<u8>,
        pool_index: u64,
        until: u64,
        recipient: address,
    ) acquires GeneralStore {
        let store = borrow_global_mut<GeneralStore>(DEPLOYER);
        let locked_swaps = &mut store.locked_swaps;
        assert!(!table::contains(locked_swaps, swap_id), ESWAP_ALREADY_EXISTS);

        table::add(locked_swaps, swap_id, LockedSwap { pool_index, until, recipient });
    }

    public(friend) fun remove_locked_swap(swap_id: vector<u8>): (u64, u64, address) acquires GeneralStore  {
        let store = borrow_global_mut<GeneralStore>(DEPLOYER);
        let locked_swaps = &mut store.locked_swaps;
        assert!(table::contains(locked_swaps, swap_id), ESWAP_NOT_EXISTS);

        let LockedSwap { pool_index, until, recipient } = table::remove(locked_swaps, swap_id);

        (pool_index, until, recipient)
    }
}
