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

def get_variables():
    print('get_variables:')
    part1 = sha3.keccak_256(b'getVariable()').hexdigest()[:8]
    data = '0x{0}'.format(part1)
    result = network.send_eth_call(
        config.BASE_ACCOUNT,
        data,
        config.ETHER_DOLLAR_ADDR
    )
    print(result)


def get_loan(collateral_amount, loan_amount, account, account_priv):
    print('get_loan:')
    part1 = sha3.keccak_256(b'getLoan(uint256)').hexdigest()[:8]
    part2 = pad32(loan_amount * 100)  # CONVERT DOLLAR TO CENT
    collateral_amount *= 10**18  # CONVERT ETHER TO WEI
    data = '0x{0}{1}'.format(part1, part2)
    print(data)
    raw_transaction = sign_transaction(
        config.ETHER_BANK_ADDR,
        collateral_amount,
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


def settle_loan(loan_amount, loan_id, account, account_priv):
    print('settle_loan:')
    part1 = sha3.keccak_256(b'settleLoan(uint256,uint256)').hexdigest()[:8]
    part2 = pad32(loan_amount * 100)
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


def liquidate(loan_id, account, account_priv):
    print('liquidate:')
    part1 = sha3.keccak_256(b'liquidate(uint256)').hexdigest()[:8]
    part2 = pad32(loan_id)
    data = '0x{0}{1}'.format(part1, part2)
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


# LIQUIDATOR FUNCTIONS

def place_bid(liquidate_id, amount, account, account_priv):
    print('place_bid:')
    part1 = sha3.keccak_256(b'placeBid(uint256,uint256)').hexdigest()[:8]
    part2 = pad32(liquidate_id)
    part3 = pad32(amount * 10**18)
    data = '0x{0}{1}{2}'.format(part1, part2, part3)
    raw_transaction = sign_transaction(
        config.LIQUIDATOR_ADDR,
        0,
        data,
        account,
        account_priv
    )
    result = network.send_raw_transaction(raw_transaction)
    print(result)


def stop_liquidate(liquidate_id, account, account_priv):
    print('stop_liquidate:')
    part1 = sha3.keccak_256(b'stopLiquidation(uint256)').hexdigest()[:8]
    part2 = pad32(liquidate_id)
    data = '0x{0}{1}'.format(part1, part2)
    raw_transaction = sign_transaction(
        config.LIQUIDATOR_ADDR,
        0,
        data,
        account,
        account_priv
    )
    result = network.send_raw_transaction(raw_transaction)
    print(result)


def get_best_bid(liquidate_id):
    print('get_best_bid:')
    part1 = sha3.keccak_256(b'getBestBid(uint256)').hexdigest()[:8]
    part2 = pad32(liquidate_id)
    data = '0x{0}{1}'.format(part1, part2)
    result = network.send_eth_call(
        config.BASE_ACCOUNT,
        data,
        config.LIQUIDATOR_ADDR
    )
    print(result[:66], hex2int('0x{0}'.format(result[66:])))


def withdraw(amount, account, account_priv):
    print('get_best_bid:')
    part1 = sha3.keccak_256(b'withdraw(uint256)').hexdigest()[:8]
    part2 = pad32(amount * 100)
    data = '0x{0}{1}'.format(part1, part2)
    raw_transaction = sign_transaction(
        config.LIQUIDATOR_ADDR,
        0,
        data,
        account,
        account_priv
    )
    result = network.send_raw_transaction(raw_transaction)
    print(result)


if __name__ == '__main__':
    # get_loan(10, 500, config.USERS['user1']['addr'], config.USERS['user1']['priv'])
    # time.sleep(1)
    # get_balance(config.USERS['user1']['addr'])
    # time.sleep(1)
    # approve_amount(config.ETHER_BANK_ADDR, 500, config.USERS['user1']['addr'], config.USERS['user1']['priv'])
    # time.sleep(1)
    # allowance(config.USERS['user1']['addr'], config.ETHER_BANK_ADDR)
    # time.sleep(1)
    # events.loans(config.USERS['user1']['addr'])
    # time.sleep(1)
    # events.loan(1)
    # time.sleep(1)
    # settle_loan(250, 1, config.USERS['user1']['addr'], config.USERS['user1']['priv'])
    # time.sleep(1)
    # get_balance(config.USERS['user1']['addr'])
    # time.sleep(1)
    # events.loans(config.USERS['user1']['addr'])
    # time.sleep(1)
    # events.update()
    # time.sleep(1)
    # edit_oracles(config.USERS['user1']['addr'], 100)
    # time.sleep(1)
    # edit_oracles(config.USERS['user2']['addr'], 40)
    # time.sleep(1)
    # edit_oracles(config.USERS['user3']['addr'], 70)
    # time.sleep(1)
    # vote(0, 200, config.USERS['user1']['addr'], config.USERS['user1']['priv'])
    # time.sleep(1)
    # vote(0, 50, config.USERS['user3']['addr'], config.USERS['user3']['priv'])
    # time.sleep(1)
    # vote(0, 200, config.USERS['user1']['addr'], config.USERS['user1']['priv'])
    # time.sleep(1)
    # events.update()
    # time.sleep(1)

    get_loan(10, 600, config.USERS['user1']['addr'], config.USERS['user1']['priv'])
    get_loan(99, 1000, config.USERS['user2']['addr'], config.USERS['user2']['priv'])

    get_balance(config.USERS['user1']['addr'])
    get_balance(config.USERS['user2']['addr'])

    time.sleep(1)
    edit_oracles(config.USERS['user1']['addr'], 100)
    time.sleep(1)
    edit_oracles(config.USERS['user2']['addr'], 80)
    time.sleep(1)
    vote(0, 80, config.USERS['user1']['addr'], config.USERS['user1']['priv'])
    time.sleep(1)
    vote(1, 3, config.USERS['user1']['addr'], config.USERS['user1']['priv'])
    time.sleep(1)
    vote(3, 1, config.USERS['user1']['addr'], config.USERS['user1']['priv'])
    time.sleep(1)
    events.votes()
    time.sleep(1)
    events.update()
    time.sleep(1)
    liquidate(1, config.USERS['user4']['addr'], config.USERS['user4']['priv'])
    time.sleep(1)
    events.liquidations()
    time.sleep(1)
    approve_amount(config.LIQUIDATOR_ADDR, 600, config.USERS['user1']['addr'], config.USERS['user1']['priv'])
    time.sleep(1)
    place_bid(1, 9, config.USERS['user1']['addr'], config.USERS['user1']['priv'])
    time.sleep(1)
    approve_amount(config.LIQUIDATOR_ADDR, 700, config.USERS['user2']['addr'], config.USERS['user2']['priv'])
    time.sleep(1)
    place_bid(1, 7, config.USERS['user2']['addr'], config.USERS['user2']['priv'])
    time.sleep(1)
    get_balance(config.USERS['user1']['addr'])
    get_balance(config.USERS['user2']['addr'])
    events.update()
    time.sleep(1)
    get_best_bid(1)
    time.sleep(1)
    stop_liquidate(1, config.USERS['user4']['addr'], config.USERS['user4']['priv'])
    time.sleep(1)
    withdraw(600, config.USERS['user1']['addr'], config.USERS['user1']['priv'])
    get_balance(config.USERS['user1']['addr'])
    get_balance(config.USERS['user2']['addr'])
