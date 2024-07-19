#[starknet::contract]
mod CollectionINO {
    use alexandria_ascii::ToAsciiTrait;
    use collection_ino::erc721::erc721::ERC721Component;
    use collection_ino::erc721::erc721::ERC721Component::InternalTrait;
    use core::Zeroable;
    // use ecdsa::check_ecdsa_signature;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
    use starknet::{
        get_caller_address, get_contract_address, get_block_timestamp, replace_class_syscall
    };
    use starknet::{ContractAddress, ClassHash, SyscallResult, SyscallResultTrait};

    const ETH_CONTRACT_ADDRESS: felt252 =
        0x002825f54382afee98d6cfe8f2daf9aae24089b4a724de92b0e4fda50a4551e9;
    const OWNER_ADDRESS: felt252 =
        0x01c31ccFCD807F341E2Ae54856c42b1977f6d92f62C68336e7499Cc01E18524b;
    const CO_OWNER_ADDRESS: felt252 =
        0x01c31ccFCD807F341E2Ae54856c42b1977f6d92f62C68336e7499Cc01E18524b;

    // const PUBLIC_KEY_SIGN: felt252 =
    //     0x3832eeefe028b33ccb29c2b6173b2db8e851794f0a78127157c93c0f88eba89;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC721
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721CamelOnly = ERC721Component::ERC721CamelOnlyImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        token_id: u256,
        total_supply: u256,
        token_uri_1: felt252,
        token_uri_2: felt252,
        token_uri_3: felt252,
        token_uri_4: felt252,
        token_uri_5: felt252,
        supply_pool: LegacyMap<u8, u256>,
        sum_pool: LegacyMap<u8, u256>,
        time_pool: LegacyMap<u8, u64>,
        price_pool: LegacyMap<u8, u256>,
        mint_max: LegacyMap<u8, u64>,
        user_minted: LegacyMap<(ContractAddress, u8), u64>,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[derive(Drop, starknet::Event)]
    struct NFTMinted {
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        pool: u8
    }

    #[derive(Drop, starknet::Event)]
    struct NFTBurned {
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256
    }

    #[derive(Drop, starknet::Event)]
    struct Upgraded {
        class_hash: ClassHash
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        NFTMinted: NFTMinted,
        NFTBurned: NFTBurned,
        Upgraded: Upgraded,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    mod Errors {
        const NOT_OWNER: felt252 = 'Error: not owner';
        const SIGNATURE_NOT_MATCH: felt252 = 'Error: signature not match';
        const MESSAGE_HASH_NOT_MATCH: felt252 = 'Error: msg hash not match';
        const TIME_NOT_START_YET: felt252 = 'Error: time not start yet';
        const SUPPLY_POOL_LIMIT: felt252 = 'Error: supply pool limit';
        const TOTAL_SUPPLY_LIMIT: felt252 = 'Error: total supply limit';
        const MINTED_MAX_AMOUNT_POOL: felt252 = 'Error: minted max amt pool';
        const INVALID_TOKEN_ID: felt252 = 'Error: invalid token id';
        const INVALID_CLASS_HASH: felt252 = 'Error: invalid class hash';
        const ALLOWANCE_NOT_ENOUGH: felt252 = 'Error: allowance not enough';
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        let name: felt252 = 'MEMELAND2';
        let symbol: felt252 = 'MELD2';

        self.erc721.initializer(name, symbol);

        // Token URI
        self.token_uri_1.write('https://');
        self.token_uri_2.write('grow-api.');
        self.token_uri_3.write('memeland.com/');
        self.token_uri_4.write('token/');
        self.token_uri_5.write('metadata/');

        // Total supply
        self.total_supply.write(3000);

        // Supply
        self.supply_pool.write(1, 750); // Public  
        self.supply_pool.write(2, 750); // Private
        self.supply_pool.write(3, 750); // Whitelist
        self.supply_pool.write(4, 750); // Holder

        // Price 
        self.price_pool.write(1, 0);
        self.price_pool.write(2, 0);
        self.price_pool.write(3, 0);
        self.price_pool.write(4, 0);

        // Time
        self.time_pool.write(1, 1715698800);
        self.time_pool.write(2, 0);
        self.time_pool.write(3, 1715695200);
        self.time_pool.write(4, 0);

        // Max mint
        self.mint_max.write(1, 100);
        self.mint_max.write(2, 0);
        self.mint_max.write(3, 100);
        self.mint_max.write(4, 0);
    }

