use starknet::ContractAddress;

#[starknet::interface]
pub trait IVerifier<TContractState> {
    fn verify_proof(
        self: @TContractState,
        program_hash: felt252,
        public_inputs: Span<felt252>,
        proof: Span<felt252>,
    ) -> bool;
}

#[starknet::interface]
pub trait IGaragaVerifier<TContractState> {
    fn verify_proof(
        self: @TContractState,
        program_hash: felt252,
        public_inputs: Span<felt252>,
        proof: Span<felt252>,
    ) -> bool;
}

#[starknet::interface]
pub trait IVerifierAdmin<TContractState> {
    fn set_program_hash(ref self: TContractState, program_hash: felt252, enabled: bool);
    fn set_program_hashes(ref self: TContractState, program_hashes: Span<felt252>, enabled: bool);
    fn set_garaga_verifier(ref self: TContractState, garaga_verifier: ContractAddress);
}

#[starknet::interface]
pub trait INullifierRegistry<TContractState> {
    fn is_used(self: @TContractState, nullifier: felt252) -> bool;
    fn mark_used(ref self: TContractState, nullifier: felt252);
}

#[starknet::interface]
pub trait INullifierRegistryAdmin<TContractState> {
    fn set_authorized_caller(
        ref self: TContractState, caller: ContractAddress, is_authorized: bool,
    );
}

#[starknet::interface]
pub trait IMarket<TContractState> {
    fn add_commitment(
        ref self: TContractState,
        commitment: felt252,
        program_hash: felt252,
        public_inputs: Span<felt252>,
        proof: Span<felt252>,
    ) -> felt252;
    fn resolve_market(ref self: TContractState, outcome: bool);
    fn claim_reward(
        ref self: TContractState,
        nullifier: felt252,
        payout_recipient: ContractAddress,
        payout_amount: u256,
        program_hash: felt252,
        public_inputs: Span<felt252>,
        proof: Span<felt252>,
    );
    fn merkle_root(self: @TContractState) -> felt252;
}

#[starknet::interface]
pub trait IShieldVault<TContractState> {
    fn release_payout(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn is_authorized_market(self: @TContractState, market: ContractAddress) -> bool;
}

#[starknet::interface]
pub trait IShieldVaultUser<TContractState> {
    fn deposit(ref self: TContractState, amount: u256, encrypted_balance_commitment: felt252);
    fn withdraw(
        ref self: TContractState,
        amount: u256,
        recipient: ContractAddress,
        nullifier: felt252,
        program_hash: felt252,
        public_inputs: Span<felt252>,
        proof: Span<felt252>,
    );
    fn note_merkle_root(self: @TContractState) -> felt252;
    fn next_note_index(self: @TContractState) -> u32;
    fn has_balance_commitment(self: @TContractState, encrypted_balance_commitment: felt252) -> bool;
    fn is_withdraw_nullifier_used(self: @TContractState, nullifier: felt252) -> bool;
}

#[starknet::interface]
pub trait IERC20<TContractState> {
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TContractState,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
    ) -> bool;
}

#[starknet::interface]
pub trait IMockERC20Admin<TContractState> {
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256);
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    fn balance_of(self: @TContractState, owner: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
}

#[starknet::interface]
pub trait IMockGaragaVerifierAdmin<TContractState> {
    fn set_default_result(ref self: TContractState, value: bool);
    fn set_program_result(ref self: TContractState, program_hash: felt252, value: bool);
}
