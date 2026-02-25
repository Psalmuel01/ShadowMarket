use shadow_market::interfaces::{
    IMarketDispatcher, IMarketDispatcherTrait, IMockGaragaVerifierAdminDispatcher,
    IMockGaragaVerifierAdminDispatcherTrait,
    INullifierRegistryAdminDispatcher, INullifierRegistryAdminDispatcherTrait,
    INullifierRegistryDispatcher, INullifierRegistryDispatcherTrait, IVerifierAdminDispatcher,
    IVerifierAdminDispatcherTrait,
};
use shadow_market::merkle_tree_lib::{TREE_DEPTH};
use shadow_market::merkle_tree_lib as MerkleTreeLib;
use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, test_address,
    ContractClassTrait, DeclareResultTrait,
};
use starknet::ContractAddress;

const MARKET_ID: u64 = 42;
const POSITION_PROGRAM_HASH: felt252 = 1111;
const CLAIM_PROGRAM_HASH: felt252 = 2222;

#[derive(Copy, Drop)]
struct Setup {
    owner: ContractAddress,
    oracle: ContractAddress,
    market: ContractAddress,
    nullifier_registry: ContractAddress,
    verifier: ContractAddress,
    mock_garaga: ContractAddress,
}

fn deploy_contract(name: ByteArray, constructor_calldata: Array<felt252>) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

fn as_felt(addr: ContractAddress) -> felt252 {
    addr.into()
}

fn compute_root_for_first_insertion(commitment: felt252) -> felt252 {
    let mut node = commitment;
    let mut level = 0_u32;
    loop {
        if level == TREE_DEPTH {
            break;
        };
        node = MerkleTreeLib::hash_pair(node, MerkleTreeLib::zero_hash(level));
        level += 1_u32;
    };
    node
}

fn setup_market(default_mock_result: bool) -> Setup {
    let owner = addr(111);
    let oracle = addr(222);

    let mock_garaga = deploy_contract(
        "MockGaragaVerifier", array![as_felt(owner), if default_mock_result { 1 } else { 0 }],
    );
    let verifier = deploy_contract("Verifier", array![as_felt(owner), as_felt(mock_garaga)]);
    let nullifier_registry = deploy_contract("NullifierRegistry", array![as_felt(owner)]);
    let market = deploy_contract(
        "Market",
        array![
            MARKET_ID.into(),
            as_felt(oracle),
            0, // end_time
            as_felt(verifier),
            as_felt(nullifier_registry),
            0, // shield vault disabled
        ],
    );

    start_cheat_caller_address(verifier, owner);
    IVerifierAdminDispatcher { contract_address: verifier }
        .set_program_hash(POSITION_PROGRAM_HASH, true);
    IVerifierAdminDispatcher { contract_address: verifier }.set_program_hash(CLAIM_PROGRAM_HASH, true);
    stop_cheat_caller_address(verifier);

    start_cheat_caller_address(nullifier_registry, owner);
    INullifierRegistryAdminDispatcher { contract_address: nullifier_registry }
        .set_authorized_caller(market, true);
    stop_cheat_caller_address(nullifier_registry);

    Setup { owner, oracle, market, nullifier_registry, verifier, mock_garaga }
}

fn seed_one_commitment(setup: Setup, commitment: felt252) -> felt252 {
    let market = IMarketDispatcher { contract_address: setup.market };
    let old_root = market.merkle_root();
    let expected_new_root = compute_root_for_first_insertion(commitment);

    let add_public_inputs = array![
        MARKET_ID.into(),
        0, // leaf_index
        commitment,
        old_root,
        expected_new_root,
    ];
    let dummy_proof = array![1];
    let returned_root = market.add_commitment(
        commitment, POSITION_PROGRAM_HASH, add_public_inputs.span(), dummy_proof.span(),
    );
    assert(returned_root == expected_new_root, 'BAD_ROOT_RETURN');
    returned_root
}

fn resolve_market_true(setup: Setup) {
    start_cheat_caller_address(setup.market, setup.oracle);
    IMarketDispatcher { contract_address: setup.market }.resolve_market(true);
    stop_cheat_caller_address(setup.market);
}

