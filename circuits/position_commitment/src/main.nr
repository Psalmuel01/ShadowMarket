use std::hash::pedersen_hash;

global TREE_DEPTH: u32 = 20;

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
// 1: leaf_index
// 2: commitment
// 3: old_merkle_root
// 4: new_merkle_root
fn main(
    user_secret: Field,
    position_side: u1,
    amount: u64,
    blinding_factor: Field,
    merkle_siblings: [Field; TREE_DEPTH],
    market_id: pub Field,
    leaf_index: pub u32,
    commitment: pub Field,
    old_merkle_root: pub Field,
    new_merkle_root: pub Field,
) {
    assert(amount > 0);

    let computed_commitment = commitment_hash(
        user_secret,
        market_id,
        position_side,
        amount,
        blinding_factor,
    );
    assert(computed_commitment == commitment);

    // Prove old root corresponds to an empty leaf at `leaf_index`,
    // and new root corresponds to inserting `commitment` at the same index.
    let mut old_node = 0;
    let mut new_node = computed_commitment;
    for level in 0..TREE_DEPTH {
        let bit: u1 = ((leaf_index >> level) & 1) as u1;
        let sibling = merkle_siblings[level];

        if bit == 0 {
            old_node = hash_pair(old_node, sibling);
            new_node = hash_pair(new_node, sibling);
        } else {
            old_node = hash_pair(sibling, old_node);
            new_node = hash_pair(sibling, new_node);
        }
    }

    assert(old_node == old_merkle_root);
    assert(new_node == new_merkle_root);
}
