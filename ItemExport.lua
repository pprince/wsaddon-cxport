-- Utility Functions etc.

local function Set (list)
    local set = {}
    for _, l in ipairs(list) do set[l] = true end
    return set
end


    


-- Begin Module/AddOn ItemExport


local ItemExport = {}


function ItemExport:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    self.saveData = {}
    self.isScanning = false
    self.queueSize = 0
    self.additionalItems = {
        19194,  -- One-Nine Fine Carbon
        19195,  -- Two-Nines Fine Carbon
        19196,  -- Three-Nines Fine Carbon
        19190,  -- Fine Thread
        14769,  -- Mage Thread
        14785,  -- Star Thread
        19197,  -- Spiroseed Oil
        19198,  -- Coralscale Oil
        19199,  -- Flameseed Oil
        19191,  -- Low Viscosity Flux
        19192,  -- Medium Viscosity Flux
        19193,  -- High Viscosity Flux
        19305,  -- Bonding Interface
    }
    return o
end


function ItemExport:Init()
    Apollo.RegisterAddon(self, true, "ItemExport", {
        "MarketplaceCommodity",
        "MarketplaceListings"
    })
end


function ItemExport:OnLoad()
    Apollo.RegisterEventHandler("CommodityInfoResults", "OnCommodityInfoResults", self)
    Apollo.RegisterSlashCommand("cxport", "OnSlashCommand_cxport", self);
    Apollo.RegisterSlashCommand("craftingexport", "OnSlashCommand_craftingexport", self);
end


function ItemExport:OnSlashCommand_cxport()
    self.saveData.items = {}
    self:ScanCX()
end


function ItemExport:OnSave(eLevel)
    if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Realm then
        return nil
    end

    local save = {}
    save = self.saveData

    return save
end


function ItemExport:OnRestore(eLevel, tData)
    if tData.items then
        self.saveData.items = tData.items
    end
end


function ItemExport:ScanCX()
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

    for i, nItemId in ipairs(self.additionalItems) do
        self:AddItem(nItemId)
    end

    for i, nItemId in ipairs(queue) do
        MarketplaceLib.RequestCommodityInfo(nItemId)
    end
end


function ItemExport:OnCommodityInfoResults(nItemId, tStats, tOrders)
    if self.isScanning then
        self.queueSize = self.queueSize - 1
        if self.queueSize == 0 then
            self.isScanning = false
        end
    else
        -- error
        return nil
    end

    self:AddItem(nItemId, tStats)
end


function ItemExport:AddItem(nItemId, tStats)
    item = Item.GetDataFromId(nItemId)
    tItemInfo = item:GetDetailedInfo()

    tSaveItem = {}

    tSaveItem.name = tItemInfo.tPrimary.strName

    if tItemInfo.tPrimary.tCost.arMonBuy and tItemInfo.tPrimary.tCost.arMonBuy[1] then
        tSaveItem.vendorSell = tItemInfo.tPrimary.tCost.arMonBuy[1]:GetAmount()
    else
        tSaveItem.vendorSell = 0
    end

    if tItemInfo.tPrimary.tCost.arMonSell and tItemInfo.tPrimary.tCost.arMonSell[1] then
        tSaveItem.vendorBuy = tItemInfo.tPrimary.tCost.arMonSell[1]:GetAmount()
    else
        tSaveItem.vendorBuy = 0
    end

    if tStats then
        tSaveItem.commodityBuy = tStats.arBuyOrderPrices[1].monPrice:GetAmount()
        tSaveItem.commoditySell = tStats.arSellOrderPrices[1].monPrice:GetAmount()
        tSaveItem.commodityBuyTop10 = tStats.arBuyOrderPrices[2].monPrice:GetAmount()
        tSaveItem.commoditySellTop10 = tStats.arSellOrderPrices[2].monPrice:GetAmount()
        tSaveItem.commodityBuyTop50 = tStats.arBuyOrderPrices[3].monPrice:GetAmount()
        tSaveItem.commoditySellTop50 = tStats.arSellOrderPrices[3].monPrice:GetAmount()
        tSaveItem.commodityBuyOrderCount = tStats.nBuyOrderCount or 0
        tSaveItem.commoditySellOrderCount = tStats.nSellOrderCount or 0
    else
        tSaveItem.commodityBuy = 0
        tSaveItem.commoditySell = 0
        tSaveItem.commodityBuyTop10 = 0
        tSaveItem.commoditySellTop10 = 0
        tSaveItem.commodityBuyTop50 = 0
        tSaveItem.commoditySellTop50 = 0
        tSaveItem.commodityBuyOrderCount = 0
        tSaveItem.commoditySellOrderCount = 0
    end

    self.saveData.items[nItemId] = tSaveItem
end


function ItemExport:OnSlashCommand_craftingexport()
    local sCircuitBoardTradeskills = Set({
        CraftingLib.CodeEnumTradeskill.Armorer,
        CraftingLib.CodeEnumTradeskill.Outfitter,
        CraftingLib.CodeEnumTradeskill.Tailor,
        CraftingLib.CodeEnumTradeskill.Weaponsmith,
    })

    for idx, tTradeskill in ipairs(CraftingLib.GetKnownTradeskills()) do
        if sCircuitBoardTradeskills[tTradeskill.eId] then
            self:ExportTradeskill(tTradeskill)
        end
    end
end


function ItemExport:ExportTradeskill(tTradeskill) -- {[eId], [strName]}
    if not self.saveData.schematics then
        self.saveData.schematics = {}
    end

    self.saveData.schematics[tTradeskill.strName] = {}

    local tSchematics = CraftingLib.GetSchematicList(tTradeskill.eId, nil, nil, true) -- include not-known schematics

    for idx, tSchematic in ipairs(tSchematics) do
        self.saveData.schematics[tTradeskill.strName][tSchematic.nSchematicId] = CraftingLib.GetSchematicInfo(tSchematic.nSchematicId) 
    end
end



local ItemExportInst = ItemExport:new()
ItemExport:Init()
