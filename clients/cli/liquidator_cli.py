import sha3
import click
from web3.auto import w3
import config
import utils
import ganache as network
# import infura as network
from utils import pad32, hex2int, sign_transaction, check_account


@click.group()
def main():
    "Simple CLI for working with Ether dollar's liquidator"
    pass


@main.command()
@click.option('--liquidation_id', type=int, required=True, help="The liquidation's ID")
@click.option('--ether', type=int, required=True, help="The bid's amount")
@click.option('--private_key', callback=check_account, help='The privat key to sign the transaction')
def place_bid(liquidation_id, ether, private_key):
    'Place a bid on the liquidation'

    part1 = sha3.keccak_256(b'placeBid(uint256,uint256)').hexdigest()[:8]
    part2 = pad32(liquidation_id)
    part3 = pad32(ether * 10**18)
    data = '0x{0}{1}{2}'.format(part1, part2, part3)
    raw_transaction = sign_transaction(config.LIQUIDATOR_ADDR, 0, data, private_key)
    result = network.send_raw_transaction(raw_transaction)
    click.secho(result, fg='green')


@main.command()
@click.option('--liquidation_id', type=int, required=True, help="The liquidation's ID")
@click.option('--private_key', callback=check_account, help='The privat key to sign the transaction')
def stop_liquidation(liquidation_id, private_key):
    'Stop the finalized liquidation'

    part1 = sha3.keccak_256(b'stopLiquidation(uint256)').hexdigest()[:8]
    part2 = pad32(liquidation_id)
    data = '0x{0}{1}'.format(part1, part2)
    raw_transaction = sign_transaction(config.LIQUIDATOR_ADDR, 0, data, private_key)
    result = network.send_raw_transaction(raw_transaction)
    click.secho(result, fg='green')


@main.command()
@click.option('--liquidation_id', type=int, required=True, help="The liquidation's ID")
def get_best_bid(liquidation_id):
    "Get the best bid amount and the bidder's address for the liquidation"

    part1 = sha3.keccak_256(b'getBestBid(uint256)').hexdigest()[:8]
    part2 = pad32(liquidation_id)
    data = '0x{0}{1}'.format(part1, part2)
    result = network.send_eth_call(config.BASE_ACCOUNT, data, config.LIQUIDATOR_ADDR)
    click.secho('{0}, {1}'.format(result[:66], hex2int('0x{0}'.format(result[66:]))), fg='green')


@main.command()
@click.option('--amount', type=int, required=True, help='The amount to withdraw')
@click.option('--private_key', callback=check_account, help='The privat key to sign the transaction')
def withdraw(amount, private_key):
    'Withdraw the leftover Ether dollar from liquidations'

    part1 = sha3.keccak_256(b'withdraw(uint256)').hexdigest()[:8]
    part2 = pad32(amount * 100)
    data = '0x{0}{1}'.format(part1, part2)
    raw_transaction = sign_transaction(config.LIQUIDATOR_ADDR, 0, data, private_key)
    result = network.send_raw_transaction(raw_transaction)
    click.secho(result, fg='green')


@main.command()
@click.option('--loan_id', type=int, help="The loan's ID")
def active_liquidations(loan_id):
    result = {}
    liquidator_contract = w3.eth.contract(
        address=config.LIQUIDATOR_ADDR, abi=utils.get_abi('Liquidator'))
    start_filter = liquidator_contract.events.StartLiquidation.createFilter(
        fromBlock=1, toBlock='latest')
    if loan_id:
        start_filter = liquidator_contract.events.StartLiquidation.createFilter(
            fromBlock=1, toBlock='latest', argument_filters={'loanId': loan_id})
    for liquidation in start_filter.get_all_entries():
        liquidation_id = liquidation['args']['liquidationId']
        stop_filter = liquidator_contract.events.StopLiquidation.createFilter(
            fromBlock=1,
            toBlock='latest',
            argument_filters={'liquidationId': liquidation_id})
        if not stop_filter.get_all_entries():
            result[liquidation_id] = dict(liquidation['args'])
    click.secho(str(result), fg='green')
    return result


if __name__ == '__main__':
    main()
