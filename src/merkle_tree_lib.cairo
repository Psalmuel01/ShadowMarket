use core::poseidon::poseidon_hash_span;

pub const TREE_DEPTH: u32 = 20;
pub const TREE_CAPACITY: u32 = 1048576;

pub fn poseidon_pair(left: felt252, right: felt252) -> felt252 {
    let data = array![left, right];
    poseidon_hash_span(data.span())
}

pub fn poseidon_five(
    a: felt252, b: felt252, c: felt252, d: felt252, e: felt252,
) -> felt252 {
    let data = array![a, b, c, d, e];
    poseidon_hash_span(data.span())
}

pub fn commitment_hash(
    user_secret: felt252,
    market_id: felt252,
    position_side: felt252,
    amount: felt252,
    blinding_factor: felt252,
) -> felt252 {
    // Keep Cairo/Noir commitment derivation aligned via pair-compression tree.
    let ab = poseidon_pair(user_secret, market_id);
    let cd = poseidon_pair(position_side, amount);
    let e0 = poseidon_pair(blinding_factor, 0);
    poseidon_pair(poseidon_pair(ab, cd), e0)
}

pub fn nullifier_hash(user_secret: felt252, market_id: felt252) -> felt252 {
    poseidon_pair(user_secret, market_id)
}

pub fn zero_hash(level: u32) -> felt252 {
    let mut node = 0;
    let mut i = 0_u32;
    loop {
        if i == level {
            break;
        };
        node = poseidon_pair(node, node);
        i += 1_u32;
    };
    node
}

pub fn compute_root_from_path(leaf: felt252, path: Span<felt252>, index: u32) -> felt252 {
    let mut node = leaf;
    let mut idx = index;
    let mut i = 0_usize;
    loop {
        if i == path.len() {
            break;
        };
        let sibling = *path.at(i);
        if idx % 2_u32 == 0_u32 {
            node = poseidon_pair(node, sibling);
        } else {
            node = poseidon_pair(sibling, node);
        };
        idx = idx / 2_u32;
        i += 1_usize;
    };
    node
}

pub fn verify_merkle_path(
    leaf: felt252, path: Span<felt252>, index: u32, expected_root: felt252,
) -> bool {
    compute_root_from_path(leaf, path, index) == expected_root
}
