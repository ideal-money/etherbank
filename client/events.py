from web3.auto import w3
import config
import json


def loans(account):
    print('get_loans')
    result = {}
    with open("../build/contracts/EtherBank.json") as f:
        ether_bank_json = json.load(f)
    ether_bank_contract = w3.eth.contract(
        address=config.ETHER_BANK_ADDR, abi=ether_bank_json['abi'])
    loan_filter = ether_bank_contract.events.LoanGot.createFilter(
        fromBlock=1, toBlock='latest', argument_filters={'borrower': account})
    for loan in loan_filter.get_all_entries():
        loan_id = loan['args']['loanId']
        result[loan_id] = dict(loan['args'])
        settle_filter = ether_bank_contract.events.LoanSettled.createFilter(
            fromBlock=1,
            toBlock='latest',
            argument_filters={'loanId': loan_id})
        for settle in settle_filter.get_all_entries():
            result[loan_id]['collateralAmount'] -= settle['args'][
                'collateralAmount']
            result[loan_id]['amount'] -= settle['args']['amount']
    print(result)
    return result


def loan(loan_id):
    result = {}
    print('get_loan')
    with open("../build/contracts/EtherBank.json") as f:
        ether_bank_json = json.load(f)
    ether_bank_contract = w3.eth.contract(
        address=config.ETHER_BANK_ADDR, abi=ether_bank_json['abi'])
    loan_filter = ether_bank_contract.events.LoanGot.createFilter(
        fromBlock=1, toBlock='latest', argument_filters={'loanId': loan_id})
    loan = loan_filter.get_all_entries()
    if loan:
        result = dict(loan[0]['args'])
        settle_filter = ether_bank_contract.events.LoanSettled.createFilter(
            fromBlock=1,
            toBlock='latest',
            argument_filters={'loanId': loan_id})
        for settle in settle_filter.get_all_entries():
            result['collateralAmount'] -= settle['args']['collateralAmount']
            result['amount'] -= settle['args']['amount']
    print(result)
    return result


def update():
    print('update_variables')
    result = []
    with open("../build/contracts/Oracles.json") as f:
        oracles_json = json.load(f)
    oracles_contract = w3.eth.contract(
        address=config.ORACLES_ADDR, abi=oracles_json['abi'])
    update_filter = oracles_contract.events.Update.createFilter(
        fromBlock=1, toBlock='latest')
    updates = update_filter.get_all_entries()
    for update in updates:
        result.append(dict(update['args']))
    print(result)
    return result


def votes():
    print('votes')
    result = []
    with open("../build/contracts/Oracles.json") as f:
        oracles_json = json.load(f)
    oracles_contract = w3.eth.contract(
        address=config.ORACLES_ADDR, abi=oracles_json['abi'])
    update_filter = oracles_contract.events.SetVote.createFilter(
        fromBlock=1, toBlock='latest')
    votes = update_filter.get_all_entries()
    for vote in votes:
        result.append(dict(vote['args']))
    print(result)
    return result


def liquidations(loan_id=None):
    print('liquidations')
    result = {}
    with open("../build/contracts/Liquidator.json") as f:
        liquidator_json = json.load(f)
    liquidator_contract = w3.eth.contract(
        address=config.LIQUIDATOR_ADDR, abi=liquidator_json['abi'])
    start_filter = liquidator_contract.events.StartLiquidation.createFilter(
        fromBlock=1, toBlock='latest')
    if loan_id:
        start_filter = liquidator_contract.events.StartLiquidation.createFilter(
            fromBlock=1, toBlock='latest', argument_filters={'loanId': loan_id})
    for liquidation in start_filter.get_all_entries():
        liquidation_id = liquidation['args']['liquidationId']
        result[liquidation_id] = dict(liquidation['args'])
        stop_filter = liquidator_contract.events.StopLiquidation.createFilter(
            fromBlock=1,
            toBlock='latest',
            argument_filters={'liquidationId': liquidation_id})
        if stop_filter.get_all_entries():
            result[liquidation_id]['stope'] = dict(
                stop_filter.get_all_entries()[0])
    print(result)
    return result


def withdraw(account=None):
    print('liquidations')
    result = []
    with open("../build/contracts/Liquidator.json") as f:
        liquidator_json = json.load(f)
    liquidator_contract = w3.eth.contract(
        address=config.LIQUIDATOR_ADDR, abi=liquidator_json['abi'])
    withdraw_filter = liquidator_contract.events.Withdraw.createFilter(
        fromBlock=1, toBlock='latest')
    if account:
        withdraw_filter = liquidator_contract.events.Withdraw.createFilter(
            fromBlock=1, toBlock='latest', argument_filters={'withdrawalAccount': account})
    for withdraw in withdraw_filter.get_all_entries():
        result.append(dict(liquidation['args']['liquidationId']))
    print(result)
    return result
