import ZeedzDrops from 0xZEEDZ_DROPS

transaction(productID: UInt64) {

    let dropsAdmin: &ZeedzDrops.DropsAdmin{ZeedzDrops.ProductsManager}

    prepare(acct: AuthAccount) {
        self.dropsAdmin = acct.borrow<&ZeedzDrops.DropsAdmin{ZeedzDrops.ProductsManager}>(from: ZeedzDrops.ZeedzDropsStoragePath)
            ?? panic("Missing or mis-typed admin resource")
    }

    execute {
        self.dropsAdmin.removeProduct(productID: productID)
    }
}