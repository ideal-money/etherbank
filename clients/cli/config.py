from web3.auto import w3

USERS = {
    'user1': {
        'addr': '0x8fd9Bf9c6297b57f97948222c074c927E3bDDd75',
        'priv': '93449babbac70bfdefc807a0f012c74cd68f92ca35eaf952e991a329f88fc850'
    },
    'user2': {
        'addr': '0xd7a322f4b4d49FC552D9a9ea3059Fd840347Bf40',
        'priv': '97e25f630d89328f755bb00057005df4ea25acc0a017335c50d1ca0c0d91b386'
    },
    'user3': {
        'addr': '0x0857b69396e39e691CC4cA118eB8cA979EcC3363',
        'priv': 'c796de7b9b4b7362ed3b23b14d083c103eacd84f77770bc55f138700d76b428c'
    },
    'user4': {
        'addr': '0xaC996056eA91b1C54a7761Ece74B451b8Ec92885',
        'priv': '9e0080b15a099ca9a7aac5049ab833d064511d9ae01f6b253392a406c3824896'
    }
}

BASE_ACCOUNT = '0x24DE3890921219051424e5EEd1Dd4B91C3823663'
BASE_ACCOUNT_PRIVATE = '05bc4b317399235288624bec16a1b24b45df8c5401f86d4ce893ed6a26481d14'

GAS = 5*10**6
GAS_PRICE = 150*10**9
UNIT = 1.0*10**18

# INFURA_ENDPOINT = 'https://ropsten.infura.io/c556c4fcd2d64c41baef3ef84e33052a'

ETHER_DOLLAR_ADDR = w3.toChecksumAddress(
    '0x4752196af598ffea1f4d7cb51ff42a5529f68602')

ETHER_BANK_ADDR = w3.toChecksumAddress(
    '0x3130f14038a44a11986d0f1919f68684e6fa93aa')

ORACLES_ADDR = w3.toChecksumAddress(
    '0xbfaa3e93b4900a39524e6481e45228382722a1de')

LIQUIDATOR_ADDR = w3.toChecksumAddress(
    '0x5129f5ab0d65d4c2262fcfdd453e1b1bb1aeb232')
