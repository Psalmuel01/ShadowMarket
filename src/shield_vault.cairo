#[starknet::contract]
pub mod ShieldVault {
    use crate::interfaces::{
        IERC20Dispatcher, IERC20DispatcherTrait, IShieldVault, IVerifierDispatcher,
        IVerifierDispatcherTrait,
    };
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        verifier: ContractAddress,
        collateral_token: ContractAddress,
        shielded_balance_commitments: Map<felt252, bool>,
        withdraw_nullifiers: Map<felt252, bool>,
        authorized_markets: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Deposited: Deposited,
        Withdrawn: Withdrawn,
        AuthorizedMarketSet: AuthorizedMarketSet,
    }

    #[derive(Drop, starknet::Event)]
    struct Deposited {
        #[key]
        sender: ContractAddress,
        amount: u256,
        encrypted_balance_commitment: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct Withdrawn {
        #[key]
        recipient: ContractAddress,
        amount: u256,
        #[key]
        nullifier: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct AuthorizedMarketSet {
        #[key]
        market: ContractAddress,
        is_authorized: bool,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        verifier: ContractAddress,
        collateral_token: ContractAddress,
    ) {
        self.owner.write(owner);
        self.verifier.write(verifier);
        self.collateral_token.write(collateral_token);
    }

    #[external(v0)]
    fn deposit(ref self: ContractState, amount: u256, encrypted_balance_commitment: felt252) {
        let sender = get_caller_address();
        let transferred = IERC20Dispatcher { contract_address: self.collateral_token.read() }
            .transfer_from(sender, get_contract_address(), amount);
        assert(transferred, 'TRANSFER_FAILED');

        self.shielded_balance_commitments.write(encrypted_balance_commitment, true);
        self.emit(Deposited { sender, amount, encrypted_balance_commitment });
    }

    #[external(v0)]
    fn withdraw(
        ref self: ContractState,
        amount: u256,
        recipient: ContractAddress,
        nullifier: felt252,
        program_hash: felt252,
        public_inputs: Span<felt252>,
        proof: Span<felt252>,
    ) {
        assert(!self.withdraw_nullifiers.read(nullifier), 'NULLIFIER_USED');

        let verified = IVerifierDispatcher { contract_address: self.verifier.read() }
            .verify_proof(program_hash, public_inputs, proof);
        assert(verified, 'INVALID_PROOF');

        let transferred = IERC20Dispatcher { contract_address: self.collateral_token.read() }
            .transfer(recipient, amount);
        assert(transferred, 'TRANSFER_FAILED');

        self.withdraw_nullifiers.write(nullifier, true);
        self.emit(Withdrawn { recipient, amount, nullifier });
    }

    #[external(v0)]
    fn set_authorized_market(
        ref self: ContractState, market: ContractAddress, is_authorized: bool,
    ) {
        self.assert_owner();
        self.authorized_markets.write(market, is_authorized);
        self.emit(AuthorizedMarketSet { market, is_authorized });
    }

    #[abi(embed_v0)]
    impl ShieldVaultImpl of IShieldVault<ContractState> {
        fn release_payout(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            assert(self.authorized_markets.read(get_caller_address()), 'NOT_AUTHORIZED_MARKET');

            let transferred = IERC20Dispatcher { contract_address: self.collateral_token.read() }
                .transfer(recipient, amount);
            assert(transferred, 'TRANSFER_FAILED');
        }

        fn is_authorized_market(self: @ContractState, market: ContractAddress) -> bool {
            self.authorized_markets.read(market)
        }
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
