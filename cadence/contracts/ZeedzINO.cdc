import NonFungibleToken from "./NonFungibleToken.cdc"

/*
    The official ZeedzINO contract
*/
pub contract ZeedzINO: NonFungibleToken {

    // Events
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, metadata: {String : String})
    pub event Burned(id: UInt64, from: Address?)
    pub event ZeedleLeveledUp(id: UInt64)

    // Named Paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath
    pub let AdminPrivatePath: PrivatePath

    pub var totalSupply: UInt64

    pub resource NFT: NonFungibleToken.INFT {
        pub let id: UInt64
        pub let typeID: UInt64 // Zeedle type -> e.g "Ginger, Aloe etc"
        pub var level: UInt64 // Zeedle level
        access(self) let metadata: {String: String} // Additional metadata

        init(initID: UInt64, initTypeID: UInt64, initMetadata: {String: String}) {
            self.id = initID
            self.typeID = initTypeID
            self.level = 0
            self.metadata = initMetadata
        }

        pub fun getMetadata(): {String: String} {
            return self.metadata
        }

        pub fun getLevel(): UInt64 {
            return self.level
        }

        access(contract) fun levelUp() {
            self.level = self.level + 1
        }

        pub fun getTypeID(): UInt64 {
            return self.typeID
        }
    }

    /* 
        This is the interface that users can cast their Zeedz Collection as
        to allow others to deposit Zeedles into their Collection. It also allows for reading
        the details of Zeedles in the Collection.
    */ 
    pub resource interface ZeedzCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun burn(burnID: UInt64)
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowZeedle(id: UInt64): &ZeedzINO.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow Zeedle reference: The ID of the returned reference is incorrect"
            }
        }
    }

    /* 
        A collection of Zeedz NFTs owned by an account
    */
    pub resource Collection: ZeedzCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {

        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <-token
        }

        pub fun burn(burnID: UInt64){
             let token <- self.ownedNFTs.remove(key: burnID) ?? panic("missing NFT")
             destroy token
             emit Burned(id: burnID, from: self.owner?.address)
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @ZeedzINO.NFT
            let id: UInt64 = token.id
            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token
            emit Deposit(id: id, to: self.owner?.address)
            destroy oldToken
        }

        /*
            Returns an array of the IDs that are in the collection
         */
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        /*
            Gets a reference to an NFT in the collection
            so that the caller can read its metadata and call its methods
        */
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return &self.ownedNFTs[id] as &NonFungibleToken.NFT
        }

        /*
            borrowZeedle
            Gets a reference to an NFT in the collection as a Zeed,
            exposing all of its fields
            this is safe as there are no functions that can be called on the Zeed.
        */
        pub fun borrowZeedle(id: UInt64): &ZeedzINO.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
                return ref as! &ZeedzINO.NFT
            } else {
                return nil
            }
        }

        destroy() {
            destroy self.ownedNFTs
        }

        init () {
            self.ownedNFTs <- {}
        }
    }

    /*
        Public function that anyone can call to create a new empty collection
    */ 
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    /*
        The Admin/Minter resource used to mint Zeedz
    */
    pub resource Administrator {

        /*
            Mints a new NFT with a new ID
            and deposit it in the recipients collection using their collection reference
        */
        pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}, typeID: UInt64, metadata: {String : String}) {
            emit Minted(id: ZeedzINO.totalSupply, metadata: metadata)
            recipient.deposit(token: <-create ZeedzINO.NFT(initID: ZeedzINO.totalSupply, initTypeID: typeID, metadata: metadata))
            ZeedzINO.totalSupply = ZeedzINO.totalSupply + (1 as UInt64)
        }

        /*
            Increse the Zeedle's level by 1
        */
        pub fun levelUpZeedle(zeedleRef: &ZeedzINO.NFT) {
            zeedleRef.levelUp()
            emit ZeedleLeveledUp(id: zeedleRef.id)
        }
    }

    /*
        Get a reference to a Zeedle from an account's Collection, if available.
        If an account does not have a Zeedz.Collection, panic.
        If it has a collection but does not contain the zeedleId, return nil.
        If it has a collection and that collection contains the zeedleId, return a reference to that.
    */
    pub fun fetch(_ from: Address, zeedleID: UInt64): &ZeedzINO.NFT? {
        let collection = getAccount(from)
            .getCapability(ZeedzINO.CollectionPublicPath)!
            .borrow<&ZeedzINO.Collection{ZeedzINO.ZeedzCollectionPublic}>()
            ?? panic("Couldn't get collection")
        return collection.borrowZeedle(id: zeedleID)
    }


    init() {
        self.CollectionStoragePath = /storage/ZeedzINOCollection
        self.CollectionPublicPath = /public/ZeedzINOCollection
        self.AdminStoragePath = /storage/ZeedzINOMinter
        self.AdminPrivatePath=/private/ZeedzINOAdminPrivate

        self.totalSupply = 0

        self.account.save(<- create Administrator(), to: self.AdminStoragePath)
        self.account.link<&Administrator>(self.AdminPrivatePath, target: self.AdminStoragePath)

        emit ContractInitialized()
    }
}