    //
    // Read Method
    // 

    #[external(v0)]
    fn get_sum_pool(self: @ContractState) -> Array<u256> {
        let mut arr: Array<u256> = ArrayTrait::new();
        arr.append(self.token_id.read());
        arr.append(self.sum_pool.read(1));
        arr.append(self.sum_pool.read(2));
        arr.append(self.sum_pool.read(3));
        arr.append(self.sum_pool.read(4));
        arr
    }

    #[external(v0)]
    fn token_uri(self: @ContractState, token_id: u256) -> Span<felt252> {
        assert(self.erc721.owner_of(token_id).is_non_zero(), Errors::INVALID_TOKEN_ID);
        let token_id_str: felt252 = token_id.low.to_ascii();
        let mut token_uri: Array<felt252> = array![
            self.token_uri_1.read(),
            self.token_uri_2.read(),
            self.token_uri_3.read(),
            self.token_uri_4.read(),
            self.token_uri_5.read(),
            token_id_str,
            '.json'
        ];
        token_uri.span()
    }

    #[external(v0)]
    fn tokenURI(self: @ContractState, tokenId: u256) -> Span<felt252> {
        token_uri(self, tokenId)
    }

    //
    // Write Method
    //

    #[external(v0)]
    fn up_time(ref self: ContractState, pool: u8, time: u64) {
        // Check owner
        let caller = get_caller_address();
        let owner_address: ContractAddress = OWNER_ADDRESS.try_into().unwrap();
        let co_owner_address: ContractAddress = CO_OWNER_ADDRESS.try_into().unwrap();
        assert(caller == owner_address || caller == co_owner_address, Errors::NOT_OWNER);

        // Save to storage
        self.time_pool.write(pool, time);
    }

    #[external(v0)]
    fn up_supply(ref self: ContractState, pool: u8, supply: u256) {
        // Check owner
        let caller = get_caller_address();
        let owner_address: ContractAddress = OWNER_ADDRESS.try_into().unwrap();
        let co_owner_address: ContractAddress = CO_OWNER_ADDRESS.try_into().unwrap();
        assert(caller == owner_address || caller == co_owner_address, Errors::NOT_OWNER);

        // Save to storage
        self.supply_pool.write(pool, supply);
    }

    #[external(v0)]
    fn up_mint_max(ref self: ContractState, pool: u8, supply: u64) {
        // Check owner
        let caller = get_caller_address();
        let owner_address: ContractAddress = OWNER_ADDRESS.try_into().unwrap();
        let co_owner_address: ContractAddress = CO_OWNER_ADDRESS.try_into().unwrap();
        assert(caller == owner_address || caller == co_owner_address, Errors::NOT_OWNER);

        // Save to storage
        self.mint_max.write(pool, supply);
    }

    #[external(v0)]
    fn up_price(ref self: ContractState, pool: u8, price: u256) {
        // Check owner
        let caller = get_caller_address();
        let owner_address: ContractAddress = OWNER_ADDRESS.try_into().unwrap();
        let co_owner_address: ContractAddress = CO_OWNER_ADDRESS.try_into().unwrap();
        assert(caller == owner_address || caller == co_owner_address, Errors::NOT_OWNER);

        // Save to storage
        self.price_pool.write(pool, price);
    }

