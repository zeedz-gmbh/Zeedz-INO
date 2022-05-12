pub contract ZeedzDrops {

    pub event PackPurchased(packID: UInt64, details: PackDetails, currency: String, userID: String)

    pub event PackAdded(packID: UInt64, packDetails: PackDetails)

    pub event PacksReserved(packID: UInt64, amount: UInt64)

    pub event PackRemoved(packID: UInt64)

    pub let ZeedzDropsAdminStoragePath: StoragePath

    access(contract) var saleCutRequirements: {String : [SaleCutRequirement]}

    access(contract) var packs: @{UInt64: Pack}

    pub struct SaleCutRequirement {
        pub let receiver: Capability<&{FungibleToken.Receiver}>

        pub let ratio: UFix64

        init(receiver: Capability<&{FungibleToken.Receiver}>, ratio: UFix64) {
            pre {
                ratio <= 1.0: "ratio must be less than or equal to 1.0"
                reciever.borrow() != nil: "invalid reciever capability"
            }
            self.receiver = receiver
            self.ratio = ratio
        }
    }

    pub struct PackDetails {
        // pack name
        pub let name: String

        // description
        pub let description: String

        // product id
        pub let productId: UInt64

        // total pack item quantity
        pub let total: UInt64

        // {Type of the FungibleToken => price}
        pub let prices: {String : UFix64}

        // total packs sold
        pub var sold: UInt64

        // if true, the pack is buyable
        pub var saleEnabled: Bool

        // pack sale start timestamp
        pub var timeStart: UFix64

        // pack sale start timestamp
        pub var timeEnd: UFix64

        init (
            name: String, 
            description: String, 
            productId: UInt64, 
            total: UInt64, 
            saleEnabled: Bool, 
            timeStart: UFix64, 
            timeEnd: UFix64, 
            prices: {String : UFix64}) {
            self.name = name
            self.description = description
            self.productId = productId
            self.total = total
            self.sold = 0
            self.timeStart = timeStart
            self.timeEnd = timeEnd
            self.prices = prices
            self.saleEnabled = saleEnabled
        }

        access(contract) fun setSaleEnabledStatus(status: Bool){
            self.saleEnabled = status
        }

        access(contract) fun setStartTime(startTime: UFix64){
            self.timeStart = startTime
        }

        access(contract) fun setEndTime(startTime: UFix64){
            self.timeEnd = endTime
        }

        access(contract) fun setSold(sold: UInt64){
            self.sold = sold
        }

        access(contract) fun reserve(amount: UInt64){
            self.sold = self.sold - amount
        }
    }


    pub interface PackPublic {
        pub fun purchase(payment: @FungibleToken.Vault, )
        pub fun getDetails(): PackDetails
    }

    pub resource interface PacksManage {
        pub fun setSaleEnabledStatus(status: Bool)
        pub fun setStartTime(startTime: UFix64)
        pub fun setEndTime(endTime: UFix64)
        pub fun reserve(packID: UInt64, amount: UInt64)
        pub fun removePack(packID: UInt64)
        pub fun purchaseWithDiscount(packID: UInt64, payment: @FungibleToken.Vault, discount: UFix64, valutType: vaultType)
        pub fun addPack(
            name: String, 
            description: String, 
            productId: UInt64, 
            total: UInt64, 
            saleEnabled: Bool, 
            timeStart: UFix64, 
            timeEnd: UFix64, 
            prices: {String : UFix64})
    }

    pub resource interface DropsManage {
        pub fun updateSaleCutRequirement(requirements: [SaleCutRequirement], vaultType: Type)
    }

    pub resource Pack: PackPublic {
  
        access(self) let details: PackDetails

        pub fun getDetails(): PackDetails {
            return self.details
        }

        pub fun purchase(payment: @FungibleToken.Vault, valutType: Type, userID: String) {
            pre {
                self.saleEnabled == true: "the sale of this pack is disabled"
                (self.details.total - self.sold) > 0: "these packs are sold out"
                payment.isInstance(valutType): "payment vault is not requested fungible token type"
                payment.balance == self.details.prices[valutType.identifier]: "payment vault does not contain requested price"
                getCurrentBlock().timestamp > self.timeStart: "the sale of this pack has not started yet"
                getCurrentBlock().timestamp < self.timeEnd: "the sale of this pack has ended"
                self.saleCutRequirements[vaultType.identifier] != nil: "sale cuts not set for requested fungible token"
            }

            var residualReceiver: &{FungibleToken.Receiver}? = nil

            for cut in self.saleCutRequirements[vaultType.identifier] {
                if let receiver = cut.receiver.borrow() {
                   let paymentCut <- payment.withdraw(amount: cut.ratio * self.details.prices[vaultType.identifier])
                    receiver.deposit(from: <-paymentCut)
                    if (residualReceiver == nil) {
                        residualReceiver = receiver
                    }
                }
            }

            assert(residualReceiver != nil, message: "no valid payment receivers")

            residualReceiver!.deposit(from: <-payment)

            emit PackPurchased(packID: self.uuid, details: self.details, currency: valutType.identifier, userId: String)
        }

        acess(contract) fun purchaseWithDiscount(payment: @FungibleToken.Vault, discount: UFix64, packID: UInt64, valutType: Type){
             pre {
                self.discount < 1: "discount cannot be higher than 100%"
                self.saleEnabled == true: "the sale of this pack is disabled"
                (self.details.total - self.sold) > 0: "these packs are sold out"
                payment.isInstance(valutType): "payment vault is not requested fungible token type"
                (payment.balance*discount) == self.details.prices[valutType.identifier]: "payment vault does not contain requested price"
                getCurrentBlock().timestamp > self.timeStart: "the sale of this pack has not started yet"
                getCurrentBlock().timestamp < self.timeEnd: "the sale of this pack has ended"
                self.saleCutRequirements[vaultType.identifier] != nil: "sale cuts not set for requested fungible token"
            }

            var residualReceiver: &{FungibleToken.Receiver}? = nil

            for cut in self.saleCutRequirements[vaultType.identifier] {
                if let receiver = cut.receiver.borrow() {
                   let paymentCut <- payment.withdraw(amount: cut.ratio * self.details.prices[vaultType.identifier]*discount)
                    receiver.deposit(from: <-paymentCut)
                    if (residualReceiver == nil) {
                        residualReceiver = receiver
                    }
                }
            }

            assert(residualReceiver != nil, message: "no valid payment receivers")

            residualReceiver!.deposit(from: <-payment)

            emit PackPurchased(packID: self.uuid, details: self.details, currency: valutType.identifier, userId: String)
        }

        pub fun borrowPack(id: UInt64): &Pack? {
            if self.ownedNFTs[id] != nil {
                let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
                return ref as! &ZeedzINO.NFT
            } else {
                return nil
            }
        }

        destroy () {
            emit PackRemoved(
                packID: self.uuid,
            )
        }

        init (
            name: String, 
            description: String, 
            productId: UInt64, 
            total: UInt64, 
            saleEnabled: Bool, 
            timeStart: UFix64, 
            timeEnd: UFix64, 
            prices: {String : UFix64}) {
            self.details = PackDetails(
              name: String, 
              description: String, 
              productId: UInt64, 
              total: UInt64, 
              saleEnabled: Bool, 
              timeStart: UFix64, 
              timeEnd: UFix64, 
              prices: {String : UFix64}
            )
        }
    }

    pub resource Administrator: PacksManage, DropsManage {
        pub fun addPack(
            name: String, 
            description: String, 
            productId: UInt64, 
            total: UInt64, 
            saleEnabled: Bool, 
            timeStart: UFix64, 
            timeEnd: UFix64, 
            prices: {String : UFix64}): UInt64{
            let pack <- create Pack(
                        name: name, 
                        description: description, 
                        productId: productId,
                        total: total,
                        saleEnabled: saleEnabled,
                        timeStart: timeStart,
                        timeEnd: timeEnd,
                        prices: prices
                    )

            let packID = pack.uuid

            let details = pack.getDetails()

            emit PackAdded(
                packID: packID,
                packDetails: details
            )

            return packID
        }

        pub fun reserve(packID: UInt64, packID: UInt64, amount: UInt64){
            let pack = self.borrowPack(packID) ?? panic("not able to find specified pack")
            pack.reserve(amount: amount)
            emit PacksReserved(packID: packID, amount: amount)

        }
        pub fun removePack(packID: UInt64){
            pre {
                self.packs[packID] != nil: "could not find pack with given id"
            }

            let pack <- self.packs.remove(key: packID)!
            destroy pack
            emit PackRemoved(packID: packID)
        }

        pub fun setSaleEnabledStatus(status: Bool, packID: UInt64){
            let pack = self.borrowPack(packID) ?? panic("not able to find specified pack")
            pack.setSaleEnabledStatus(status: status)
        }

        pub fun setStartTime(startTime: UFix64, packID: UInt64){
            let pack = self.borrowPack(packID) ?? panic("not able to find specified pack")
            pack.setStartTime(startTime: startTime)
        }

        pub fun setEndTime(endTime: UFix64, packID: UInt64){
            let pack = self.borrowPack(packID) ?? panic("not able to find specified pack")
            pack.setEndTime(endTime: endTime)
        }

        pub fun purchaseWithDiscount(packID: UInt64, payment: @FungibleToken.Vault, discount: UFix64, packID: UInt64, valutType: Type){
            let pack = self.borrowPack(packID) ?? panic("not able to find specified pack")
            pack.purchaseWithDiscount(payment, discount, packID, vaultType: vaultType)
        }

        pub fun updateSaleCutRequirement(requirements: [SaleCutRequirement], vaultType: Type) {
            var totalRatio: UFix64 = 0.0
            for requirement in requirements {
                totalRatio = totalRatio + requirement.ratio
            }
            assert(totalRatio <= 1.0, message: "total ratio must be less than or equal to 1.0")
            ZeedzMarketplace.saleCutRequirements[vaultType.identifier] = requirements
        }

        init(){
             self.packs <- {}
        }
    }

    pub fun getAllSaleCutRequirements(): {String: [SaleCutRequirement]} {
        return self.saleCutRequirements
    }

    pub fun borrowPack(id: UInt64): &Pack? {
        if self.packs[id] != nil {
            return &self.packs[id] as! &Pack
        } else {
            return nil
        }
    }

    init () {
        self.ZeedzDropsAdminStoragePath = /storage/ZeedzDropsAdmin
        self.saleCutRequirements = {}

        let admin <- create Administrator()
        self.account.save(<-admin, to: self.ZeedzDropsAdminStoragePath)
    }
}