#[starknet::contract]
pub mod MockGaragaVerifier {
    use crate::interfaces::IGaragaVerifier;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        default_result: bool,
        has_override: Map<felt252, bool>,
        override_result: Map<felt252, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        DefaultResultSet: DefaultResultSet,
        ProgramResultSet: ProgramResultSet,
    }

    #[derive(Drop, starknet::Event)]
    struct DefaultResultSet {
        value: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct ProgramResultSet {
        #[key]
        program_hash: felt252,
        value: bool,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, default_result: bool) {
        self.owner.write(owner);
        self.default_result.write(default_result);
    }

    #[abi(embed_v0)]
    impl MockGaragaVerifierImpl of IGaragaVerifier<ContractState> {
        fn verify_proof(
            self: @ContractState,
            program_hash: felt252,
            public_inputs: Span<felt252>,
            proof: Span<felt252>,
        ) -> bool {
            let _ = public_inputs;
            let _ = proof;
            if self.has_override.read(program_hash) {
                return self.override_result.read(program_hash);
            };
            self.default_result.read()
        }
    }

    #[external(v0)]
    fn set_default_result(ref self: ContractState, value: bool) {
        self.assert_owner();
        self.default_result.write(value);
        self.emit(DefaultResultSet { value });
    }

    #[external(v0)]
    fn set_program_result(ref self: ContractState, program_hash: felt252, value: bool) {
        self.assert_owner();
        self.has_override.write(program_hash, true);
        self.override_result.write(program_hash, value);
        self.emit(ProgramResultSet { program_hash, value });
    }

    #[external(v0)]
    fn owner(self: @ContractState) -> ContractAddress {
        self.owner.read()
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_owner(self: @ContractState) {
            assert(get_caller_address() == self.owner.read(), 'NOT_OWNER');
        }
    }
}
