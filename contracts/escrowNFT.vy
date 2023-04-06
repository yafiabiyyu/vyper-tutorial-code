# @version 0.3.7

from vyper.interfaces import ERC721
from vyper.interfaces import ERC20
from interfaces import IRandom

fee: public(uint256)
randoms: public(IRandom)
owner: immutable(address)


enum Status:
    Pending
    Accepted
    Rejected
    Canceled

struct EscrowData:
    tokenId: uint256
    amount: uint256
    nft: address
    payment: address
    seller: address
    buyer: address
    status: Status

escrowData: EscrowData

idToEscrow: public(HashMap[uint256, EscrowData])

event NewEscrow:
    _escrowId: uint256
    _tokenId: uint256
    _nftAddress: address
    _sellerAddress: address
    _buyerAddress: address
    _amount: uint256

@external
def __init__(_fee: uint256):
    self.fee = _fee
    self.randoms = IRandom(0xdd318EEF001BB0867Cd5c134496D6cF5Aa32311F)
    owner = msg.sender

@external
def updateFee(_fee: uint256):
    assert msg.sender == owner
    self.fee = _fee

@internal
@view
def _generateId() -> uint256:
    randomHash: bytes32 = keccak256(
        concat(
            blockhash(block.number - 16),
            self.randoms.random()
        )
    )
    return convert(randomHash, uint256) % 100000000