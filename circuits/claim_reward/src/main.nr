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
    market_id: Field,
    expected_commitment: pub Field,
    market_outcome: pub Field,
    nullifier: pub Field,
    payout: pub Field,
) {
    let computed_commitment = hash5(
        user_secret,
        market_id,
        position_side,
        amount,
        blinding_factor,
    );
    assert(computed_commitment == expected_commitment);

    // Side must match resolved outcome (0/1 boolean encoding).
    assert(position_side == market_outcome);

    let computed_nullifier = hash_2([user_secret, market_id]);
    assert(computed_nullifier == nullifier);

    // Example payout function; replace with market-specific logic.
    let expected_payout = amount * 2;
    assert(expected_payout == payout);
}
