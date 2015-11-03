local GeminiHook = Apollo.GetPackage("Gemini:Hook-1.0").tPackage

local kAdditionalItems = {
    -- Crafting Mats from Crafting Vendor
        -- Weaponsmith
            81866, 81870, 81874, 81878, 81882,
}


local CXport = {}


function CXport:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end


function CXport:Init()
    self.saveData = {}
    self.isScanning = false
    self.queueSize = 0

    local bHasConfigureFunction = false
    local strConfigureButtonText = ""
    local tDependencies = {
        "MarketplaceCommodity",
        "MarketplaceListings",
    }

    GeminiHook:Embed(self)
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end


function CXport:OnLoad()
    self.MarketplaceCommodity = Apollo.GetAddon("MarketplaceCommodity")
    self:PostHook(self.MarketplaceCommodity, "Initialize", "OnMarketplaceCommodityInitialize")

    Apollo.RegisterEventHandler("CommodityInfoResults", "OnCommodityInfoResults", self)

    self.Xml = XmlDoc.CreateFromFile("CXport.xml")
end


function CXport:OnMarketplaceCommodityInitialize(luaCaller)
    if self.Button ~= nil then self.Button:Destroy() end
    self.Button = Apollo.LoadForm(self.Xml, "CXportButton", self.MarketplaceCommodity.wndMain, self)
end


function CXport:OnCXportButton(wndHandler, wndControl, eMouseButton)
    self:ScanCX()
end


function CXport:OnSave(eLevel)
    if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Realm then
        return nil
    end

    return self.saveData
end

function CXport:OnRestore(eLevel, tData)
    if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Realm then
        return nil
    end

    if tData then
        self.saveData = tData
    end
end


function CXport:ScanCX()
    self.saveData = {}
    self.saveData.timestamp = os.date("!%c")
    self.saveData.items = {}

    local queue = {}

    for idx1, tTopCategory in ipairs(MarketplaceLib.GetCommodityFamilies()) do
        for idx2, tMidCategory in ipairs(MarketplaceLib.GetCommodityCategories(tTopCategory.nId)) do
            for idx3, tBotCategory in pairs(MarketplaceLib.GetCommodityTypes(tMidCategory.nId)) do
                for idx4, tItem in pairs(MarketplaceLib.GetCommodityItems(tBotCategory.nId)) do
                    table.insert(queue, tItem.nId)
                end
            end
        end
    end

    self.queueSize = #queue
    self.isScanning = true

    for i, nItemId in ipairs(kAdditionalItems) do
        self:AddItem(nItemId)
    end

    for i, nItemId in ipairs(queue) do
        MarketplaceLib.RequestCommodityInfo(nItemId)
    end
end


function CXport:OnCommodityInfoResults(nItemId, tStats, tOrders)
    if self.isScanning then
        self.queueSize = self.queueSize - 1
        self:AddItem(nItemId, tStats)
        if self.queueSize == 0 then
            self.isScanning = false
            RequestReloadUI()
        end
    end
end


function CXport:AddItem(nItemId, tStats)

    tSaveItem = {}

    item = Item.GetDataFromId(nItemId)


    -- General Item Info

    tSaveItem.name = item:GetName()
    tSaveItem.categoryTop = item:GetItemFamilyName() or ""
    tSaveItem.categoryMid = item:GetItemCategoryName() or ""
    tSaveItem.categoryBot = item:GetItemTypeName() or ""


    -- Vendor Price Data

    local vendorSell = item:GetBuyPrice()
    local vendorBuy = item:GetSellPrice()

    if vendorSell then
        if vendorSell:GetTypeString() == "Credits" then
            tSaveItem.vendorSell = vendorSell:GetAmount()
        end
    end

    if vendorBuy then
        if vendorBuy:GetTypeString() == "Credits" then
            tSaveItem.vendorBuy = vendorBuy:GetAmount()
        end
    end


    -- Commodity Price & Qty Data

    if tStats then
        tSaveItem.commodityBuyOrderCount = tStats.nBuyOrderCount or 0
        tSaveItem.commoditySellOrderCount = tStats.nSellOrderCount or 0

        if tSaveItem.commodityBuyOrderCount > 0 then
            tSaveItem.commodityBuyTop1 = tStats.arBuyOrderPrices[1].monPrice:GetAmount()
            tSaveItem.commodityBuyTop10 = tStats.arBuyOrderPrices[2].monPrice:GetAmount()
            tSaveItem.commodityBuyTop50 = tStats.arBuyOrderPrices[3].monPrice:GetAmount()
        end

        if tSaveItem.commoditySellOrderCount > 0 then
            tSaveItem.commoditySellTop1 = tStats.arSellOrderPrices[1].monPrice:GetAmount()
            tSaveItem.commoditySellTop10 = tStats.arSellOrderPrices[2].monPrice:GetAmount()
            tSaveItem.commoditySellTop50 = tStats.arSellOrderPrices[3].monPrice:GetAmount()
        end
    end

    self.saveData.items[nItemId] = tSaveItem
end


local CXportInst = CXport:new()
CXportInst:Init()
