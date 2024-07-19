use starknet::ContractAddress;
#[starknet::interface]
trait IMarketplace<TContractState> {
    fn change_market_fee(ref self: TContractState, new_fee: u256);
    fn buy_nft(ref self: TContractState, token_id: u256);
    fn listing_nft(ref self: TContractState, token_id: u256);
    fn cancel_listing(ref self: TContractState, token_id: u256);
    fn get_nft_price(self: @TContractState, token_id: u256) -> u256;
    fn get_nft_owner(self: @TContractState, token_id: u256) -> ContractAddress;
    fn edit_nft_price(ref self: TContractState, token_id: u256, price: u256);
}

#[starknet::interface]
trait IERC721<TContractState> {
    fn owner_of(ref self: TContractState, token_id: u256) -> ContractAddress;
    fn get_approved(ref self: TContractState, token_id: u256) -> ContractAddress;
    fn transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
    );
}

#[starknet::interface]
trait IERC20<TContractState> {
    fn allowance(
        ref self: TContractState,
        owner: ContractAddress,
        spender: ContractAddress,
    ) -> u256;
    fn transferFrom(
        ref self: TContractState,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
    );
}

#[starknet::contract]
mod Marketplace {
    use starknet::{
        ContractAddress, get_caller_address, get_contract_address
    };
    use super::{
        IERC721Dispatcher, IERC721DispatcherTrait
    };
    use super::{
        IERC20Dispatcher, IERC20DispatcherTrait
    };

    const OWNER_ADDRESS: felt252 =
        0x01c31ccFCD807F341E2Ae54856c42b1977f6d92f62C68336e7499Cc01E18524b;
    const NFT_CONTRACT_ADDRESS: felt252 =
        0x00a01c352fd150d184835c727a84adfaf047838271e8641da6ea5156f7f73dce;
    const ETH_CONTRACT_ADDRESS: felt252 =
        0x002825f54382afee98d6cfe8f2daf9aae24089b4a724de92b0e4fda50a4551e9;

    mod Errors {
        const NOT_OWNER: felt252 = 'Error: not owner';
        const ALLOWANCE_NOT_ENOUGH: felt252 = 'Error: allowance not enough';
        const ALLOWANCE_NOT_SET: felt252 = 'Error: allowance not set';
        const NFT_ON_SALE: felt252 = 'Error: nft on sale';
        const NFT_NOT_ON_SALE: felt252 = 'Error: nft not on sale';
        const BUY_SELF_NFT: felt252 = 'Error: buy self nft';
    }
    
    #[storage]
    struct Storage {
        market_fee: u256,
        nfts_owner: LegacyMap<u256, ContractAddress>,
        nfts_price: LegacyMap<u256, u256>,
        nfts_status: LegacyMap<u256, u8>,
    }

    #[derive(Drop, starknet::Event)]
    struct NFT_LISTED {
        from: ContractAddress,
        token_id: u256,
        price: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct NFT_CANCELLED {
        token_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct NFT_BOUGHT {
        from: ContractAddress,
        token_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct NFT_PRICE_EDITED {
        token_id: u256,
        new_price: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct MARKET_FEE_CHANGE {
        new_fee: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        NFT_LISTED: NFT_LISTED,
        NFT_CANCELLED: NFT_CANCELLED,
        NFT_BOUGHT: NFT_BOUGHT,
        NFT_PRICE_EDITED: NFT_PRICE_EDITED,
        MARKET_FEE_CHANGE: MARKET_FEE_CHANGE,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {

    }

    #[external(v0)]
    fn change_market_fee(ref self: ContractState, new_fee: u256) {
        assert(get_caller_address() == OWNER_ADDRESS.try_into().unwrap(), Errors::NOT_OWNER);
        self.market_fee.write(new_fee);
        self.emit(MARKET_FEE_CHANGE { new_fee: new_fee });
    }

    #[external(v0)]
    fn buy_nft(ref self: ContractState, token_id: u256) {
        assert(self.nfts_status.read(token_id) == 1, Errors::NFT_NOT_ON_SALE);
        assert(
            self.nfts_owner.read(token_id) != get_caller_address(),
            Errors::BUY_SELF_NFT
        );
        assert(
            IERC20Dispatcher { contract_address: ETH_CONTRACT_ADDRESS.try_into().unwrap() }
            .allowance(get_caller_address(), get_contract_address()) >= self.nfts_price.read(token_id),
            Errors::ALLOWANCE_NOT_ENOUGH
        );

        IERC20Dispatcher { contract_address: ETH_CONTRACT_ADDRESS.try_into().unwrap() }
        .transferFrom(get_caller_address(), self.nfts_owner.read(token_id), self.nfts_price.read(token_id));

        IERC721Dispatcher { contract_address: NFT_CONTRACT_ADDRESS.try_into().unwrap() }
        .transfer_from(get_contract_address(), get_caller_address(), token_id);

        self.nfts_status.write(token_id, 0);
        self.emit(NFT_BOUGHT { from: get_caller_address(), token_id: token_id });
    }

    #[external(v0)]
    fn listing_nft(ref self: ContractState, token_id: u256, price: u256) {
        assert(self.nfts_status.read(token_id) == 0, Errors::NFT_ON_SALE);
        assert(
            IERC721Dispatcher { contract_address: NFT_CONTRACT_ADDRESS.try_into().unwrap() }
            .owner_of(token_id) == get_caller_address(),
            Errors::NOT_OWNER
        );
        assert(
            IERC721Dispatcher { contract_address: NFT_CONTRACT_ADDRESS.try_into().unwrap() }
            .get_approved(token_id) == get_contract_address(),
            Errors::ALLOWANCE_NOT_SET
        );

        IERC721Dispatcher { contract_address: NFT_CONTRACT_ADDRESS.try_into().unwrap() }
        .transfer_from(get_caller_address(), get_contract_address(), token_id);
        
        self.nfts_owner.write(token_id, get_caller_address());
        self.nfts_price.write(token_id, price);
        self.nfts_status.write(token_id, 1);

        self.emit(NFT_LISTED { from: get_caller_address(), token_id: token_id, price: price });
    }

    #[external(v0)]
    fn cancel_listing(ref self: ContractState, token_id: u256) {
        assert(self.nfts_status.read(token_id) == 1, Errors::NFT_NOT_ON_SALE);
        assert(
            self.nfts_owner.read(token_id) == get_caller_address(),
            Errors::NOT_OWNER
        );

        IERC721Dispatcher { contract_address: NFT_CONTRACT_ADDRESS.try_into().unwrap() }
        .transfer_from(get_contract_address(), get_caller_address(), token_id);

        self.nfts_status.write(token_id, 0);

        self.emit(NFT_CANCELLED { token_id: token_id });
    }

    #[external(v0)]
    fn get_nft_price(self: @ContractState, token_id: u256) -> u256 {
        self.nfts_price.read(token_id)
    }

    #[external(v0)]
    fn get_nft_owner(self: @ContractState, token_id: u256) -> ContractAddress {
        self.nfts_owner.read(token_id)
    }

    #[external(v0)]
    fn edit_nft_price(ref self: ContractState, token_id: u256, price: u256) {
        assert(self.nfts_status.read(token_id) == 1, Errors::NFT_NOT_ON_SALE);
        assert(
            self.nfts_owner.read(token_id) == get_caller_address(),
            Errors::NOT_OWNER
        );

        self.nfts_price.write(token_id, price);
        self.emit(NFT_PRICE_EDITED { token_id: token_id, new_price: price });
    }
}
