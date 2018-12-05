from web3.auto import w3
import config
import json


def loans(account):
    print('get_loans')
    retsult = {}
    with open("../build/contracts/EtherBank.json") as f:
        ether_bank_json = json.load(f)
    ether_bank_contract = w3.eth.contract(
        address=config.ETHER_BANK_ADDR, abi=ether_bank_json['abi'])
    loan_filter = ether_bank_contract.events.LoanGot.createFilter(
        fromBlock=1, toBlock='latest', argument_filters={'borrower': account})
    for loan in loan_filter.get_all_entries():
        loan_id = loan['args']['loanId']
        retsult[loan_id] = dict(loan['args'])
        settle_filter = ether_bank_contract.events.LoanSettled.createFilter(
            fromBlock=1,
            toBlock='latest',
            argument_filters={'loanId': loan_id})
        for settle in settle_filter.get_all_entries():
            retsult[loan_id]['collateralAmount'] -= settle['args'][
                'collateralAmount']
            retsult[loan_id]['amount'] -= settle['args']['amount']
        print(retsult[loan_id])
    return retsult


def loan(loan_id):
    print('get_loan')
    retsult = {}
    with open("../build/contracts/EtherBank.json") as f:
        ether_bank_json = json.load(f)
    ether_bank_contract = w3.eth.contract(
        address=config.ETHER_BANK_ADDR, abi=ether_bank_json['abi'])
    loan_filter = ether_bank_contract.events.LoanGot.createFilter(
        fromBlock=1, toBlock='latest', argument_filters={'loanId': loan_id})
    loan = loan_filter.get_all_entries()
    if loan:
        retsult = dict(loan[0]['args'])
        settle_filter = ether_bank_contract.events.LoanSettled.createFilter(
            fromBlock=1,
            toBlock='latest',
            argument_filters={'loanId': loan_id})
        for settle in settle_filter.get_all_entries():
            retsult['collateralAmount'] -= settle['args']['collateralAmount']
            retsult['amount'] -= settle['args']['amount']
        print(retsult)
    return retsult
