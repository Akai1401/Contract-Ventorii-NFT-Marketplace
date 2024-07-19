import {
  RpcProvider,
  Account,
  Contract,
  CallData,
  cairo
} from "starknet";
import "dotenv/config.js";
const provider = new RpcProvider({
  nodeUrl: "",
});
const account = new Account(
  provider,
  process.env.ACCOUNT_ADDRESS,
  process.env.PRIVATE_KEY
);
const publicKey = await account.signer.getPubKey();
console.log("Account connected successfully with public key: ", publicKey);

const mint = async () => {
  const multiCall = await account.execute(
    [
      {
        contractAddress: process.env.ETH_CONTRACT_ADDRESS,
        entrypoint: "approve",
        calldata: CallData.compile({
          spender: process.env.NFT_CONTRACT_ADDRESS,
          amount: cairo.uint256(10 * 10 ** 18)
        })
      },
      {
        contractAddress: process.env.NFT_CONTRACT_ADDRESS,
        entrypoint: "mint_nft",
        calldata: CallData.compile({
          pool_mint: 1,
        })
      }
    ]
  );
  console.log("Tx Hash:", multiCall.transaction_hash);
}

const listing = async (token_id, price) => {
  const multiCall = await account.execute(
    [
      {
        contractAddress: process.env.NFT_CONTRACT_ADDRESS,
        entrypoint: "approve",
        calldata: CallData.compile({
          to: process.env.MARKET_CONTRACT_ADDRESS,
          token_id: cairo.uint256(token_id)
        })
      },
      {
        contractAddress: process.env.MARKET_CONTRACT_ADDRESS,
        entrypoint: "listing_nft",
        calldata: CallData.compile({
          token_id: cairo.uint256(token_id),
          price: cairo.uint256(price)
        })
      }
    ]
  );
  console.log("Tx Hash:", multiCall.transaction_hash);
}

const cancel = async (token_id) => {
  const multiCall = await account.execute(
    [
      {
        contractAddress: process.env.MARKET_CONTRACT_ADDRESS,
        entrypoint: "cancel_listing",
        calldata: CallData.compile({
          token_id: cairo.uint256(token_id)
        })
      }
    ]
  );
  console.log("Tx Hash:", multiCall.transaction_hash);
}

const buy = async (token_id, price) => {
  const multiCall = await account.execute(
    [
      {
        contractAddress: process.env.ETH_CONTRACT_ADDRESS,
        entrypoint: "approve",
        calldata: CallData.compile({
          spender: process.env.MARKET_CONTRACT_ADDRESS,
          amount: cairo.uint256(price)  
        })
      },
      {
        contractAddress: process.env.MARKET_CONTRACT_ADDRESS,
        entrypoint: "buy_nft",
        calldata: CallData.compile({
          token_id: cairo.uint256(token_id)
        })
      }
    ]
  );
  console.log("Tx Hash:", multiCall.transaction_hash);
}

const main = async () => {
  // mint();
  // listing(2, 25);
  // cancel(1);
  buy(2, 25);
};

main();
