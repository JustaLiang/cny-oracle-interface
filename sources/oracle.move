module cny_game::oracle {

    use std::type_name::{Self, TypeName};
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;
    use sui::transfer;
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use sui::math::pow;
    use sui::dynamic_field as df;
    use cny_game::listing::ListingCap;
    use cny_game::math::{mul_and_div, mul_and_div_u128};

    //***********************
    //  Constants
    //***********************

    public fun red_envelop_price_in_sui(): u64 { 10_000_000_000 }
    public fun sui_decimals(): u8 { 9 }
    public fun precision(): u128 { 1_000_000_000_000_000_000 }
    public fun precision_decimals(): u8 { 18 }

    //***********************
    //  Errors
    //***********************

    const EPriceOutdated: u64 = 0;
    const EPriceFeedNotExists: u64 = 1;
    const EPriceFeedAlreadyExists: u64 = 2;
    const EInvalidRule: u64 = 3;

    //***********************
    //  Objects
    //***********************

    struct Oracle has key {
        id: UID,
    }

    struct PriceFeed<phantom T> has store {
        price_against_sui: u128,
        latest_update_time: u64,
        decimals: u8,
        tolerance_ms: u64,
        rule: TypeName,
    }

    //***********************
    //  Constructor
    //***********************

    fun init(ctx: &mut TxContext) {
        let oracle = Oracle {
            id: object::new(ctx),
        };
        transfer::share_object(oracle);
    }

    //***********************
    //  Admin Functions
    //***********************

    public fun add_price_feed<T, Rule: drop>(
        _: &ListingCap,
        oracle: &mut Oracle,
        decimals: u8,
        tolerance_ms: u64,
    ) {
        let coin_type = type_name::get<T>();
        assert!(
            !df::exists_with_type<TypeName, PriceFeed<T>>(&oracle.id, coin_type),
            EPriceFeedAlreadyExists,
        );
        let price_feed = PriceFeed<T> {
            price_against_sui: 0,
            latest_update_time: 0,
            tolerance_ms,
            decimals,
            rule: type_name::get<Rule>(),
        };
        df::add(&mut oracle.id, coin_type, price_feed);
    }

    public fun remove_price_feed<T>(
        _: &ListingCap,
        oracle: &mut Oracle,
    ) {
        let coin_type = type_name::get<T>();
        assert!(
            df::exists_with_type<TypeName, PriceFeed<T>>(&oracle.id, coin_type),
            EPriceFeedAlreadyExists,
        );
        let price_feed = df::remove<TypeName, PriceFeed<T>>(
            &mut oracle.id, coin_type,
        );
        let PriceFeed { 
            price_against_sui: _,
            latest_update_time: _,
            tolerance_ms: _,
            decimals: _,
            rule: _,
        } = price_feed;
    }

    public fun change_rule<T, NewRule: drop>(
        _: &ListingCap,
        oracle: &mut Oracle,
    ) {
        let price_feed = borrow_price_feed_mut<T>(oracle);
        price_feed.rule = type_name::get<NewRule>();
    }

    public fun update_tolerance_ms<T>(
        _: &ListingCap,
        oracle: &mut Oracle,
        tolerance_ms: u64,
    ) {
       let price_feed = borrow_price_feed_mut<T>(oracle);
       price_feed.tolerance_ms = tolerance_ms;
    }

    //***********************
    //  Public Functions
    //***********************

    public fun update_price<T, Rule: drop>(
        _: Rule,
        oracle: &mut Oracle,
        clock: &Clock,
        price_against_sui: u128,
    ) {
        let rule_name = type_name::get<Rule>();
        let price_feed = borrow_price_feed_mut<T>(oracle);
        assert!(price_feed.rule == rule_name, EInvalidRule);
        let current_time = clock::timestamp_ms(clock);
        price_feed.latest_update_time = current_time;
        price_feed.price_against_sui = price_against_sui;
    }

    //***********************
    //  Getter Functions
    //***********************

    public fun red_envelop_price<T>(
        oracle: &Oracle,
        clock: &Clock,
    ): u64 {
        if (type_name::get<T>() == type_name::get<SUI>()) {
            red_envelop_price_in_sui()
        } else {
            let price_feed = borrow_price_feed<T>(oracle);
            let latest_update_time = price_feed.latest_update_time;
            let current_time = clock::timestamp_ms(clock);
            assert!(
                current_time - latest_update_time <= price_feed.tolerance_ms,
                EPriceOutdated,
            );
            let price_against_sui = price_feed.price_against_sui;
            let amount_to_pay = mul_and_div_u128(
                red_envelop_price_in_sui(),
                precision(),
                price_against_sui
            );
            handle_decimal_diff(amount_to_pay, price_feed.decimals)
        }
    }

    //***********************
    //  Internal Functions
    //***********************

    fun borrow_price_feed<T>(oracle: &Oracle): &PriceFeed<T> {
        let coin_type = type_name::get<T>();
        assert!(
            df::exists_with_type<TypeName, PriceFeed<T>>(&oracle.id, coin_type),
            EPriceFeedNotExists,
        );
        df::borrow<TypeName, PriceFeed<T>>(&oracle.id, coin_type)
    }

    fun borrow_price_feed_mut<T>(oracle: &mut Oracle): &mut PriceFeed<T> {
        let coin_type = type_name::get<T>();
        assert!(
            df::exists_with_type<TypeName, PriceFeed<T>>(&oracle.id, coin_type),
            EPriceFeedNotExists,
        );
        df::borrow_mut<TypeName, PriceFeed<T>>(&mut oracle.id, coin_type)
    }

    fun handle_decimal_diff(amount_to_pay: u64, target_decimals: u8): u64 {
        let sui_decimals = sui_decimals();
        if (sui_decimals > target_decimals) {
            mul_and_div(
                amount_to_pay,
                1,
                pow(10, sui_decimals - target_decimals),
            )
        } else if (sui_decimals < target_decimals) {
            mul_and_div(
                amount_to_pay,
                pow(10, sui_decimals - target_decimals),
                1,
            )
        } else {
            amount_to_pay
        }
    }

    //***********************
    //  Test-only Functions
    //***********************

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    #[test_only]
    public fun update_for_testing<T>(
        price_feed: &mut PriceFeed<T>,
        clock: &Clock,
        price_against_sui: u128,
    ) {
        price_feed.latest_update_time = clock::timestamp_ms(clock);
        price_feed.price_against_sui = price_against_sui;
    }
}
