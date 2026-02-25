use shadow_market::interfaces::{
    IMockERC20AdminDispatcher, IMockERC20AdminDispatcherTrait,
    IMockGaragaVerifierAdminDispatcher, IMockGaragaVerifierAdminDispatcherTrait,
    IShieldVaultUserDispatcher, IShieldVaultUserDispatcherTrait, IVerifierAdminDispatcher,
    IVerifierAdminDispatcherTrait,
};
use shadow_market::merkle_tree_lib::{TREE_DEPTH};
use shadow_market::merkle_tree_lib as MerkleTreeLib;
use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait,
};
use starknet::ContractAddress;

const WITHDRAW_PROGRAM_HASH: felt252 = 3333;

#[derive(Copy, Drop)]
struct Setup {
    owner: ContractAddress,
    user: ContractAddress,
    recipient: ContractAddress,
    token: ContractAddress,
    mock_garaga: ContractAddress,
    verifier: ContractAddress,
    vault: ContractAddress,
}

fn deploy_contract(name: ByteArray, constructor_calldata: Array<felt252>) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
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

fn setup_vault(mock_verification_result: bool) -> Setup {
    let owner = addr(11);
    let user = addr(22);
    let recipient = addr(33);

    let mock_garaga = deploy_contract(
        "MockGaragaVerifier", array![owner.into(), if mock_verification_result { 1 } else { 0 }],
    );
    let verifier = deploy_contract("Verifier", array![owner.into(), mock_garaga.into()]);
    let token = deploy_contract("MockERC20", array![owner.into()]);
    let vault = deploy_contract(
        "ShieldVault", array![owner.into(), verifier.into(), token.into()],
    );

    start_cheat_caller_address(verifier, owner);
    IVerifierAdminDispatcher { contract_address: verifier }
        .set_program_hash(WITHDRAW_PROGRAM_HASH, true);
    stop_cheat_caller_address(verifier);

    start_cheat_caller_address(token, owner);
    IMockERC20AdminDispatcher { contract_address: token }
        .mint(user, u256 { low: 500, high: 0 });
    stop_cheat_caller_address(token);

    start_cheat_caller_address(token, user);
    IMockERC20AdminDispatcher { contract_address: token }
        .approve(vault, u256 { low: 500, high: 0 });
    stop_cheat_caller_address(token);

    Setup { owner, user, recipient, token, mock_garaga, verifier, vault }
}

fn deposit_one_note(setup: Setup, commitment: felt252, amount: u256) -> felt252 {
    start_cheat_caller_address(setup.vault, setup.user);
    IShieldVaultUserDispatcher { contract_address: setup.vault }.deposit(amount, commitment);
    stop_cheat_caller_address(setup.vault);

    IShieldVaultUserDispatcher { contract_address: setup.vault }.note_merkle_root()
}

#[test]
fn test_deposit_updates_note_root_and_balances() {
    let setup = setup_vault(true);
    let commitment = 12345;
    let amount = u256 { low: 200, high: 0 };
    let expected_root = compute_root_for_first_insertion(commitment);

    let root_after_deposit = deposit_one_note(setup, commitment, amount);
    assert(root_after_deposit == expected_root, 'BAD_NOTE_ROOT');

    let vault = IShieldVaultUserDispatcher { contract_address: setup.vault };
    assert(vault.next_note_index() == 1_u32, 'BAD_NOTE_INDEX');
    assert(vault.has_balance_commitment(commitment), 'MISSING_COMMITMENT');

    let token = IMockERC20AdminDispatcher { contract_address: setup.token };
    assert(token.balance_of(setup.user) == u256 { low: 300, high: 0 }, 'BAD_USER_BAL');
    assert(token.balance_of(setup.vault) == amount, 'BAD_VAULT_BAL');
}

#[test]
fn test_withdraw_updates_root_and_transfers() {
    let setup = setup_vault(true);
    let amount = u256 { low: 100, high: 0 };
    let old_root = deposit_one_note(setup, 9876, amount);
    let new_root = old_root;
    let nullifier = 4444;

    let public_inputs = array![
        nullifier,
        amount.low.into(),
        amount.high.into(),
        setup.recipient.into(),
        old_root,
        new_root,
    ];
    let proof = array![1];

    start_cheat_caller_address(setup.vault, setup.user);
    IShieldVaultUserDispatcher { contract_address: setup.vault }.withdraw(
        amount,
        setup.recipient,
        nullifier,
        WITHDRAW_PROGRAM_HASH,
        public_inputs.span(),
        proof.span(),
    );
    stop_cheat_caller_address(setup.vault);

    let vault = IShieldVaultUserDispatcher { contract_address: setup.vault };
    assert(vault.note_merkle_root() == old_root, 'ROOT_NOT_UPDATED');
    assert(vault.is_withdraw_nullifier_used(nullifier), 'NULLIFIER_NOT_USED');

    let token = IMockERC20AdminDispatcher { contract_address: setup.token };
    assert(token.balance_of(setup.recipient) == amount, 'BAD_RECIPIENT_BAL');
    assert(token.balance_of(setup.vault) == u256 { low: 0, high: 0 }, 'BAD_VAULT_BAL');
}

