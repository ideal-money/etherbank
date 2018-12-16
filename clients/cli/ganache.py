import os
from web3.auto import w3
import config


def get_nonce(signer):
    return w3.eth.getTransactionCount(signer)


def send_eth_call(sender, data, contract_addr):
    res = w3.eth.call({
        'from': sender,
        'to': contract_addr,
        'data': data
    })
    return res.hex()


def send_raw_transaction(raw_transaction):
    res = w3.eth.sendRawTransaction(raw_transaction)
    return res.hex()
