use core::pedersen::pedersen;

pub const TREE_DEPTH: u32 = 20;
pub const TREE_CAPACITY: u32 = 1048576;

pub fn hash_pair(left: felt252, right: felt252) -> felt252 {
    pedersen(left, right)
}

pub fn commitment_hash(
    user_secret: felt252,
    market_id: felt252,
    position_side: felt252,
    amount: felt252,
    blinding_factor: felt252,
) -> felt252 {
    // Keep Cairo/Noir commitment derivation aligned via Pedersen pair-compression tree.
    let ab = hash_pair(user_secret, market_id);
    let cd = hash_pair(position_side, amount);
    let e0 = hash_pair(blinding_factor, 0);
    hash_pair(hash_pair(ab, cd), e0)
}

pub fn nullifier_hash(user_secret: felt252, market_id: felt252) -> felt252 {
    hash_pair(user_secret, market_id)
}

pub fn zero_hash(level: u32) -> felt252 {
    let mut node = 0;
    let mut i = 0_u32;
    loop {
        if i == level {
            break;
        };
        node = hash_pair(node, node);
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
            node = hash_pair(node, sibling);
        } else {
            node = hash_pair(sibling, node);
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
