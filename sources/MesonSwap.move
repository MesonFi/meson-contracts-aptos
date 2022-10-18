/// @title MesonSwap
/// @notice The class to receive and process swap requests on the initial chain side.
/// Methods in this class will be executed by swap initiators or LPs
/// on the initial chain of swaps.
module Meson::MesonSwap {
    use std::vector;
    use std::table;
    use std::signer;
    use std::timestamp;
    use aptos_framework::coin;
    use aptos_framework::coin::{Coin};
    use Meson::MesonConfig;
    use Meson::MesonHelpers;
    use Meson::MesonStates;

    const DEPLOYER: address = @Meson;
    const ENOT_DEPLOYER: u64 = 0;
    const ESWAP_ALREADY_EXISTS: u64 = 2;
    const EEXPIRE_TOO_EARLY: u64 = 3;
    const EEXPIRE_TOO_LATE: u64 = 4;
    const EHASH_VALUE_NOT_MATCH: u64 = 8;
    const ESWAP_NOT_EXISTS: u64 = 9;
    const EALREADY_EXPIRED: u64 = 10;
    const ESTILL_IN_LOCK: u64 = 11;
    const ERECIPENT_NOT_MATCH: u64 = 12;

    
    const EINVALID_ENCODED_LENGTH: u64 = 33;
    const EINVALID_ENCODED_DECODING_0: u64 = 35;
    const EINVALID_ENCODED_DECODING_1: u64 = 36;

    struct StoredContentOfSwap<phantom CoinType> has key {
        _postedSwaps: table::Table<vector<u8>, PostedSwap>,
        _cachedCoin: table::Table<vector<u8>, Coin<CoinType>>,
    }

    struct PostedSwap has store {
        fromAddress: address,
        poolOwner: address,
        initiator: vector<u8>,
    }

    fun newPostedSwap(fromAddress: address, poolOwner: address, initiator: vector<u8>): PostedSwap {
        PostedSwap { fromAddress, poolOwner, initiator }
    }

    fun destructPosted(posted: PostedSwap): (address, address, vector<u8>) {
        let PostedSwap { fromAddress, poolOwner, initiator } = posted;
        (fromAddress, poolOwner, initiator)
    }


    public entry fun initializeTable<CoinType>(deployer: &signer) {
        let deployerAddress = signer::address_of(deployer);
        assert!(deployerAddress == DEPLOYER, ENOT_DEPLOYER);
        let newContent = StoredContentOfSwap<CoinType> {
            _postedSwaps: table::new<vector<u8>, PostedSwap>(),
            _cachedCoin: table::new<vector<u8>, Coin<CoinType>>(),
        };
        move_to<StoredContentOfSwap<CoinType>>(deployer, newContent);
    }

