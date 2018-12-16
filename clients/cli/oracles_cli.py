import sha3
import click
from web3.auto import w3
import utils
import config
import ganache as network
# import infura as network


@click.group()
def main():
    "Simple CLI for oracles to work with Ether dollar"
    pass


@main.command()
@click.option('--type_code', type=int, required=True, help="The variable type")
@click.option('--value', type=int, required=True, help="The vote's value")
@click.option('--private_key', callback=utils.check_account, help='The privat key to sign the transaction')
def vote(type_code, value, private_key):
    'Vote on the variable for setting up Ether Bank'

    part1 = sha3.keccak_256(b'vote(uint8,uint256)').hexdigest()[:8]
    part2 = utils.pad32(type_code)
    part3 = utils.pad32(value)
    data = '0x{0}{1}{2}'.format(part1, part2, part3)
    raw_transaction = utils.sign_transaction(config.ORACLES_ADDR, 0, data, private_key)
    result = network.send_raw_transaction(raw_transaction)
    click.secho(result, fg='green')


@main.command()
@click.option('--oracle', required=True, help="The oracle's address")
@click.option('--score', type=int, required=True, help="The oracle's score")
@click.option('--private_key', callback=utils.check_account, help='The privat key to sign the transaction')
def edit_oracles(oracle, score, private_key):
    "Edit oracle's score"

    part1 = sha3.keccak_256(b'edit(address,uint64)').hexdigest()[:8]
    part2 = utils.pad32(utils.hex2int(oracle))
    part3 = utils.pad32(score)
    data = '0x{0}{1}{2}'.format(part1, part2, part3)
    raw_transaction = utils.sign_transaction(config.ORACLES_ADDR, 0, data, private_key)
    result = network.send_raw_transaction(raw_transaction)
    click.secho(result, fg='green')


@main.command()
@click.option('--private_key', callback=utils.check_account, help='The privat key to sign the transaction')
def finish_recruiting(private_key):
    'Set recruiting as finished'

    part1 = sha3.keccak_256(b'finishRecruiting()').hexdigest()[:8]
    data = '0x{0}'.format(part1)
    raw_transaction = utils.sign_transaction(config.ORACLES_ADDR, 0, data, private_key)
    result = network.send_raw_transaction(raw_transaction)
    click.secho(result, fg='green')


@main.command()
def get_variables():
    contract = w3.eth.contract(
        address=config.ETHER_BANK_ADDR, abi=utils.get_abi('EtherBank'))
    result = {
        'depositRate': contract.call().depositRate(),
        'etherPrice': contract.call().etherPrice(),
        'liquidationDuration': contract.call().liquidationDuration()
    }
    click.secho(str(result), fg='green')
    return(result)


if __name__ == '__main__':
    main()