    #[external(v0)]
    fn mint_nft(ref self: ContractState, pool_mint: u8) {
        let caller = get_caller_address();
        let this_contract_address = get_contract_address();

        // Verify time
        assert(get_block_timestamp() >= self.time_pool.read(pool_mint), Errors::TIME_NOT_START_YET);

        // Verify supply pool
        assert(
            self.supply_pool.read(pool_mint) > self.sum_pool.read(pool_mint),
            Errors::SUPPLY_POOL_LIMIT
        );

        // Verify token id
        let mut token_id = self.token_id.read();
        assert(token_id < self.total_supply.read(), Errors::TOTAL_SUPPLY_LIMIT);

        // Verify the number of nft user has minted
        let acc_user_mint: (ContractAddress, u8) = (caller, pool_mint);
        assert(
            self.user_minted.read(acc_user_mint) < self.mint_max.read(pool_mint),
            Errors::MINTED_MAX_AMOUNT_POOL
        );

        // Save to stoage
        self.user_minted.write(acc_user_mint, self.user_minted.read(acc_user_mint) + 1);
        token_id += 1;
        self.token_id.write(token_id);
        self.sum_pool.write(pool_mint, self.sum_pool.read(pool_mint) + 1);

        // Transfer token
        let token_contract_address: ContractAddress = ETH_CONTRACT_ADDRESS.try_into().unwrap();
        let allowance = IERC20CamelDispatcher { contract_address: token_contract_address }
            .allowance(caller, this_contract_address);
        assert(allowance >= self.price_pool.read(pool_mint), Errors::ALLOWANCE_NOT_ENOUGH);
        IERC20CamelDispatcher { contract_address: token_contract_address }
            .transferFrom(caller, this_contract_address, self.price_pool.read(pool_mint));

        // Mint NFT & set the token's URI
        self.erc721._mint(caller, token_id);

        // Emit event
        self.emit(NFTMinted { from: Zeroable::zero(), to: caller, token_id, pool: pool_mint });
    }
    // fn mint_nft(
    //     ref self: ContractState,
    //     pool_mint: u8,
    //     message_hash: felt252,
    //     signature_r: felt252,
    //     signature_s: felt252
    // ) {
    //     let caller = get_caller_address();
    //     let this_contract_address = get_contract_address();

    //     // Verify signature
    //     assert(
    //         check_ecdsa_signature(message_hash, PUBLIC_KEY_SIGN, signature_r, signature_s),
    //         Errors::SIGNATURE_NOT_MATCH
    //     );

    //     // Verify message hash
    //     assert(
    //         message_hash == check_msg(caller, this_contract_address, pool_mint),
    //         Errors::MESSAGE_HASH_NOT_MATCH
    //     );

    //     // Verify time
    //     assert(get_block_timestamp() >= self.time_pool.read(pool_mint), Errors::TIME_NOT_START_YET);

    //     // Verify supply pool
    //     assert(
    //         self.supply_pool.read(pool_mint) > self.sum_pool.read(pool_mint),
    //         Errors::SUPPLY_POOL_LIMIT
    //     );

    //     // Verify token id
    //     let mut token_id = self.token_id.read();
    //     assert(token_id < self.total_supply.read(), Errors::TOTAL_SUPPLY_LIMIT);

    //     // Verify the number of nft user has minted
    //     let acc_user_mint: (ContractAddress, u8) = (caller, pool_mint);
    //     assert(
    //         self.user_minted.read(acc_user_mint) < self.mint_max.read(pool_mint),
    //         Errors::MINTED_MAX_AMOUNT_POOL
    //     );

    //     // Save to stoage
    //     self.user_minted.write(acc_user_mint, self.user_minted.read(acc_user_mint) + 1);
    //     token_id += 1;
    //     self.token_id.write(token_id);
    //     self.sum_pool.write(pool_mint, self.sum_pool.read(pool_mint) + 1);

    //     // Transfer token
    //     let token_contract_address: ContractAddress = ETH_CONTRACT_ADDRESS.try_into().unwrap();
    //     IERC20CamelDispatcher { contract_address: token_contract_address }
    //         .transferFrom(caller, this_contract_address, self.price_pool.read(pool_mint));

