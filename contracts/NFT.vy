# @dev Implementation of ERC-721 non-fungible token standard.
# @author Abiyyu Yafi (@yafiabiyyu)
# Modified from: https://github.com/vyperlang/vyper/blob/de74722bf2d8718cca46902be165f9fe0e3641dd/examples/tokens/ERC721.vy

# @version 0.3.7

from vyper.interfaces import ERC165
from vyper.interfaces import ERC721


# Define Interface

interface ERC721Receiver:
    def onERC721Received(
        _operator: address,
        _from: address,
        _tokenId: uint256,
        _data: Bytes[1024]
    ) -> bytes4: nonpayable

interface IRandom:
    def random() -> bytes32: view


# Define State Variables

_name: String[50]
_symbol: String[5]
_tokenURI: DynArray[String[100], 4]
_rarityArray: DynArray[uint256, 4]
_tokenCounter: uint256
_mintingFee: uint256

_devAddress: address
_random: IRandom
SUPPORTED_INTERFACES: constant(bytes4[2]) = [
    0x01ffc9a7,
    0x80ac58cd
]


# Define Mappings

_owner: HashMap[uint256, address]
_balance: HashMap[address, uint256]
_tokenApprovals: HashMap[uint256, address]
_operatorApprovals: HashMap[address, HashMap[address, bool]]
_tokenIdToURI: HashMap[uint256, String[100]]


# Define Events

event TransferOwnerShip:
    newOwner: indexed(address)
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
def __init__(name_: String[50], symbol_: String[5], tokenURI_: DynArray[String[100], 4], rarityArray_: DynArray[uint256, 4], mintingFee_: uint256, random_: address):
    self._name = name_
    self._symbol = symbol_
    self._tokenURI = tokenURI_
    self._rarityArray = rarityArray_
    self._tokenCounter = 0
    self._mintingFee = mintingFee_
    self._devAddress = msg.sender
    self._random = IRandom(random_)


# Define Dev Function

@external
def claimFee():
    assert msg.sender == self._devAddress, "Ownable: Only dev can call this function"
    amount: uint256 = self.balance
    send(self._devAddress, amount)

@external
def updateFee(mintingFee_: uint256):
    assert msg.sender == self._devAddress, "Ownable: Only dev can call this function"
    self._mintingFee = mintingFee_

@external
def transferOwnerShip(newOwner_: address):
    assert msg.sender == self._devAddress, "Ownable: Only dev can call this function"
    self._devAddress = newOwner_
    log TransferOwnerShip(newOwner_, msg.sender)

@view
@external
def getDev() -> address:
    return self._devAddress


# Define ERC721 Functions

@view
@external
def name() -> String[50]:
    return self._name

@view
@external
def symbol() -> String[5]:
    return self._symbol

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
def getTokenURI(tokenId_: uint256) -> String[100]:
    assert self._exist(tokenId_), "ERC721: Invalid token id"
    return self._tokenIdToURI[tokenId_]

@view
@external
def getApproved(tokenId_: uint256) -> address:
    return self._tokenApprovals[tokenId_]

@view
@external
def isApprovedForAll(owner_: address, operator_: address) -> bool:
    return self._operatorApprovals[owner_][operator_]

@view
@external
def fee() -> uint256:
    return self._mintingFee

@external
@payable
def mint():
    assert msg.value == self._mintingFee, "ERC721: Insufficient fee"
    randomNumber: uint256 = self._getRandomNumber() % 100
    rarity: uint256 = self._calculateRarity(randomNumber)
    self._setTokenURI(self._tokenCounter, self._tokenURI[rarity])
    self._owner[self._tokenCounter] = msg.sender
    self._balance[msg.sender] += 1
    log Transfer(empty(address), msg.sender, self._tokenCounter)
    self._tokenCounter += 1


@external
def burn(tokenId_: uint256):
    assert self._isApprovedOrOwner(msg.sender, tokenId_), "ERC721: Not owner or approved"
    owner: address = self._ownerOf(tokenId_)
    assert owner != empty(address), "ERC721: Invalid token id"
    self._balance[owner] -= 1
    self._owner[tokenId_] = empty(address)
    self._tokenApprovals[tokenId_] = empty(address)
    log Transfer(msg.sender, empty(address), tokenId_)

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

@pure
@external
def supportsInterface(interface_id: bytes4) -> bool:
    """
    @dev Interface identification is specified in ERC-165.
    @param interface_id Id of the interface
    """
    return interface_id in SUPPORTED_INTERFACES

@internal
def _setTokenURI(tokenId_: uint256, tokenURI_: String[100]):
    self._tokenIdToURI[tokenId_] = tokenURI_

@view
@internal
def _calculateRarity(randomNumber_: uint256) -> uint256:
    cumulativeSum: uint256 = 0
    rarity: uint256 = 0
    for i in range(4):
        if randomNumber_ >= cumulativeSum:
            if randomNumber_ < self._rarityArray[i]:
                rarity = i
        cumulativeSum = self._rarityArray[i]
    return rarity

@view
@internal
def _getRandomNumber() -> uint256:
    randomHash: bytes32 = keccak256(
        concat(blockhash(block.number - 15), self._random.random())
    )
    return convert(randomHash, uint256)

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