    /// `encoded_swap` in format of `version:uint8|amount:uint40|salt:uint80|fee:uint40|expireTs:uint40|outChain:uint16|outToken:uint8|inChain:uint16|inToken:uint8`
    ///   version: Version of encoding
    ///   amount: The amount of tokens of this swap, always in decimal 6. The amount of a swap is capped at $100k so it can be safely encoded in uint48;
    ///   salt: The salt value of this swap, carrying some information below:
    ///     salt & 0x80000000000000000000 == true => will release to an owa address, otherwise a smart contract;
    ///     salt & 0x40000000000000000000 == true => will waive *service fee*;
    ///     salt & 0x08000000000000000000 == true => use *non-typed signing* (some wallets such as hardware wallets don't support EIP-712v1);
    ///     salt & 0x0000ffffffffffffffff: customized data that can be passed to integrated 3rd-party smart contract;
    ///   fee: The fee given to LPs (liquidity providers). An extra service fee maybe charged afterwards;
    ///   expireTs: The expiration time of this swap on the initial chain. The LP should `executeSwap` and receive his funds before `expireTs`;
    ///   outChain: The target chain of a cross-chain swap (given by the last 2 bytes of SLIP-44);
    ///   outToken: The index of the token on the target chain. See `tokenForIndex` in `MesonToken.sol`;
    ///   inChain: The initial chain of a cross-chain swap (given by the last 2 bytes of SLIP-44);
    ///   inToken: The index of the token on the initial chain. See `tokenForIndex` in `MesonToken.sol`.
    public entry fun postSwap<CoinType>(
        fromAccount: &signer,
        encoded_swap: vector<u8>,
        signature: vector<u8>, // must be signed by `initiator`
        initiator: vector<u8>, // an eth address of (20 bytes), the signer to sign for release
        poolOwner: address,
    ) acquires StoredContentOfSwap {
        assert!(vector::length(&encoded_swap) == 32, EINVALID_ENCODED_LENGTH);
        assert!(vector::length(&initiator) == 20, 1);
        MesonHelpers::match_protocol_version(encoded_swap);
        MesonHelpers::for_initial_chain(encoded_swap);

        let _storedContentOfSwap = borrow_global_mut<StoredContentOfSwap<CoinType>>(DEPLOYER);
        let _postedSwaps = &mut _storedContentOfSwap._postedSwaps;
        let _cachedCoin = &mut _storedContentOfSwap._cachedCoin;
        assert!(!table::contains(_postedSwaps, encoded_swap), ESWAP_ALREADY_EXISTS);

        let amount = MesonHelpers::amount_from(encoded_swap);
        // TODO: assert amount <= MAX_SWAP_AMOUNT

        // Assertion about time-lock.
        let delta = MesonHelpers::expire_ts_from(encoded_swap) - timestamp::now_seconds();
        assert!(delta > MesonConfig::get_MIN_BOND_TIME_PERIOD(), EEXPIRE_TOO_EARLY);
        assert!(delta < MesonConfig::get_MAX_BOND_TIME_PERIOD(), EEXPIRE_TOO_LATE);

        MesonHelpers::check_request_signature(encoded_swap, signature, initiator);

        let withdrewCoin = coin::withdraw<CoinType>(fromAccount, amount);

        let posting = newPostedSwap(signer::address_of(fromAccount), poolOwner, initiator);
        table::add(_postedSwaps, encoded_swap, posting);
        table::add(_cachedCoin, encoded_swap, withdrewCoin);
    }


    public entry fun cancelSwap<CoinType>(
        _signerAccount: &signer, // signer could be anyone
        encoded_swap: vector<u8>,
    ) acquires StoredContentOfSwap {
        let _storedContentOfSwap = borrow_global_mut<StoredContentOfSwap<CoinType>>(DEPLOYER);
        let _postedSwaps = &mut _storedContentOfSwap._postedSwaps;
        let _cachedCoin = &mut _storedContentOfSwap._cachedCoin;
        assert!(table::contains(_postedSwaps, encoded_swap), ESWAP_NOT_EXISTS);

        let expire_ts = MesonHelpers::expire_ts_from(encoded_swap);
        assert!(expire_ts < timestamp::now_seconds(), ESTILL_IN_LOCK);

        let posted = table::remove(_postedSwaps, encoded_swap);
        let (fromAddress, _, _) = destructPosted(posted);

        let fetchedCoin = table::remove(_cachedCoin, encoded_swap);
        coin::deposit<CoinType>(fromAddress, fetchedCoin);
    }


    public entry fun executeSwap<CoinType>(
        _signerAccount: &signer, // signer could be anyone
        encoded_swap: vector<u8>,
        signature: vector<u8>,
        recipient: vector<u8>,
        depositToPool: bool,
    ) acquires StoredContentOfSwap {
        let _storedContentOfSwap = borrow_global_mut<StoredContentOfSwap<CoinType>>(DEPLOYER);
        let _postedSwaps = &mut _storedContentOfSwap._postedSwaps;
        let _cachedCoin = &mut _storedContentOfSwap._cachedCoin;
        assert!(table::contains(_postedSwaps, encoded_swap), ESWAP_NOT_EXISTS);

        let posted = table::remove(_postedSwaps, encoded_swap);
        // TODO: need to set a value in `_postedSwaps` to prevent double spending
        let (_, poolOwner, initiator) = destructPosted(posted);

        MesonHelpers::check_release_signature(encoded_swap, recipient, signature, initiator);

        let fetchedCoin = table::remove(_cachedCoin, encoded_swap);
        if (depositToPool) {
            MesonStates::addLiquidity<CoinType>(poolOwner, fetchedCoin);
        } else {
            coin::deposit<CoinType>(poolOwner, fetchedCoin);
        }
    }
}
