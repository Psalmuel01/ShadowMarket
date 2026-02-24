use std::hash::poseidon::bn254::hash_2;

fn hash5(a: Field, b: Field, c: Field, d: Field, e: Field) -> Field {
    // 5-field commitment hash built from Poseidon pair compression.
    let ab = hash_2([a, b]);
    let cd = hash_2([c, d]);
    let e0 = hash_2([e, 0]);
    hash_2([hash_2([ab, cd]), e0])
}

fn main(
    user_secret: Field,
    position_side: Field,
    amount: Field,
    blinding_factor: Field,
    market_id: pub Field,
    commitment: pub Field,
    old_merkle_root: pub Field,
    new_merkle_root: pub Field,
) {
    let computed_commitment = hash5(
        user_secret,
        market_id,
        position_side,
        amount,
        blinding_factor,
    );
    assert(computed_commitment == commitment);
    assert(amount > 0);

    // This models incremental insertion transition.
    let expected_new_root = hash_2([old_merkle_root, commitment]);
    assert(expected_new_root == new_merkle_root);
}
