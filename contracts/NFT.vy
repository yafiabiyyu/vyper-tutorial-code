# @dev Implementation of ERC-721 non-fungible token standard.
# @author Abiyyu Yafi (@yafiabiyyu)
# Modified from: https://github.com/vyperlang/vyper/blob/de74722bf2d8718cca46902be165f9fe0e3641dd/examples/tokens/ERC721.vy

# @version 0.3.7

from vyper.interfaces import ERC165
from vyper.interfaces import ERC721

implements: ERC165
implements: ERC721


# DEFINE INTERFACE

interface ERC721Receiver:
    def onERC721Received(
        _operator: address,
        _from: address,
        _tokenId: uint256,
        _data: Bytes[1024]
    ) -> bytes4: nonpayable

interface IRandom:
    def random() -> bytes32: view


# DEFINE GLOBAL VARIABLES

_name: String[50]
_symbol: String[10]
_counter: uint256
_mintingFee: uint256
_dev: address
_RANDOM: IRandom

SUPPORTED_INTERFACES: constant(bytes4[2]) = [
    0x01ffc9a7,
    0x80ac58cd
]


# DEFINE MAPPINGS

_owner: HashMap[uint256, address]
_balance: HashMap[address, uint256]
_tokenApprovals: HashMap[uint256, address]
_operatorApprovals: HashMap[address, HashMap[address, bool]]


# DEFINE EVENTS

event TransferOwnerShip:
    owner: indexed(address)
    oldOwner: indexed(address)

event Transfer:
    sender: indexed(address)
    receiver: indexed(address)
    tokenId: uint256

event Approval:
    owner: indexed(address)
    spender: indexed(address)
    tokenId: uint256

event ApprovalForAll:
    owner: indexed(address)
    operator: indexed(address)
    approved: bool


@external
def __init__(name_: String[50], symbol_: String[10], mintingFee_: uint256):
    self._name = name_
    self._symbol = symbol_
    self._counter = 0
    self._mintingFee = mintingFee_
    self._dev = msg.sender
    self._RANDOM = IRandom(0xdd318EEF001BB0867Cd5c134496D6cF5Aa32311F)


# DEFINE DEV FUNCTIONS

@external
def setFee(fee_: uint256):
    assert msg.sender == self._dev, "ERC721: Only dev can set fee"
    assert fee_ > 0, "ERC721: Fee must be greater than 0"
    self._mintingFee = fee_

@external
def transferOwnership(newOwner_: address):
    assert msg.sender == self._dev, "ERC721: Only dev can transfer ownership"
    assert newOwner_ != empty(address), "ERC721: Owner cannot be zero address"
    self._dev = newOwner_
    log TransferOwnerShip(msg.sender, newOwner_)


# DEFINE ERC721 FUNCTIONS

@pure
@external
def supportsInterface(interface_id: bytes4) -> bool:
    """
    @dev Interface identification is specified in ERC-165.
    @param interface_id Id of the interface
    """
    return interface_id in SUPPORTED_INTERFACES

@view
@external
def name() -> String[50]:
    return self._name

@view
@external
def symbol() -> String[10]:
    return self._symbol

@view
@external
def fee() -> uint256:
    return self._mintingFee

@view
@external
def dev() -> address:
    return self._dev

@view
@external
def balanceOf(owner_: address) -> uint256:
    return self._balance[owner_]

@view
@external
def ownerOf(tokenId_: uint256) -> address:
    return self._ownerOf(tokenId_)

@view
@external
def getApproved(tokenId_: uint256) -> address:
    return self._tokenApprovals[tokenId_]

@view
@external
def isApprovedForAll(owner_: address, operator_: address) -> bool:
    return self._operatorApprovals[owner_][operator_]

@external
def approve(spender_: address, tokenId_: uint256):
    owner_: address = self._ownerOf(tokenId_)
    assert spender_ != empty(address), "ERC721: Approve to the zero address"
    assert spender_ != owner_, "ERC721: Approve to current owner"
    assert self._exist(tokenId_), "ERC721: Invalid token id"

    senderIsOwner: bool = self._ownerOf(tokenId_) == msg.sender
    senderIsApproved: bool = self._operatorApprovals[self._ownerOf(tokenId_)][msg.sender]
    assert senderIsOwner or senderIsApproved, "ERC721: Not owner or approved for all"
    self._tokenApprovals[tokenId_] = spender_
    log Approval(owner_, spender_, tokenId_)

@external
def setApprovalForAll(operator_: address, approved_: bool):
    assert operator_ != empty(address), "ERC721: Approve to the zero address"
    assert operator_ != msg.sender, "ERC721: Approve to caller"
    self._operatorApprovals[msg.sender][operator_] = approved_
    log ApprovalForAll(msg.sender, operator_, approved_)

@external
def transferFrom(from_: address, to_: address, tokenId_: uint256):
    self._transfer(from_, to_, msg.sender, tokenId_)

@external
def safeTransferFrom(from_: address, to_: address, tokenId_: uint256, data_: Bytes[1024]=b""):
    self._transfer(from_, to_, msg.sender, tokenId_)
    if to_.is_contract: # check if `_to` is a contract address
        returnValue: bytes4 = ERC721Receiver(to_).onERC721Received(msg.sender, from_, tokenId_, data_)
        # Throws if transfer destination is a contract which does not implement 'onERC721Received'
        assert returnValue == method_id("onERC721Received(address,address,uint256,bytes)", output_type=bytes4)

@external
@payable
def mint():
    assert msg.value == self._mintingFee, "ERC721: Invalid amount"
    self._owner[self._counter] = msg.sender
    self._balance[msg.sender] += 1
    self._counter += 1


@external
def burn(tokenId_: uint256):
    assert self._isApprovedOrOwner(msg.sender, tokenId_), "ERC721: Not owner or approved"
    owner: address = self._ownerOf(tokenId_)
    assert owner != empty(address), "ERC721: Invalid token id"
    self._balance[owner] -= 1
    self._owner[tokenId_] = empty(address)
    self._tokenApprovals[tokenId_] = empty(address)




# DEFINE INTERNAL FUNCTIONS

@internal
def _transfer(from_: address, to_: address, sender_: address, tokenId_: uint256):
    assert self._exist(tokenId_), "ERC721: Invalid token id"
    assert to_ != empty(address), "ERC721: Transfer to the zero address"
    assert self._isApprovedOrOwner(sender_, tokenId_), "ERC721: Not owner or approved"

    self._balance[from_] -= 1
    self._balance[to_] += 1

    # Remove previous approvals
    if self._tokenApprovals[tokenId_] != empty(address):
        self._tokenApprovals[tokenId_] = empty(address)
    
    self._owner[tokenId_] = to_
    log Transfer(from_, to_, tokenId_)


@view
@internal
def _isApprovedOrOwner(spender_: address, tokenId_: uint256) -> bool:
    owner_: address = self._ownerOf(tokenId_)
    spenderIsOwner: bool = owner_ == spender_
    spenderIsApproved: bool = spender_ == self._tokenApprovals[tokenId_]
    spenderIsApprovedForAll: bool = self._operatorApprovals[owner_][spender_]
    return (spenderIsOwner or spenderIsApproved) or spenderIsApprovedForAll
@view
@internal
def _exist(tokenId_: uint256) -> bool:
    return self._owner[tokenId_] != empty(address)

@view
@internal
def _ownerOf(tokenId_: uint256) -> address:
    return self._owner[tokenId_]