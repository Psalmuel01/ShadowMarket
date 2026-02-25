#[starknet::contract]
pub mod MockERC20 {
    use crate::interfaces::IERC20;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        balances: Map<ContractAddress, u256>,
        allowances: Map<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        Minted: Minted,
    }

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Approval {
        #[key]
        owner: ContractAddress,
        #[key]
        spender: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Minted {
        #[key]
        to: ContractAddress,
        amount: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
    }

    #[external(v0)]
    fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
        self.assert_owner();
        let to_balance = self.read_balance_low(to);
        let amount_low = self.assert_low_u256(amount);
        self.balances.write(to, u256 { low: to_balance + amount_low, high: 0 });
        self.emit(Minted { to, amount });
    }

    #[external(v0)]
    fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
        self.allowances.write((get_caller_address(), spender), self.assert_low_only_u256(amount));
        self.emit(Approval { owner: get_caller_address(), spender, amount });
        true
    }

    #[external(v0)]
    fn balance_of(self: @ContractState, owner: ContractAddress) -> u256 {
        self.balances.read(owner)
    }

    #[external(v0)]
    fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
        self.allowances.read((owner, spender))
    }

    #[abi(embed_v0)]
    impl ERC20Impl of IERC20<ContractState> {
        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            self.move_funds(get_caller_address(), recipient, amount);
            true
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) -> bool {
            let spender = get_caller_address();
            let allowance = self.allowances.read((sender, spender));
            let allowance_low = self.assert_low_u256(allowance);
            let amount_low = self.assert_low_u256(amount);
            assert(allowance_low >= amount_low, 'INSUFFICIENT_ALLOWANCE');

            self.allowances
                .write((sender, spender), u256 { low: allowance_low - amount_low, high: 0 });
            self.move_funds(sender, recipient, amount);
            true
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_owner(self: @ContractState) {
            assert(get_caller_address() == self.owner.read(), 'NOT_OWNER');
        }

        fn assert_low_u256(self: @ContractState, value: u256) -> u128 {
            assert(value.high == 0, 'HIGH_NOT_SUPPORTED');
            value.low
        }

        fn assert_low_only_u256(self: @ContractState, value: u256) -> u256 {
            assert(value.high == 0, 'HIGH_NOT_SUPPORTED');
            u256 { low: value.low, high: 0 }
        }

        fn read_balance_low(self: @ContractState, account: ContractAddress) -> u128 {
            let balance = self.balances.read(account);
            self.assert_low_u256(balance)
        }

        fn move_funds(
            ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
        ) {
            let amount_low = self.assert_low_u256(amount);

            let sender_balance = self.read_balance_low(sender);
            assert(sender_balance >= amount_low, 'INSUFFICIENT_BALANCE');
            self.balances.write(sender, u256 { low: sender_balance - amount_low, high: 0 });

            let recipient_balance = self.read_balance_low(recipient);
            self.balances.write(recipient, u256 { low: recipient_balance + amount_low, high: 0 });

            self.emit(Transfer { from: sender, to: recipient, amount });
        }
    }
}
