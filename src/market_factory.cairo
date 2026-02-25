#[starknet::contract]
pub mod MarketFactory {
    use crate::merkle_tree_lib as MerkleTreeLib;
    use core::serde::Serde;
    use starknet::ClassHash;
    use starknet::ContractAddress;
    use starknet::SyscallResultTrait;
    use starknet::get_caller_address;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::syscalls::deploy_syscall;

    #[storage]
    struct Storage {
        owner: ContractAddress,
        market_class_hash: ClassHash,
        verifier: ContractAddress,
        nullifier_registry: ContractAddress,
        shield_vault: ContractAddress,
        next_market_id: u64,
        markets_by_id: Map<u64, ContractAddress>,
        question_hash_by_id: Map<u64, felt252>,
        oracle_by_id: Map<u64, ContractAddress>,
        end_time_by_id: Map<u64, u64>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        MarketCreated: MarketCreated,
        MarketClassHashUpdated: MarketClassHashUpdated,
        DependenciesUpdated: DependenciesUpdated,
    }

    #[derive(Drop, starknet::Event)]
    struct MarketCreated {
        #[key]
        market_id: u64,
        #[key]
        market_address: ContractAddress,
        question_hash: felt252,
        oracle: ContractAddress,
        end_time: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct MarketClassHashUpdated {
        market_class_hash: ClassHash,
    }

    #[derive(Drop, starknet::Event)]
    struct DependenciesUpdated {
        verifier: ContractAddress,
        nullifier_registry: ContractAddress,
        shield_vault: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        market_class_hash: ClassHash,
        verifier: ContractAddress,
        nullifier_registry: ContractAddress,
        shield_vault: ContractAddress,
    ) {
        self.owner.write(owner);
        self.market_class_hash.write(market_class_hash);
        self.verifier.write(verifier);
        self.nullifier_registry.write(nullifier_registry);
        self.shield_vault.write(shield_vault);
        self.next_market_id.write(0_u64);
    }

    #[external(v0)]
    fn create_market(
        ref self: ContractState, question_hash: felt252, oracle: ContractAddress, end_time: u64,
    ) -> (u64, ContractAddress) {
        self.assert_owner();

        let market_id = self.next_market_id.read();
        let verifier = self.verifier.read();
        let nullifier_registry = self.nullifier_registry.read();
        let shield_vault = self.shield_vault.read();

        let mut constructor_calldata = array![];
        Serde::<u64>::serialize(@market_id, ref constructor_calldata);
        Serde::<ContractAddress>::serialize(@oracle, ref constructor_calldata);
        Serde::<u64>::serialize(@end_time, ref constructor_calldata);
        Serde::<ContractAddress>::serialize(@verifier, ref constructor_calldata);
        Serde::<ContractAddress>::serialize(@nullifier_registry, ref constructor_calldata);
        Serde::<ContractAddress>::serialize(@shield_vault, ref constructor_calldata);

        let salt = MerkleTreeLib::hash_pair(question_hash, market_id.into());
        let (market_address, _) = deploy_syscall(
            self.market_class_hash.read(), salt, constructor_calldata.span(), false,
        )
            .unwrap_syscall();

        self.markets_by_id.write(market_id, market_address);
        self.question_hash_by_id.write(market_id, question_hash);
        self.oracle_by_id.write(market_id, oracle);
        self.end_time_by_id.write(market_id, end_time);
        self.next_market_id.write(market_id + 1_u64);

        self.emit(
            MarketCreated { market_id, market_address, question_hash, oracle, end_time },
        );
        (market_id, market_address)
    }

    #[external(v0)]
    fn set_market_class_hash(ref self: ContractState, market_class_hash: ClassHash) {
        self.assert_owner();
        self.market_class_hash.write(market_class_hash);
        self.emit(MarketClassHashUpdated { market_class_hash });
    }

    #[external(v0)]
    fn set_dependencies(
        ref self: ContractState,
        verifier: ContractAddress,
        nullifier_registry: ContractAddress,
        shield_vault: ContractAddress,
    ) {
        self.assert_owner();
        self.verifier.write(verifier);
        self.nullifier_registry.write(nullifier_registry);
        self.shield_vault.write(shield_vault);
        self.emit(DependenciesUpdated { verifier, nullifier_registry, shield_vault });
    }

    #[external(v0)]
    fn get_market(self: @ContractState, market_id: u64) -> ContractAddress {
        self.markets_by_id.read(market_id)
    }

    #[external(v0)]
    fn get_market_metadata(
        self: @ContractState, market_id: u64,
    ) -> (felt252, ContractAddress, u64) {
        (
            self.question_hash_by_id.read(market_id),
            self.oracle_by_id.read(market_id),
            self.end_time_by_id.read(market_id),
        )
    }

    #[external(v0)]
    fn next_market_id(self: @ContractState) -> u64 {
        self.next_market_id.read()
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_owner(self: @ContractState) {
            assert(get_caller_address() == self.owner.read(), 'NOT_OWNER');
        }
    }
}
