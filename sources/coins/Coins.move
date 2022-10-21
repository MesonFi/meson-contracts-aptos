module Meson::Coins {
    use aptos_framework::managed_coin;

    struct USDC {}
    struct USDT {}
    struct UCT {}

    fun init_module(sender: &signer) {
        managed_coin::initialize<USDC>(sender, b"USD Coin", b"USDC", 6, true);
        managed_coin::initialize<USDT>(sender, b"Tether USD", b"USDT", 6, true);
        managed_coin::initialize<UCT>(sender, b"USD Coupon Token (meson.fi)", b"UCT", 4, true);
    }
}
