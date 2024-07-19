#[starknet::contract]
mod MyToken {
    use openzeppelin::token::erc20::ERC20Component;
    use starknet::{ContractAddress, get_caller_address};
    use erc20::utils;

    const OWNER_ADDRESS: felt252 =
        0x01c31ccFCD807F341E2Ae54856c42b1977f6d92f62C68336e7499Cc01E18524b;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage
    }

    #[external(v0)]
    fn mint(
        ref self: ContractState,
        amount: u256
    ) {
        let caller = get_caller_address();
        let owner_address: ContractAddress = OWNER_ADDRESS.try_into().unwrap();
        assert(caller == owner_address, 'UNAUTHORIZED');

        self.erc20._mint(caller, amount * utils::Utils::pow(10, 18));
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState
    ) {
        let name = 'MEMECOIN';
        let symbol = 'MECN';
        let owner_address: ContractAddress = OWNER_ADDRESS.try_into().unwrap();

        self.erc20.initializer(name, symbol);
        self.erc20._mint(owner_address, 100000 * utils::Utils::pow(10, 18));
    }
}