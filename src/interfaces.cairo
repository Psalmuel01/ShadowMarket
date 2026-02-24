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
pub trait INullifierRegistry<TContractState> {
    fn is_used(self: @TContractState, nullifier: felt252) -> bool;
    fn mark_used(ref self: TContractState, nullifier: felt252);
}

#[starknet::interface]
pub trait IShieldVault<TContractState> {
    fn release_payout(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn is_authorized_market(self: @TContractState, market: ContractAddress) -> bool;
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
