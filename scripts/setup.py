from brownie import accounts, config, network, NFT, web3


def get_account():
    if network.show_active() == "development":
        return accounts
    else:
        return accounts.from_mnemonic(config["wallets"]["from_mnemonic"], count=5)
    

def main():
    account = get_account()
    contract = NFT.deploy(
        "Test",
        "TT",
        web3.toWei(0.1, "ether"),
        {"from": account[0]}
    )
    contract.tx.wait(5)
    txCall = contract.cobaRandom.call()
    print(txCall)