const { Wallet, utils } = require('ethers')

const w = new Wallet('0x110a4fa09cfa4af52aa01d064771eada70b907ccd2ea3de5aa272fe409351314')

console.log('Address:', w.address)
console.log('Public key:', w.publicKey)

const digest = utils.id('test message')
console.log('Digest: ', digest)

const sig = w._signingKey().signDigest(digest)
console.log('Compact sig:', sig.compact)
