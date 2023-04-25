# @version 0.3.7


interface INFT:
    def transferFrom(from_: address, to_: address, tokenId_:uint256): nonpayable
    def safeTransferFrom(from_: address, to_: address, tokenId_: uint256, data_: Bytes[1024]=b""): nonpayable

token: public(INFT)

@external
def __init__(nft_: address):
    self.token = INFT(nft_)

@external
def deposit(tokenId_: uint256):
    self.token.transferFrom(msg.sender, self, tokenId_)

@external
def withdraw(tokenId_: uint256):
    self.token.transferFrom(self, msg.sender, tokenId_)