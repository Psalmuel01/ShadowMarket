use std::hash::pedersen_hash;

global TREE_DEPTH: u32 = 20;
global MAX_PAYOUTABLE_AMOUNT: u64 = 9_223_372_036_854_775_807; // floor(u64::MAX / 2)

fn hash_pair(left: Field, right: Field) -> Field {
    pedersen_hash([left, right])
}

fn commitment_hash(
    user_secret: Field, market_id: Field, position_side: u1, amount: u64, blinding_factor: Field,
) -> Field {
    // Matches Cairo `merkle_tree_lib::commitment_hash`.
    let ab = hash_pair(user_secret, market_id);
    let cd = hash_pair(position_side as Field, amount as Field);
    let e0 = hash_pair(blinding_factor, 0);
    hash_pair(hash_pair(ab, cd), e0)
}

// Public input schema (order is strict and bound in Market.cairo):
// 0: market_id
// 1: market_root
// 2: market_outcome
// 3: nullifier
// 4: payout_low
// 5: payout_high
// 6: payout_recipient
fn main(
    user_secret: Field,
    position_side: u1,
    amount: u64,
    blinding_factor: Field,
    leaf_index: u32,
    merkle_siblings: [Field; TREE_DEPTH],
    market_id: pub Field,
    market_root: pub Field,
    market_outcome: pub u1,
    nullifier: pub Field,
    payout_low: pub Field,
    payout_high: pub Field,
    _payout_recipient: pub Field,
) {
    assert(amount > 0);
    assert(amount <= MAX_PAYOUTABLE_AMOUNT);

    let commitment = commitment_hash(
        user_secret,
        market_id,
        position_side,
        amount,
        blinding_factor,
    );

    // Membership proof against current market root.
    let mut node = commitment;
    for level in 0..TREE_DEPTH {
        let bit: u1 = ((leaf_index >> level) & 1) as u1;
        let sibling = merkle_siblings[level];

        if bit == 0 {
            node = hash_pair(node, sibling);
        } else {
            node = hash_pair(sibling, node);
        }
    }
    assert(node == market_root);

    // Must be on winning side.
    assert(position_side == market_outcome);

    // Nullifier derivation.
    let computed_nullifier = hash_pair(user_secret, market_id);
    assert(computed_nullifier == nullifier);

    // Exact payout rule (current MVP): 2x stake, u256 low/high encoding.
    let expected_payout_low = (amount * 2) as Field;
    assert(payout_low == expected_payout_low);
    assert(payout_high == 0);
}
