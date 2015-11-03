#! python3



# ========================================================================= #
# SETTINGS:
# =========
#
# Edit these parameters to match your environment:
#
input_file = 'C:/Users/P/AppData/Roaming/NCSOFT/WildStar/AddonSaveData/pau4b6a151b/Warhound/CXport_0_Rlm.xml'
output_file = 'C:/Users/P/Documents/WildStar/dev/wsaddon-cxport/OUTPUT/Warhound.csv'
BLANK_VALUE = ""
# ========================================================================= #








# ------------------------------------------------------------------------- #
# -------------------- Do not edit below this line. ----------------------- #
# ------------------------------------------------------------------------- #


import csv
from operator import itemgetter

try:
    import xml.etree.cElementTree as ET
except ImportError:
    import xml.etree.ElementTree as ET


SAVE_FMT_VERSION = 43

columns = [
    'categoryTop',
    'categoryMid',
    'categoryBot',
    'itemId',
    'name',
    'chatLink',
    'commoditySellOrderCount',
    'commoditySellTop1',
    'commoditySellTop10',
    'commoditySellTop50',
    'commodityBuyOrderCount',
    'commodityBuyTop1',
    'commodityBuyTop10',
    'commodityBuyTop50',
    'vendorSell',
    'vendorBuy',
]


tree = ET.ElementTree(file=input_file)

timestamp = tree.find('./N[@K="timestamp"]').attrib['V']
realm = tree.find('./N[@K="realm"]').attrib['V']
savefmtversion = int(tree.find('./N[@K="savefmtversion"]').attrib['V'])

if savefmtversion != SAVE_FMT_VERSION:
    raise RuntimeError("Version mismatch between Lua addon and Python script")


print("")
print("Converting CX data...")
print("")
print("    %-16s  @ %s" % (realm, timestamp))

items = []

for elem in tree.iterfind('N[@K="items"]/N'):

    itemId = int(elem.attrib['F'])

    item = {
        'itemId': itemId,
        'chatLink': '<i%x>' % itemId,
    }

    for column in columns:

        # Skip processing if this field has already been set.
        if column in item:
            continue

        tag = elem.find('./N[@K="' + column + '"]')
        if tag is not None:
            if tag.attrib['T'] == 'n':
                item[column] = int(tag.attrib['V'])
            else:
                item[column] = str(tag.attrib['V'])
        else:
            item[column] = BLANK_VALUE

    items.append(item)


items.sort(key=itemgetter('categoryTop', 'categoryMid', 'categoryBot', 'itemId'))


with open(output_file, 'w', newline='') as csvfile:
    csvwriter = csv.DictWriter(csvfile, columns)
    csvwriter.writeheader()
    csvwriter.writerows(items)
