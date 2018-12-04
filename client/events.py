from web3.auto import w3
import time
# from infura import *
import config
import json


with open("../build/contracts/EtherBank.json") as f:
    ether_bank_json = json.load(f)
ether_bank_contract = w3.eth.contract(
    address=config.ETHER_BANK_ADDR,
    abi=ether_bank_json['abi']
)
accounts = w3.eth.accounts


def handle_event(event):
    receipt = w3.eth.waitForTransactionReceipt(event['transactionHash'])
    result = ether_bank_contract.events.greeting.processReceipt(receipt)
    print(result[0]['args'])


def log_loop(event_filter, poll_interval):
    while True:
        for event in event_filter.get_new_entries():
            handle_event(event)
            time.sleep(poll_interval)


block_filter = w3.eth.filter({
    'fromBlock': 'latest',
    'address': config.ETHER_BANK_ADDR
})
log_loop(block_filter, 2)
