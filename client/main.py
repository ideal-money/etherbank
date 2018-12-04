from web3.auto import w3
import uuid
import time
import sha3
from ganache import *
# from infura import *
import config
import json


def ether_bank_events():
    print('ether_bank_events')
    with open("../build/contracts/EtherBank.json") as f:
        ether_bank_json = json.load(f)
    ether_bank_contract = w3.eth.contract(
        address=config.ETHER_BANK_ADDR, abi=ether_bank_json['abi'])
    myfilter = ether_bank_contract.eventFilter('LoanGot', {
        'fromBlock': 0,
        'toBlock': 'latest'
    })
    eventlist = myfilter.get_all_entries()
    print(eventlist)


def ether_dollar_events():
    print('ether_dollar_events')
    with open("../build/contracts/EtherDollar.json") as f:
        ether_dollar_json = json.load(f)
    ether_dollar_contract = w3.eth.contract(
        address=config.ETHER_DOLLAR_ADDR, abi=ether_dollar_json['abi'])
    myfilter = ether_dollar_contract.eventFilter('Approval', {
        'fromBlock': 0,
        'toBlock': 'latest'
    })
    eventlist = myfilter.get_all_entries()
    print(eventlist)


def hex2int(s):
    assert s.startswith('0x')
    return int(s[2:], 16)


def pad32(n):
    return format(n, '064X')


def new_address():
    rand_hex = uuid.uuid4().hex
    account = w3.eth.account.create(rand_hex)
    return (account.address, account.privateKey.hex())


def sign_transaction(contract_addr, wei_amount, data, signer, priv):
    transaction = {
        'to': contract_addr,
        'value': hex(int(wei_amount)),
        'gas': hex(config.GAS),
        'gasPrice': hex(config.GAS_PRICE),
        'nonce': hex(get_nonce(signer)),
        'data': data
    }
    signed = w3.eth.account.signTransaction(transaction, priv)
    return signed.rawTransaction.hex()


def get_loan(collateral, amount):
    print('get_loan:')
    part1 = sha3.keccak_256(b'getLoan(uint256)').hexdigest()[:8]
    part2 = pad32(amount * 100)  # CONVERT DOLLAR TO CENT
    collateral *= 10**18  # CONVERT ETHER TO WEI
    data = '0x{0}{1}'.format(part1, part2)
    print(data)
    raw_transaction = sign_transaction(config.ETHER_BANK_ADDR, collateral,
                                       data, config.BASE_ACCOUNT,
                                       config.BASE_ACCOUNT_PRIVATE)
    result = send_raw_transaction(raw_transaction)
    print(result)


def get_balance(account):
    print('get_balance:')
    part1 = sha3.keccak_256(b'balanceOf(address)').hexdigest()[:8]
    part2 = pad32(hex2int(account))
    data = '0x{0}{1}'.format(part1, part2)
    result = send_eth_call(config.BASE_ACCOUNT, data, config.ETHER_DOLLAR_ADDR)
    print(hex2int(result))


def approve_amount(spender, value):
    print('approve_amount:')
    part1 = sha3.keccak_256(b'approve(address,uint256)').hexdigest()[:8]
    part2 = pad32(hex2int(spender))
    part3 = pad32(value * 100)  # CONVERT DOLLAR TO CENT
    data = '0x{0}{1}{2}'.format(part1, part2, part3).lower()
    raw_transaction = sign_transaction(config.ETHER_DOLLAR_ADDR, 0, data,
                                       config.BASE_ACCOUNT,
                                       config.BASE_ACCOUNT_PRIVATE)
    result = send_raw_transaction(raw_transaction)
    print(result)


def allowance(owner, spender):
    print('allowance:')
    part1 = sha3.keccak_256(b'allowance(address,address)').hexdigest()[:8]
    part2 = pad32(hex2int(owner))
    part3 = pad32(hex2int(spender))
    data = '0x{0}{1}{2}'.format(part1, part2, part3)
    result = send_eth_call(config.BASE_ACCOUNT, data, config.ETHER_DOLLAR_ADDR)
    print(hex2int(result))


def settle_loan(amount, loan_id):
    print('settle_loan:')
    part1 = sha3.keccak_256(b'settleLoan(uint256,uint256)').hexdigest()[:8]
    part2 = pad32(amount * 100)
    part3 = pad32(loan_id)
    data = '0x{0}{1}{2}'.format(part1, part2, part3)
    raw_transaction = sign_transaction(config.ETHER_BANK_ADDR, 0, data,
                                       config.BASE_ACCOUNT,
                                       config.BASE_ACCOUNT_PRIVATE)
    result = send_raw_transaction(raw_transaction)
    print(result)


if __name__ == '__main__':
    get_loan(10, 500)
    time.sleep(1)
    get_balance(config.BASE_ACCOUNT)
    time.sleep(1)
    approve_amount(config.ETHER_BANK_ADDR, 500)
    time.sleep(1)
    allowance(config.BASE_ACCOUNT, config.ETHER_BANK_ADDR)
    time.sleep(1)
    settle_loan(500, 1)
    time.sleep(1)
    get_balance(config.BASE_ACCOUNT)
