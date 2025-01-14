import ZeedzDrops from 0xZEEDZ_DROPS
import FiatToken from 0xFIAT_TOKEN
import FungibleToken from 0xFUNGIBLE_TOKEN

transaction(productID: UInt64, userID: String) {

    let productRef: &ZeedzDrops.Product{ZeedzDrops.ProductPublic}
    let paymentVault: @FungibleToken.Vault
    let vaultType: Type

    prepare(acct: AuthAccount) {
        self.productRef =  ZeedzDrops.borrowProduct(id: productID) 
            ?? panic("Product with specified id not found")

        self.vaultType = Type<@FiatToken.Vault>()

        let price = self.productRef.getDetails().getPrices()[self.vaultType.identifier]
            ?? panic("Cannot get Fiat Token price for product")

        let mainFiatVault = acct.borrow<&FiatToken.Vault>(from: FiatToken.VaultStoragePath)
            ?? panic("Cannot borrow FiatToken vault from acct storage")

        self.paymentVault <- mainFiatVault.withdraw(amount: price)
    }

    execute {
       self.productRef.purchase(payment: <- self.paymentVault, vaultType: self.vaultType, userID: userID)
    }
}