    //     // Mint NFT & set the token's URI
    //     self.erc721._mint(caller, token_id);

    //     // Emit event
    //     self.emit(NFTMinted { from: Zeroable::zero(), to: caller, token_id, pool: pool_mint });
    // }

    #[external(v0)]
    fn mint_public(ref self: ContractState, total: u256, pool_mint: u8, to: ContractAddress) {
        // Check owner
        let caller = get_caller_address();
        let owner_address: ContractAddress = OWNER_ADDRESS.try_into().unwrap();
        let co_owner_address: ContractAddress = CO_OWNER_ADDRESS.try_into().unwrap();
        assert(caller == owner_address || caller == co_owner_address, Errors::NOT_OWNER);

        // Verify supply pool
        assert(
            self.supply_pool.read(pool_mint) > self.sum_pool.read(pool_mint),
            Errors::SUPPLY_POOL_LIMIT
        );

        // Verify token id
        assert(self.token_id.read() < self.total_supply.read(), Errors::TOTAL_SUPPLY_LIMIT);

        let mut i: u256 = 0;
        loop {
            if (i == total) {
                break;
            }
            let token_id = self.token_id.read() + 1;
            self.token_id.write(token_id);
            self.sum_pool.write(pool_mint, self.sum_pool.read(pool_mint) + 1);

            // Mint NFT
            self.erc721._mint(to, token_id);

            // Emit event
            self.emit(NFTMinted { from: Zeroable::zero(), to, token_id, pool: pool_mint });

            // Increase index
            i = i + 1;
        };
    }

    #[external(v0)]
    fn burn(ref self: ContractState, token_id: u256) {
        // Check owner
        let caller = get_caller_address();
        let owner_address: ContractAddress = OWNER_ADDRESS.try_into().unwrap();
        let co_owner_address: ContractAddress = CO_OWNER_ADDRESS.try_into().unwrap();
        assert(caller == owner_address || caller == co_owner_address, Errors::NOT_OWNER);

        // Burn NFT
        self.erc721._burn(token_id);

        // Emit event
        self.emit(NFTBurned { from: caller, to: Zeroable::zero(), token_id });
    }

    #[external(v0)]
    fn claim(ref self: ContractState) {
        // Check owner
        let caller = get_caller_address();
        let owner_address: ContractAddress = OWNER_ADDRESS.try_into().unwrap();
        let co_owner_address: ContractAddress = CO_OWNER_ADDRESS.try_into().unwrap();
        assert(caller == owner_address || caller == co_owner_address, Errors::NOT_OWNER);

        // Transfer token
        let token_contract_address: ContractAddress = ETH_CONTRACT_ADDRESS.try_into().unwrap();
        IERC20CamelDispatcher { contract_address: token_contract_address }
            .transfer(
                owner_address,
                IERC20CamelDispatcher { contract_address: token_contract_address }
                    .balanceOf(get_contract_address())
            );
    }

    #[external(v0)]
    fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
        // Check owner
        let caller = get_caller_address();
        let owner_address: ContractAddress = OWNER_ADDRESS.try_into().unwrap();
        let co_owner_address: ContractAddress = CO_OWNER_ADDRESS.try_into().unwrap();
        assert(caller == owner_address || caller == co_owner_address, Errors::NOT_OWNER);

        // Check class hash
        assert(new_class_hash.is_non_zero(), Errors::INVALID_CLASS_HASH);

        // Upgrade
        replace_class_syscall(new_class_hash).unwrap_syscall();

        // Emit event
        self.emit(Upgraded { class_hash: new_class_hash });
    }

    //
    // Internal Method
    // 

    fn check_msg(account: ContractAddress, collection: ContractAddress, pool: u8) -> felt252 {
        let mut message: Array<felt252> = ArrayTrait::new();
        message.append(account.into());
        message.append(collection.into());
        message.append(pool.into());
        poseidon::poseidon_hash_span(message.span())
    }
}