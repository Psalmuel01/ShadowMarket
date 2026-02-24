#[starknet::contract]
pub mod Verifier {
    use crate::interfaces::{
        IGaragaVerifierDispatcher, IGaragaVerifierDispatcherTrait, IVerifier,
    };
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        garaga_verifier: ContractAddress,
        accepted_program_hashes: Map<felt252, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ProgramHashSet: ProgramHashSet,
        GaragaVerifierSet: GaragaVerifierSet,
    }

    #[derive(Drop, starknet::Event)]
    struct ProgramHashSet {
        #[key]
        program_hash: felt252,
        enabled: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct GaragaVerifierSet {
        verifier: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, garaga_verifier: ContractAddress,
    ) {
        self.owner.write(owner);
        self.garaga_verifier.write(garaga_verifier);
    }

    #[abi(embed_v0)]
    impl VerifierImpl of IVerifier<ContractState> {
        fn verify_proof(
            self: @ContractState,
            program_hash: felt252,
            public_inputs: Span<felt252>,
            proof: Span<felt252>,
        ) -> bool {
            if !self.accepted_program_hashes.read(program_hash) {
                return false;
            };

            IGaragaVerifierDispatcher { contract_address: self.garaga_verifier.read() }
                .verify_proof(program_hash, public_inputs, proof)
        }
    }

    #[external(v0)]
    fn set_program_hash(ref self: ContractState, program_hash: felt252, enabled: bool) {
        self.assert_owner();
        self.accepted_program_hashes.write(program_hash, enabled);
        self.emit(ProgramHashSet { program_hash, enabled });
    }

    #[external(v0)]
    fn set_garaga_verifier(ref self: ContractState, garaga_verifier: ContractAddress) {
        self.assert_owner();
        self.garaga_verifier.write(garaga_verifier);
        self.emit(GaragaVerifierSet { verifier: garaga_verifier });
    }

    #[external(v0)]
    fn owner(self: @ContractState) -> ContractAddress {
        self.owner.read()
    }

    #[external(v0)]
    fn garaga_verifier(self: @ContractState) -> ContractAddress {
        self.garaga_verifier.read()
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_owner(self: @ContractState) {
            assert(get_caller_address() == self.owner.read(), 'NOT_OWNER');
        }
    }
}
