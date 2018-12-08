var EtherDollar = artifacts.require('EtherDollar.sol');
var EtherBank = artifacts.require('EtherBank.sol');
var Oracles = artifacts.require('Oracles.sol');
var Liquidator = artifacts.require('Liquidator.sol');

module.exports = function (deployer) {
  deployer.then(async () => {

    await deployer.deploy(EtherDollar);
    const instanceEtherDollar = await EtherDollar.deployed();

    await deployer.deploy(EtherBank, instanceEtherDollar.address);
    const instanceEtherBank = await EtherBank.deployed();

    await instanceEtherDollar.transferOwnership(instanceEtherBank.address);

    await deployer.deploy(Oracles, instanceEtherBank.address);
    const instanceOracles = await Oracles.deployed();

    await deployer.deploy(Liquidator, instanceEtherDollar.address, instanceEtherBank.address);
    const instanceLiquidator = await Liquidator.deployed();

    await instanceEtherBank.setLiquidator(instanceLiquidator.address)
    await instanceEtherBank.setOracle(instanceOracles.address)

  })
}
