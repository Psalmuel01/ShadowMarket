#[starknet::contract]
pub mod NullifierRegistry {
    use crate::interfaces::INullifierRegistry;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        nullifier_used: Map<felt252, bool>,
        authorized_callers: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        NullifierMarked: NullifierMarked,
        AuthorizedCallerSet: AuthorizedCallerSet,
    }

    #[derive(Drop, starknet::Event)]
    struct NullifierMarked {
        #[key]
        nullifier: felt252,
        caller: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct AuthorizedCallerSet {
        #[key]
        caller: ContractAddress,
        is_authorized: bool,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.authorized_callers.write(owner, true);
    }

    #[abi(embed_v0)]
    impl NullifierRegistryImpl of INullifierRegistry<ContractState> {
        fn is_used(self: @ContractState, nullifier: felt252) -> bool {
            self.nullifier_used.read(nullifier)
        }

        fn mark_used(ref self: ContractState, nullifier: felt252) {
            self.assert_authorized();
            assert(!self.nullifier_used.read(nullifier), 'NULLIFIER_USED');
            self.nullifier_used.write(nullifier, true);
            self.emit(NullifierMarked { nullifier, caller: get_caller_address() });
        }
    }

    #[external(v0)]
    fn set_authorized_caller(
        ref self: ContractState, caller: ContractAddress, is_authorized: bool,
    ) {
        self.assert_owner();
        self.authorized_callers.write(caller, is_authorized);
        self.emit(AuthorizedCallerSet { caller, is_authorized });
    }

    #[external(v0)]
    fn owner(self: @ContractState) -> ContractAddress {
        self.owner.read()
    }

    #[external(v0)]
    fn is_authorized(self: @ContractState, caller: ContractAddress) -> bool {
        self.authorized_callers.read(caller)
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_owner(self: @ContractState) {
            assert(get_caller_address() == self.owner.read(), 'NOT_OWNER');
        }

        fn assert_authorized(self: @ContractState) {
            assert(self.authorized_callers.read(get_caller_address()), 'NOT_AUTHORIZED');
        }
    }
}