#[test]
#[should_panic(expected: ('NULLIFIER_USED',))]
fn test_withdraw_replay_rejected() {
    let setup = setup_vault(true);
    let amount = u256 { low: 100, high: 0 };
    let old_root = deposit_one_note(setup, 5001, amount);
    let new_root = old_root;
    let nullifier = 7001;
    let public_inputs = array![
        nullifier,
        amount.low.into(),
        amount.high.into(),
        setup.recipient.into(),
        old_root,
        new_root,
    ];
    let proof = array![2];
    let dispatcher = IShieldVaultUserDispatcher { contract_address: setup.vault };

    start_cheat_caller_address(setup.vault, setup.user);
    dispatcher.withdraw(
        amount,
        setup.recipient,
        nullifier,
        WITHDRAW_PROGRAM_HASH,
        public_inputs.span(),
        proof.span(),
    );
    dispatcher.withdraw(
        amount,
        setup.recipient,
        nullifier,
        WITHDRAW_PROGRAM_HASH,
        public_inputs.span(),
        proof.span(),
    );
    stop_cheat_caller_address(setup.vault);
}

#[test]
#[should_panic(expected: ('PI_OLD_ROOT',))]
fn test_withdraw_wrong_old_root_rejected() {
    let setup = setup_vault(true);
    let amount = u256 { low: 100, high: 0 };
    let _ = deposit_one_note(setup, 9009, amount);
    let nullifier = 9010;
    let public_inputs = array![
        nullifier,
        amount.low.into(),
        amount.high.into(),
        setup.recipient.into(),
        123456789, // wrong old root
        42,
    ];
    let proof = array![3];

    start_cheat_caller_address(setup.vault, setup.user);
    IShieldVaultUserDispatcher { contract_address: setup.vault }.withdraw(
        amount,
        setup.recipient,
        nullifier,
        WITHDRAW_PROGRAM_HASH,
        public_inputs.span(),
        proof.span(),
    );
}

#[test]
#[should_panic(expected: ('PI_NEW_ROOT',))]
fn test_withdraw_wrong_new_root_rejected() {
    let setup = setup_vault(true);
    let amount = u256 { low: 100, high: 0 };
    let old_root = deposit_one_note(setup, 1111, amount);
    let nullifier = 2222;
    let public_inputs = array![
        nullifier,
        amount.low.into(),
        amount.high.into(),
        setup.recipient.into(),
        old_root,
        old_root + 1, // wrong new root
    ];
    let proof = array![5];

    start_cheat_caller_address(setup.vault, setup.user);
    IShieldVaultUserDispatcher { contract_address: setup.vault }.withdraw(
        amount,
        setup.recipient,
        nullifier,
        WITHDRAW_PROGRAM_HASH,
        public_inputs.span(),
        proof.span(),
    );
}

#[test]
#[should_panic(expected: ('INVALID_PROOF',))]
fn test_withdraw_invalid_proof_rejected() {
    let setup = setup_vault(true);
    let amount = u256 { low: 100, high: 0 };
    let old_root = deposit_one_note(setup, 10001, amount);
    let nullifier = 10002;
    let public_inputs = array![
        nullifier,
        amount.low.into(),
        amount.high.into(),
        setup.recipient.into(),
        old_root,
        old_root,
    ];
    let proof = array![4];

    start_cheat_caller_address(setup.mock_garaga, setup.owner);
    IMockGaragaVerifierAdminDispatcher { contract_address: setup.mock_garaga }
        .set_program_result(WITHDRAW_PROGRAM_HASH, false);
    stop_cheat_caller_address(setup.mock_garaga);

    start_cheat_caller_address(setup.vault, setup.user);
    IShieldVaultUserDispatcher { contract_address: setup.vault }.withdraw(
        amount,
        setup.recipient,
        nullifier,
        WITHDRAW_PROGRAM_HASH,
        public_inputs.span(),
        proof.span(),
    );
}
