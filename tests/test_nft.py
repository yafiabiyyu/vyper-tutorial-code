import pytest, brownie
from brownie import accounts, NFT, web3, myToken


@pytest.fixture
def token():
    contract = NFT.deploy(
        "Test NFT",
        "TST",
        web3.toWei(0.1, "ether"),
        {"from": accounts[0]},
    )
    contract.mint({"from": accounts[0], "value": web3.toWei(0.1, "ether")})
    return contract

@pytest.fixture
def target(token):
    return myToken.deploy(token.address, {"from": accounts[0]})

def test_update_fee_from_owner(token):
    token.setFee(web3.toWei(0.2, "ether"), {"from": accounts[0]})
    assert token.fee() == web3.toWei(0.2, "ether")


def test_update_fee_fails_from_non_owner(token):
    with brownie.reverts("ERC721: Only dev can set fee"):
        token.setFee(web3.toWei(0.2, "ether"), {"from": accounts[1]})


def test_update_fee_fails_zero_fee(token):
    with brownie.reverts("ERC721: Fee must be greater than 0"):
        token.setFee(0, {"from": accounts[0]})


def test_transfer_ownership(token):
    token.transferOwnership(accounts[1], {"from": accounts[0]})
    assert token.dev() == accounts[1]


def test_fails_transfer_ownership_from_non_owner(token):
    with brownie.reverts("ERC721: Only dev can transfer ownership"):
        token.transferOwnership(accounts[1], {"from": accounts[1]})


def test_fails_transfer_ownership_to_zero_address(token):
    with brownie.reverts("ERC721: Owner cannot be zero address"):
        token.transferOwnership(
            "0x0000000000000000000000000000000000000000", {"from": accounts[0]}
        )


# NFT Testing

def test_minting(token):
    token.mint({"from": accounts[1], "value": web3.toWei(0.1, "ether")})

    assert token.balanceOf(accounts[1].address) == 1
    assert token.ownerOf(1) == accounts[1].address

def test_minting_fails(token):
    with brownie.reverts("ERC721: Invalid amount"):
        token.mint({"from": accounts[1], "value": web3.toWei("0.5", "ether")})

def test_approve(token):
    token.approve(accounts[1].address, 0, {"from": accounts[0]})
    assert token.getApproved(0) == accounts[1].address

def test_approve_fails_zero_address(token):
    with brownie.reverts("ERC721: Approve to the zero address"):
        token.approve("0x0000000000000000000000000000000000000000", 0, {"from": accounts[0]})

def test_approve_fails_to_owner(token):
    with brownie.reverts("ERC721: Approve to current owner"):
        token.approve(accounts[0].address, 0, {"from": accounts[0]})

def test_approve_fails_invalid_tokenid(token):
    with brownie.reverts("ERC721: Invalid token id"):
        token.approve(accounts[1].address, 1, {"from": accounts[0]})

def test_approve_fails_not_owner(token):
    with brownie.reverts("ERC721: Not owner or approved for all"):
        token.approve(accounts[2].address, 0, {"from": accounts[1]})

def test_set_approval_all(token):
    token.setApprovalForAll(accounts[1].address, True, {"from": accounts[0]})
    assert token.isApprovedForAll(accounts[0].address, accounts[1].address) == True

def test_set_approval_all_fails_zero_address(token):
    with brownie.reverts("ERC721: Approve to the zero address"):
        token.setApprovalForAll("0x0000000000000000000000000000000000000000", True, {"from": accounts[0]})

def test_set_approval_all_fails_to_owner(token):
    with brownie.reverts("ERC721: Approve to caller"):
        token.setApprovalForAll(accounts[0].address, True, {"from": accounts[0]})

def test_transfer(token, target):
    token.transferFrom(accounts[0].address, accounts[1].address, 0, {"from": accounts[0]})
    assert token.balanceOf(accounts[1].address) == 1
    assert token.ownerOf(0) == accounts[1].address

    # Transfer to contract
    token.approve(target.address, 0, {"from": accounts[1]})
    target.deposit(0, {"from": accounts[1]})
    assert token.balanceOf(accounts[1].address) == 0
    assert token.balanceOf(target.address) == 1
    assert token.ownerOf(0) == target.address

    # Transfer from contract
    target.withdraw(0, {"from": accounts[1]})
    assert token.balanceOf(accounts[1].address) == 1
    assert token.balanceOf(target.address) == 0
    assert token.ownerOf(0) == accounts[1].address

def test_transfer_fails_invalid_tokenid(token):
    with brownie.reverts("ERC721: Invalid token id"):
        token.transferFrom(accounts[0].address, accounts[1].address, 1, {"from": accounts[0]})

def test_transfer_fails_zero_address(token):
    with brownie.reverts("ERC721: Transfer to the zero address"):
        token.transferFrom(accounts[0], "0x0000000000000000000000000000000000000000", 0, {"from": accounts[0]})

def test_transfer_fails_not_owner_or_approval(token):
    with brownie.reverts("ERC721: Not owner or approved"):
        token.transferFrom(accounts[0].address, accounts[1].address, 0, {"from": accounts[1]})