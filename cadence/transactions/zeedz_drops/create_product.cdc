import ZeedzDrops from 0xZEEDZ_DROPS

transaction(name: String, description: String, id: String, total: UInt64, saleEnabled: Bool, timeStart: UFix64, timeEnd: UFix64, prices: {String : UFix64}) {

    let dropsAdmin: &ZeedzDrops.DropsAdmin{ZeedzDrops.ProductsManager}

    prepare(acct: AuthAccount) {
        self.dropsAdmin = acct.borrow<&ZeedzDrops.DropsAdmin{ZeedzDrops.ProductsManager}>(from: ZeedzDrops.ZeedzDropsStoragePath)
            ?? panic("Missing or mis-typed admin resource")
    }

    execute {
        self.dropsAdmin.addProduct(name: name, description: description, id: id, total: total, saleEnabled: saleEnabled, timeStart: timeStart, timeEnd: timeEnd, prices: prices)
    }
}