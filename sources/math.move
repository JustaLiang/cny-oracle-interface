module cny_game::math {
    
    use sui::bls12381::bls12381_min_pk_verify;
    use sui::hash::blake2b256;

    //***********************
    //  Errors
    //***********************

    const EInvalidBlsSig: u64 = 0;

    //***********************
    //  Public Functions
    //***********************

    public fun max_u64(): u64 { 0xffffffffffffffff }

    public fun mul_and_div(x: u64, n: u64, m: u64): u64 {
        ((((x as u128) * (n as u128))/(m as u128)) as u64)
    }

    public fun mul_and_div_u128(x: u64, n: u128, m: u128): u64 {
        (((x as u128) * n / m) as u64)
    }

    public fun bytes_to_u256(bytes: &vector<u8>): u256 {
        let output: u256 = 0;
        let bytes_length: u64 = 32;
        let idx: u64 = 0;
        while (idx < bytes_length) {
            let current_byte = *std::vector::borrow(bytes, idx);
            output = (output << 8) | (current_byte as u256) ;
            idx = idx + 1;
        };
        output
    }

    public fun verify_bls_sig_and_give_result(
        bls_sig: &vector<u8>,
        pub_key: &vector<u8>,
        seed: &vector<u8>,
        range: u64,
    ): u64 {
        assert!(
            bls12381_min_pk_verify(bls_sig, pub_key, seed),
            EInvalidBlsSig,
        );
        let hashed = blake2b256(bls_sig);
        let big_num = bytes_to_u256(&hashed);
        let range = (range as u256);
        ((big_num % range) as u64)
    }

    #[test]
    fun test_blake2b256() {
        let msg = vector[1,2,3];
        let hashed = blake2b256(&msg);
        std::debug::print(&hashed);
        let num_u256 = bytes_to_u256(&hashed);
        std::debug::print(&num_u256);
        let result = ((num_u256 % 1000u256) as u64);
        std::debug::print(&result);
    }
}