#[test]
fn test_happy_path_claim_marks_nullifier() {
    let setup = setup_market(true);
    let recipient = test_address();

    let commitment = 777;
    let root = seed_one_commitment(setup, commitment);
    resolve_market_true(setup);

    let nullifier = 888;
    let payout_amount = u256 { low: 200, high: 0 };
    let claim_public_inputs = array![
        MARKET_ID.into(),
        root,
        1, // outcome true
        nullifier,
        payout_amount.low.into(),
        payout_amount.high.into(),
        as_felt(recipient),
    ];
    let dummy_proof = array![2];

    IMarketDispatcher { contract_address: setup.market }.claim_reward(
        nullifier,
        recipient,
        payout_amount,
        CLAIM_PROGRAM_HASH,
        claim_public_inputs.span(),
        dummy_proof.span(),
    );

    let used = INullifierRegistryDispatcher { contract_address: setup.nullifier_registry }
        .is_used(nullifier);
    assert(used, 'NULLIFIER_NOT_MARKED');
}

#[test]
#[should_panic(expected: ('NULLIFIER_USED',))]
fn test_double_claim_rejected() {
    let setup = setup_market(true);
    let recipient = test_address();

    let commitment = 9001;
    let root = seed_one_commitment(setup, commitment);
    resolve_market_true(setup);

    let nullifier = 4444;
    let payout_amount = u256 { low: 100, high: 0 };
    let claim_public_inputs = array![
        MARKET_ID.into(),
        root,
        1,
        nullifier,
        payout_amount.low.into(),
        payout_amount.high.into(),
        as_felt(recipient),
    ];
    let dummy_proof = array![3];

    let dispatcher = IMarketDispatcher { contract_address: setup.market };
    dispatcher.claim_reward(
        nullifier,
        recipient,
        payout_amount,
        CLAIM_PROGRAM_HASH,
        claim_public_inputs.span(),
        dummy_proof.span(),
    );

    dispatcher.claim_reward(
        nullifier,
        recipient,
        payout_amount,
        CLAIM_PROGRAM_HASH,
        claim_public_inputs.span(),
        dummy_proof.span(),
    );
}

#[test]
#[should_panic(expected: ('INVALID_PROOF',))]
fn test_claim_with_invalid_proof_rejected() {
    let setup = setup_market(true);
    let recipient = test_address();

    let commitment = 5151;
    let root = seed_one_commitment(setup, commitment);
    resolve_market_true(setup);

    // Force claim program verification to return false in mock Garaga.
    start_cheat_caller_address(setup.mock_garaga, setup.owner);
    IMockGaragaVerifierAdminDispatcher { contract_address: setup.mock_garaga }
        .set_program_result(CLAIM_PROGRAM_HASH, false);
    stop_cheat_caller_address(setup.mock_garaga);

    let nullifier = 6161;
    let payout_amount = u256 { low: 50, high: 0 };
    let claim_public_inputs = array![
        MARKET_ID.into(),
        root,
        1,
        nullifier,
        payout_amount.low.into(),
        payout_amount.high.into(),
        as_felt(recipient),
    ];
    let dummy_proof = array![4];

    IMarketDispatcher { contract_address: setup.market }.claim_reward(
        nullifier,
        recipient,
        payout_amount,
        CLAIM_PROGRAM_HASH,
        claim_public_inputs.span(),
        dummy_proof.span(),
    );
}

#[test]
#[should_panic(expected: ('PI_OUTCOME',))]
fn test_claim_with_wrong_outcome_binding_rejected() {
    let setup = setup_market(true);
    let recipient = test_address();

    let commitment = 7007;
    let root = seed_one_commitment(setup, commitment);
    resolve_market_true(setup);

    let nullifier = 8008;
    let payout_amount = u256 { low: 50, high: 0 };
    // Outcome intentionally wrong: market resolved true, but public input says false.
    let claim_public_inputs = array![
        MARKET_ID.into(),
        root,
        0,
        nullifier,
        payout_amount.low.into(),
        payout_amount.high.into(),
        as_felt(recipient),
    ];
    let dummy_proof = array![5];

    IMarketDispatcher { contract_address: setup.market }.claim_reward(
        nullifier,
        recipient,
        payout_amount,
        CLAIM_PROGRAM_HASH,
        claim_public_inputs.span(),
        dummy_proof.span(),
    );
}
