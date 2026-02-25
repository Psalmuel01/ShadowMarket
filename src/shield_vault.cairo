#[starknet::contract]
pub mod ShieldVault {
    use crate::interfaces::{
        IERC20Dispatcher, IERC20DispatcherTrait, IShieldVault, IVerifierDispatcher,
        IVerifierDispatcherTrait,
    };
    use crate::merkle_tree_lib::{TREE_CAPACITY, TREE_DEPTH};
    use crate::merkle_tree_lib as MerkleTreeLib;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    const WITHDRAW_PI_NULLIFIER_IDX: usize = 0;
    const WITHDRAW_PI_AMOUNT_LOW_IDX: usize = 1;
    const WITHDRAW_PI_AMOUNT_HIGH_IDX: usize = 2;
    const WITHDRAW_PI_RECIPIENT_IDX: usize = 3;
    const WITHDRAW_PI_OLD_ROOT_IDX: usize = 4;
    const WITHDRAW_PI_NEW_ROOT_IDX: usize = 5;
    const WITHDRAW_PI_LEN: usize = 6;

    #[storage]
    struct Storage {
        owner: ContractAddress,
        verifier: ContractAddress,
        collateral_token: ContractAddress,
        note_merkle_root: felt252,
        next_note_index: u32,
        filled_note_subtrees: Map<u32, felt252>,
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
        note_index: u32,
        new_note_root: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct Withdrawn {
        #[key]
        recipient: ContractAddress,
        amount: u256,
        #[key]
        nullifier: felt252,
        old_note_root: felt252,
        new_note_root: felt252,
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
        self.note_merkle_root.write(MerkleTreeLib::zero_hash(TREE_DEPTH));
        self.next_note_index.write(0_u32);
    }

    #[external(v0)]
    fn deposit(ref self: ContractState, amount: u256, encrypted_balance_commitment: felt252) {
        let sender = get_caller_address();
        assert(
            !self.shielded_balance_commitments.read(encrypted_balance_commitment), 'COMMITMENT_EXISTS',
        );

        let transferred = IERC20Dispatcher { contract_address: self.collateral_token.read() }
            .transfer_from(sender, get_contract_address(), amount);
        assert(transferred, 'TRANSFER_FAILED');

        let (new_note_root, note_index) = self.append_note_and_compute_root(encrypted_balance_commitment);
        self.shielded_balance_commitments.write(encrypted_balance_commitment, true);
        self.emit(Deposited {
            sender,
            amount,
            encrypted_balance_commitment,
            note_index,
            new_note_root,
        });
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
        assert(public_inputs.len() == WITHDRAW_PI_LEN, 'BAD_PI_LEN');
        assert(!self.withdraw_nullifiers.read(nullifier), 'NULLIFIER_USED');
        let old_note_root = self.note_merkle_root.read();

        assert(*public_inputs.at(WITHDRAW_PI_NULLIFIER_IDX) == nullifier, 'PI_NULLIFIER');
        assert(*public_inputs.at(WITHDRAW_PI_AMOUNT_LOW_IDX) == amount.low.into(), 'PI_PAY_LOW');
        assert(*public_inputs.at(WITHDRAW_PI_AMOUNT_HIGH_IDX) == amount.high.into(), 'PI_PAY_HIGH');
        assert(
            *public_inputs.at(WITHDRAW_PI_RECIPIENT_IDX) == recipient.into(), 'PI_RECIPIENT',
        );
        assert(*public_inputs.at(WITHDRAW_PI_OLD_ROOT_IDX) == old_note_root, 'PI_OLD_ROOT');

        let verified = IVerifierDispatcher { contract_address: self.verifier.read() }
            .verify_proof(program_hash, public_inputs, proof);
        assert(verified, 'INVALID_PROOF');

        // Keep note tree append-state coherent until withdraw circuits also provide
        // the metadata needed to update `next_note_index` + `filled_note_subtrees`.
        let new_note_root = *public_inputs.at(WITHDRAW_PI_NEW_ROOT_IDX);
        assert(new_note_root == old_note_root, 'PI_NEW_ROOT');

        let transferred = IERC20Dispatcher { contract_address: self.collateral_token.read() }
            .transfer(recipient, amount);
        assert(transferred, 'TRANSFER_FAILED');

        self.withdraw_nullifiers.write(nullifier, true);
        self.emit(Withdrawn { recipient, amount, nullifier, old_note_root, new_note_root });
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

    #[external(v0)]
    fn has_balance_commitment(self: @ContractState, encrypted_balance_commitment: felt252) -> bool {
        self.shielded_balance_commitments.read(encrypted_balance_commitment)
    }

    #[external(v0)]
    fn note_merkle_root(self: @ContractState) -> felt252 {
        self.note_merkle_root.read()
    }

    #[external(v0)]
    fn next_note_index(self: @ContractState) -> u32 {
        self.next_note_index.read()
    }

    #[external(v0)]
    fn is_withdraw_nullifier_used(self: @ContractState, nullifier: felt252) -> bool {
        self.withdraw_nullifiers.read(nullifier)
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_owner(self: @ContractState) {
            assert(get_caller_address() == self.owner.read(), 'NOT_OWNER');
        }

        fn append_note_and_compute_root(
            ref self: ContractState, note_commitment: felt252,
        ) -> (felt252, u32) {
            let note_index = self.next_note_index.read();
            assert(note_index < TREE_CAPACITY, 'TREE_FULL');

            let mut node = note_commitment;
            let mut idx = note_index;
            let mut level = 0_u32;
            loop {
                if level == TREE_DEPTH {
                    break;
                };

                if idx % 2_u32 == 0_u32 {
                    self.filled_note_subtrees.write(level, node);
                    node = MerkleTreeLib::hash_pair(node, MerkleTreeLib::zero_hash(level));
                } else {
                    let left = self.filled_note_subtrees.read(level);
                    node = MerkleTreeLib::hash_pair(left, node);
                };
                idx = idx / 2_u32;
                level += 1_u32;
            };

            self.next_note_index.write(note_index + 1_u32);
            self.note_merkle_root.write(node);
            (node, note_index)
        }
    }
}
