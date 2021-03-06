

local kAdditionalItems = {
    -- Crafting Mats from Crafting Vendor
        -- Weaponsmith
            81866, 81870, 81874, 81878, 81882,
}


local SAVE_FMT_VERSION = 44


local GeminiHook = Apollo.GetPackage("Gemini:Hook-1.0").tPackage


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


-- Portable ISO 8601 timestamp for pure Lua ...
local function now8601()
    local now = os.time()
    local tz_offset_in_seconds = os.difftime(now, os.time(os.date("!*t", now)))
    local h, m = math.modf(tz_offset_in_seconds / 3600)
    local tz_offset_hhmm = string.format("%+.4d", 100 * h + 60 * m)
    return os.date("%Y-%m-%d %H:%M:%S") .. tz_offset_hhmm
end
-- ... adapted from http://lua-users.org/wiki/TimeZone


function CXport:ScanCX()
    self.saveData = {}
    self.saveData.savefmtversion = SAVE_FMT_VERSION
    self.saveData.timestamp = now8601()
    self.saveData.realm = GameLib.GetRealmName()
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

    tSaveItem.itemName = item:GetName()
    tSaveItem.category1 = item:GetItemFamilyName() or ""
    tSaveItem.category2 = item:GetItemCategoryName() or ""
    tSaveItem.category3 = item:GetItemTypeName() or ""


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
        tSaveItem.cxBuyOrders = tStats.nBuyOrderCount or 0
        tSaveItem.cxSellOrders = tStats.nSellOrderCount or 0

        if tSaveItem.cxBuyOrders > 0 then
            tSaveItem.cxBuyTop1 = tStats.arBuyOrderPrices[1].monPrice:GetAmount()
            tSaveItem.cxBuyTop10 = tStats.arBuyOrderPrices[2].monPrice:GetAmount()
            tSaveItem.cxBuyTop50 = tStats.arBuyOrderPrices[3].monPrice:GetAmount()
        end

        if tSaveItem.cxSellOrders > 0 then
            tSaveItem.cxSellTop1 = tStats.arSellOrderPrices[1].monPrice:GetAmount()
            tSaveItem.cxSellTop10 = tStats.arSellOrderPrices[2].monPrice:GetAmount()
            tSaveItem.cxSellTop50 = tStats.arSellOrderPrices[3].monPrice:GetAmount()
        end
    end

    self.saveData.items[nItemId] = tSaveItem
end


local CXportInst = CXport:new()
CXportInst:Init()
