module cny_game::listing {

    use std::type_name::{Self, TypeName};
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::vec_set::{Self, VecSet};
    use sui::sui::SUI;
    use sui::event::emit;

    //***********************
    //  Errors
    //***********************

    const ECoinTypeAlreadyListed: u64 = 0;
    const ECoinTypeNotExists: u64 = 1;
    const ECoinTypeNotListed: u64 = 2;

    //***********************
    //  Events
    //***********************

    struct CoinTypeListed<phantom T> has copy, drop {}

    struct CoinTypeUnlisted<phantom T> has copy, drop {}

    //***********************
    //  Objects
    //***********************

    struct ListingCap has key, store {
        id: UID,
    }

    struct CoinTypeWhitelist has key {
        id: UID,
        coins: VecSet<TypeName>,
    }

    //***********************
    //  Constructor
    //***********************

    fun init(ctx: &mut TxContext) {
        // create ListingCap and transfer to deployer
        let deployer = tx_context::sender(ctx);
        let listing_cap = ListingCap { id: object::new(ctx) };
        transfer::transfer(listing_cap, deployer);
        // share the CoinTypeWhitelist
        let whitelist_coins = CoinTypeWhitelist {
            id: object::new(ctx),
            coins: vec_set::singleton(type_name::get<SUI>()),
        };
        transfer::share_object(whitelist_coins);
    }

    //***********************
    //  Admin Functions
    //***********************

    public fun add_coin_type<T>(
        _: &ListingCap,
        whitelist: &mut CoinTypeWhitelist,
    ) {
        let coin_set = &mut whitelist.coins;
        let coin_type = type_name::get<T>();
        assert!(
            !vec_set::contains(coin_set, &coin_type),
            ECoinTypeAlreadyListed,
        );
        vec_set::insert(coin_set, coin_type);
        emit(CoinTypeListed<T> {});
    }

    public fun remove_coin_type<T>(
        _: &ListingCap,
        whitelist: &mut CoinTypeWhitelist,
    ) {
        let coin_set = &mut whitelist.coins;
        let coin_type = type_name::get<T>();
        assert!(
            vec_set::contains(coin_set, &coin_type),
            ECoinTypeNotExists,
        );
        vec_set::remove(coin_set, &coin_type);
        emit(CoinTypeUnlisted<T> {});
    }

    //***********************
    //  Assert Functions
    //***********************

    public fun assert_coin_type_is_listed<T>(
        whitelist: &CoinTypeWhitelist,
    ): TypeName {
        let coin_type = type_name::get<T>();
        assert!(
            vec_set::contains(&whitelist.coins, &coin_type),
            ECoinTypeNotListed,
        );
        coin_type
    }

    //***********************
    //  Test-only Functions
    //***********************

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}
