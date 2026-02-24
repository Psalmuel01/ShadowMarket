#[starknet::contract]
pub mod Market {
    use crate::interfaces::{
        INullifierRegistryDispatcher, INullifierRegistryDispatcherTrait, IShieldVaultDispatcher,
        IShieldVaultDispatcherTrait, IVerifierDispatcher, IVerifierDispatcherTrait,
    };
    use crate::merkle_tree_lib::{TREE_CAPACITY, TREE_DEPTH};
    use crate::merkle_tree_lib as MerkleTreeLib;
    use starknet::ContractAddress;
    use starknet::contract_address_const;
    use starknet::get_block_timestamp;
    use starknet::get_caller_address;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        market_id: u64,
        oracle: ContractAddress,
        end_time: u64,
        verifier: ContractAddress,
        nullifier_registry: ContractAddress,
        shield_vault: ContractAddress,
        merkle_root: felt252,
        next_index: u32,
        filled_subtrees: Map<u32, felt252>,
        resolution_outcome: bool,
        is_resolved: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CommitmentAdded: CommitmentAdded,
        MarketResolved: MarketResolved,
        RewardClaimed: RewardClaimed,
    }

    #[derive(Drop, starknet::Event)]
    struct CommitmentAdded {
        #[key]
        commitment: felt252,
        new_root: felt252,
        leaf_index: u32,
    }

    #[derive(Drop, starknet::Event)]
    struct MarketResolved {
        outcome: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct RewardClaimed {
        #[key]
        nullifier: felt252,
        #[key]
        recipient: ContractAddress,
        payout: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        market_id: u64,
        oracle: ContractAddress,
        end_time: u64,
        verifier: ContractAddress,
        nullifier_registry: ContractAddress,
        shield_vault: ContractAddress,
    ) {
        self.market_id.write(market_id);
        self.oracle.write(oracle);
        self.end_time.write(end_time);
        self.verifier.write(verifier);
        self.nullifier_registry.write(nullifier_registry);
        self.shield_vault.write(shield_vault);
        self.merkle_root.write(MerkleTreeLib::zero_hash(TREE_DEPTH));
        self.next_index.write(0_u32);
        self.resolution_outcome.write(false);
        self.is_resolved.write(false);
    }

    #[external(v0)]
    fn add_commitment(
        ref self: ContractState,
        commitment: felt252,
        program_hash: felt252,
        public_inputs: Span<felt252>,
        proof: Span<felt252>,
    ) -> felt252 {
        self.assert_not_resolved();

        let verified = IVerifierDispatcher { contract_address: self.verifier.read() }
            .verify_proof(program_hash, public_inputs, proof);
        assert(verified, 'INVALID_PROOF');

        let (new_root, leaf_index) = self.append_commitment_and_compute_root(commitment);
        self.emit(CommitmentAdded { commitment, new_root, leaf_index });
        new_root
    }

    #[external(v0)]
    fn resolve_market(ref self: ContractState, outcome: bool) {
        assert(get_caller_address() == self.oracle.read(), 'NOT_ORACLE');
        assert(!self.is_resolved.read(), 'ALREADY_RESOLVED');
        assert(get_block_timestamp() >= self.end_time.read(), 'MARKET_OPEN');

        self.resolution_outcome.write(outcome);
        self.is_resolved.write(true);
        self.emit(MarketResolved { outcome });
    }

    #[external(v0)]
    fn claim_reward(
        ref self: ContractState,
        nullifier: felt252,
        payout_recipient: ContractAddress,
        payout_amount: u256,
        program_hash: felt252,
        public_inputs: Span<felt252>,
        proof: Span<felt252>,
    ) {
        assert(self.is_resolved.read(), 'NOT_RESOLVED');

        let nullifier_registry = INullifierRegistryDispatcher {
            contract_address: self.nullifier_registry.read(),
        };
        assert(!nullifier_registry.is_used(nullifier), 'NULLIFIER_USED');

        let verified = IVerifierDispatcher { contract_address: self.verifier.read() }
            .verify_proof(program_hash, public_inputs, proof);
        assert(verified, 'INVALID_PROOF');

        nullifier_registry.mark_used(nullifier);

        let vault = self.shield_vault.read();
        if vault != contract_address_const::<0>() {
            IShieldVaultDispatcher { contract_address: vault }
                .release_payout(payout_recipient, payout_amount);
        };

        self.emit(RewardClaimed { nullifier, recipient: payout_recipient, payout: payout_amount });
    }

    #[external(v0)]
    fn market_id(self: @ContractState) -> u64 {
        self.market_id.read()
    }

    #[external(v0)]
    fn oracle(self: @ContractState) -> ContractAddress {
        self.oracle.read()
    }

    #[external(v0)]
    fn end_time(self: @ContractState) -> u64 {
        self.end_time.read()
    }

    #[external(v0)]
    fn merkle_root(self: @ContractState) -> felt252 {
        self.merkle_root.read()
    }

    #[external(v0)]
    fn next_index(self: @ContractState) -> u32 {
        self.next_index.read()
    }

    #[external(v0)]
    fn is_resolved(self: @ContractState) -> bool {
        self.is_resolved.read()
    }

    #[external(v0)]
    fn resolution_outcome(self: @ContractState) -> bool {
        self.resolution_outcome.read()
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_not_resolved(self: @ContractState) {
            assert(!self.is_resolved.read(), 'MARKET_RESOLVED');
        }

        fn append_commitment_and_compute_root(
            ref self: ContractState, commitment: felt252,
        ) -> (felt252, u32) {
            let leaf_index = self.next_index.read();
            assert(leaf_index < TREE_CAPACITY, 'TREE_FULL');

            let mut node = commitment;
            let mut idx = leaf_index;
            let mut level = 0_u32;
            loop {
                if level == TREE_DEPTH {
                    break;
                };

                if idx % 2_u32 == 0_u32 {
                    self.filled_subtrees.write(level, node);
                    let zero = MerkleTreeLib::zero_hash(level);
                    node = MerkleTreeLib::poseidon_pair(node, zero);
                } else {
                    let left = self.filled_subtrees.read(level);
                    node = MerkleTreeLib::poseidon_pair(left, node);
                };

                idx = idx / 2_u32;
                level += 1_u32;
            };

            self.next_index.write(leaf_index + 1_u32);
            self.merkle_root.write(node);
            (node, leaf_index)
        }
    }
}
