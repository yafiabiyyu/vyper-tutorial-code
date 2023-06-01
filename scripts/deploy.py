from brownie import accounts, config, network, NFT, web3


def get_account():
    if network.show_active() == "development":
        return accounts
    else:
        return accounts.from_mnemonic(config["wallets"]["from_mnemonic"], count=5)


def main():
    account = get_account()
    token_name = "Color Random NFT"
    token_symbol = "CRNFT"
    token_uri = [
        "https://bafybeieklchqfnhj4uv66zngjcvoo7txbr2l5dieofvzlr3uux42zgdzsy.ipfs.w3s.link/Frame%201.png",
        "https://bafybeiavvlb4snecligbxtzqyfwh2adhx5nyzbirbtmgcmj2vhuluyuime.ipfs.w3s.link/Frame%202.png",
        "https://bafybeihigwbdx75szt45ntqovsx77rsbfcguaqy7qtd7znl2ib7ytuw2um.ipfs.w3s.link/Frame%203.png",
        "https://bafybeicxnnftx2wme5uixwqokn7r6qbvwimlzkdk2mvf7bqne2o6m6cnje.ipfs.w3s.link/Frame%204.png",
    ]
    token_rarity = [5, 20, 50, 100]
    minting_fee = web3.toWei(0.1, "ether")
    celo_randomness = "0xdd318EEF001BB0867Cd5c134496D6cF5Aa32311F"

    contract = NFT.deploy(
        token_name,
        token_symbol,
        token_uri,
        token_rarity,
        minting_fee,
        celo_randomness,
        {
            "from": account[0]
        }
    )

    contract.tx.wait(2)

    # Mint tokens
    txMinting = contract.mint({"from": account[0], "value": minting_fee})
    txMinting.wait(2)

    # Transfer tokens
    txTransfer = contract.transferFrom(account[0].address, account[1].address, 0, {"from": account[0]})
