import os
import config
import events

print('set-account: {}'.format(config.USERS['user1']['priv']))
os.system('python3.7 etherbank_cli.py set-account --private_key {0}'
    .format(config.USERS['user1']['priv']))

print('get-loan: {0} ETD by depositing {1} ETH'.format(600, 10))
os.system('python3.7 etherbank_cli.py get-loan --ether {0} --dollar {1}'
    .format(10, 600))

print('get-balance: {}'.format(config.USERS['user1']['addr']))
os.system('python3.7 etherbank_cli.py get-balance --account {0}'
    .format(config.USERS['user1']['addr']))

print('approve-amount: {0} approve {1} ETD to the contract'.format(config.USERS['user1']['addr'], 300))
os.system('python3.7 etherbank_cli.py approve-amount --spender {0} --dollar {1} --private_key {2}'
    .format(config.ETHER_BANK_ADDR, 300, config.USERS['user1']['priv']))

print('allowance: {0} approved {1} ETD to the contract'.format(config.USERS['user1']['addr'], 300))
os.system('python3.7 etherbank_cli.py allowance --owner {0} --spender {1}'
    .format(config.USERS['user1']['addr'], config.ETHER_BANK_ADDR))

print('settle-loan: settle {0} ETD of the lon {1}'.format(300, 1))
os.system('python3.7 etherbank_cli.py settle-loan --dollar {0} --loan_id {1}'
    .format(300, 1))

print("loans: {}'s loans".format(config.USERS['user1']['addr']))
print('loans:')
os.system('python3.7 etherbank_cli.py loans --account {0}'
    .format(config.USERS['user1']['addr']))

print('get-balance: {}'.format(config.USERS['user1']['addr']))
os.system('python3.7 etherbank_cli.py get-balance --account {0}'
    .format(config.USERS['user1']['addr']))

print('edit-oracles: set {0} for {1}'.format(100, config.USERS['user4']['addr']))
os.system('python3.7 oracles_cli.py edit-oracles --oracle {0} --score {1} --private_key {2}'
    .format(config.USERS['user4']['addr'], 100, config.BASE_ACCOUNT_PRIVATE))

print('vote: {0} set {1} for variable {2}'.format(config.USERS['user4']['addr'], 5, 1))
os.system('python3.7 oracles_cli.py vote --type_code {0} --value {1} --private_key {2}'
    .format(1, 5, config.USERS['user4']['priv']))

print('vote: {0} set {1} for variable {2}'.format(config.USERS['user4']['addr'], 5, 2))
os.system('python3.7 oracles_cli.py vote --type_code {0} --value {1} --private_key {2}'
    .format(2, 1, config.USERS['user4']['priv']))

print('liquidate: loan {}'.format(1))
os.system('python3.7 etherbank_cli.py liquidate --loan_id {0}'
    .format(1))

print('All liquidations:')
events.liquidations()

print('get-loan: {0} ETD by depositing {1} ETH'.format(1000, 90))
os.system('python3.7 etherbank_cli.py get-loan --ether {0} --dollar {1} --private_key {2}'
    .format(90, 1000, config.USERS['user2']['priv']))

print('approve-amount: {0} approve {1} ETD to the contract'.format(config.USERS['user2']['addr'], 1000))
os.system('python3.7 etherbank_cli.py approve-amount --spender {0} --dollar {1} --private_key {2}'
    .format(config.LIQUIDATOR_ADDR, 1000, config.USERS['user2']['priv']))

print('place-bid: {0} palce a bid with {1} ETD for {2} liquidation'.format(config.USERS['user2']['addr'], 8, 1))
os.system('python3.7 liquidator_cli.py place-bid --liquidation_id {0} --ether {1} --private_key {2}'
    .format(1, 8, config.USERS['user2']['priv']))

print('get-best-bid:')
os.system('python3.7 liquidator_cli.py get-best-bid --liquidation_id {0}'
    .format(1))

print('stop-liquidation: liquidation ID {}'.format(1))
os.system('python3.7 liquidator_cli.py stop-liquidation --liquidation_id {0} --private_key {1}'
    .format(1, config.USERS['user2']['priv']))

print('get-varibles:')
os.system('python3.7 etherbank_cli.py get-variables')
