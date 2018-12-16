import os
import json
import uuid
from web3.auto import w3
from eth_keys import keys
import ganache as network
import config


def check_account(ctx, param, value):
    if value:
        return value
    elif os.path.exists('ETHEREUM_ACCOUNT'):
        with open('ETHEREUM_ACCOUNT', 'r') as f:
            return f.read()
    else:
        print('Set account first!')
        ctx.abort()


def priv2addr(private_key):
    pk = keys.PrivateKey(bytes.fromhex(private_key))
    return pk.public_key.to_checksum_address()


def hex2int(s):
    assert s.startswith('0x')
    return int(s[2:], 16)


def pad32(n):
    return format(n, '064X')


def new_address():
    rand_hex = uuid.uuid4().hex
    account = w3.eth.account.create(rand_hex)
    return (account.address, account.privateKey.hex())


def sign_transaction(contract_addr, wei_amount, data, private_key):
    transaction = {
        'to': contract_addr,
        'value': hex(int(wei_amount)),
        'gas': hex(config.GAS),
        'gasPrice': hex(config.GAS_PRICE),
        'nonce': hex(network.get_nonce(priv2addr(private_key))),
        'data': data
    }
    signed = w3.eth.account.signTransaction(transaction, private_key)
    return signed.rawTransaction.hex()


def get_abi(contract_name):
    with open("../../build/contracts/{}.json".format(contract_name)) as f:
        return json.load(f)['abi']
