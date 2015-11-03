try:
    import xml.etree.cElementTree as ET
except ImportError:
    import xml.etree.ElementTree as ET

import csv


items = {}


tree = ET.ElementTree(file='C:/Users/P/AppData/Roaming/NCSOFT/WildStar/AddonSaveData/pau4b6a151b/Entity/ItemExport_0_Rlm.xml')

for elem in tree.iterfind('N[@K="items"]/N'):
    itemId = elem.attrib['F']
    itemName = elem.find('./N[@K="name"]').attrib['V']
    itemCommodityBuy = elem.find('./N[@K="commodityBuy"]').attrib['V']
    itemCommoditySell = elem.find('./N[@K="commoditySell"]').attrib['V']
    itemVendorBuy = elem.find('./N[@K="vendorBuy"]').attrib['V']
    itemVendorSell = elem.find('./N[@K="vendorSell"]').attrib['V']

    items[itemId] = {
        'itemId':           itemId,
        'name':             itemName,
        'commodityBuy':     itemCommodityBuy,
        'commoditySell':    itemCommoditySell,
        'vendorBuy':        itemVendorBuy,
        'vendorSell':       itemVendorSell,
    }


with open('itemexport.csv', 'w', newline='') as csvfile:
    csvwriter = csv.DictWriter(csvfile, [
        'name',
        'itemId',
        'commodityBuy',
        'commoditySell',
        'vendorBuy',
        'vendorSell',
    ])
    csvwriter.writeheader()
    csvwriter.writerows(items.values())
