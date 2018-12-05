from web3.auto import w3
import uuid
import time
import sha3
import ganache as network
# import infura as network
import config
import events


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
        'nonce': hex(network.get_nonce(signer)),
        'data': data
    }
    signed = w3.eth.account.signTransaction(transaction, priv)
    return signed.rawTransaction.hex()


# ETHER BANK FUNCTIONS

def get_loan(collateral, amount, account, account_priv):
    print('get_loan:')
    part1 = sha3.keccak_256(b'getLoan(uint256)').hexdigest()[:8]
    part2 = pad32(amount * 100)  # CONVERT DOLLAR TO CENT
    collateral *= 10**18  # CONVERT ETHER TO WEI
    data = '0x{0}{1}'.format(part1, part2)
    print(data)
    raw_transaction = sign_transaction(
        config.ETHER_BANK_ADDR,
        collateral,
        data,
        account,
        account_priv
    )
    result = network.send_raw_transaction(raw_transaction)
    print(result)


def get_balance(account):
    print('get_balance:')
    part1 = sha3.keccak_256(b'balanceOf(address)').hexdigest()[:8]
    part2 = pad32(hex2int(account))
    data = '0x{0}{1}'.format(part1, part2)
    result = network.send_eth_call(
        config.BASE_ACCOUNT,
        data,
        config.ETHER_DOLLAR_ADDR
    )
    print(hex2int(result))


def approve_amount(spender, value, account, account_priv):
    print('approve_amount:')
    part1 = sha3.keccak_256(b'approve(address,uint256)').hexdigest()[:8]
    part2 = pad32(hex2int(spender))
    part3 = pad32(value * 100)  # CONVERT DOLLAR TO CENT
    data = '0x{0}{1}{2}'.format(part1, part2, part3).lower()
    raw_transaction = sign_transaction(
        config.ETHER_DOLLAR_ADDR,
        0,
        data,
        account,
        account_priv
    )
    result = network.send_raw_transaction(raw_transaction)
    print(result)


def allowance(owner, spender):
    print('allowance:')
    part1 = sha3.keccak_256(b'allowance(address,address)').hexdigest()[:8]
    part2 = pad32(hex2int(owner))
    part3 = pad32(hex2int(spender))
    data = '0x{0}{1}{2}'.format(part1, part2, part3)
    result = network.send_eth_call(
        spender,
        data,
        config.ETHER_DOLLAR_ADDR
    )
    print(hex2int(result))


def settle_loan(amount, loan_id, account, account_priv):
    print('settle_loan:')
    part1 = sha3.keccak_256(b'settleLoan(uint256,uint256)').hexdigest()[:8]
    part2 = pad32(amount * 100)
    part3 = pad32(loan_id)
    data = '0x{0}{1}{2}'.format(part1, part2, part3)
    raw_transaction = sign_transaction(
        config.ETHER_BANK_ADDR,
        0,
        data,
        account,
        account_priv
    )
    result = network.send_raw_transaction(raw_transaction)
    print(result)


# ORACLES FUNCTIONS


def edit_oracles(oracle_account, score):
    print('edit_oracles:')
    part1 = sha3.keccak_256(b'edit(address,uint64)').hexdigest()[:8]
    part2 = pad32(hex2int(oracle_account))
    part3 = pad32(score)
    data = '0x{0}{1}{2}'.format(part1, part2, part3)
    raw_transaction = sign_transaction(
        config.ORACLES_ADDR,
        0,
        data,
        config.BASE_ACCOUNT,
        config.BASE_ACCOUNT_PRIVATE
    )
    result = network.send_raw_transaction(raw_transaction)
    print(result)


def vote(vote_type, value, oracle_addr, oracle_priv):
    print('vote:')
    part1 = sha3.keccak_256(b'vote(uint8,uint256)').hexdigest()[:8]
    part2 = pad32(vote_type)
    part3 = pad32(value)
    data = '0x{0}{1}{2}'.format(part1, part2, part3)
    raw_transaction = sign_transaction(
        config.ORACLES_ADDR,
        0,
        data,
        oracle_addr,
        oracle_priv
    )
    result = network.send_raw_transaction(raw_transaction)
    print(result)


def finish_recruiting(owner_addr, owner_priv):
    print('finishRecruiting:')
    part1 = sha3.keccak_256(b'finishRecruiting()').hexdigest()[:8]
    data = '0x{0}'.format(part1)
    raw_transaction = sign_transaction(
        config.ORACLES_ADDR,
        0,
        data,
        owner_addr,
        owner_priv
    )
    result = network.send_raw_transaction(raw_transaction)
    print(result)


if __name__ == '__main__':
    get_loan(10, 500, config.USERS['user1']['addr'], config.USERS['user1']['priv'])
    time.sleep(1)
    get_balance(config.BASE_ACCOUNT)
    time.sleep(1)
    approve_amount(config.ETHER_BANK_ADDR, 500, config.USERS['user1']['addr'], config.USERS['user1']['priv'])
    time.sleep(1)
    allowance(config.BASE_ACCOUNT, config.ETHER_BANK_ADDR)
    time.sleep(1)
    events.loans(config.USERS['user1']['addr'])
    time.sleep(1)
    events.loan(1)
    time.sleep(1)
    settle_loan(250, 1, config.USERS['user1']['addr'], config.USERS['user1']['priv'])
    time.sleep(1)
    get_balance(config.BASE_ACCOUNT)
    time.sleep(1)
    events.loans(config.USERS['user1']['addr'])

    # edit_oracles(config.USERS['user1']['add'], 100)
    # time.sleep(1)
    # edit_oracles(config.USERS['user2']['add'], 40)
    # time.sleep(1)
    # edit_oracles(config.USERS['user3']['add'], 70)
    # time.sleep(1)
    # vote(0, 200, config.USERS['user1']['add'], config.USERS['user1']['priv'])
    # time.sleep(1)
    # vote(0, 200, config.USERS['user2']['add'], config.USERS['user2']['priv'])
    # finish_recruiting(config.BASE_ACCOUNT, config.BASE_ACCOUNT_PRIVATE)
    # time.sleep(1)
    # edit_oracles(config.USERS['user1']['add'], 100)
