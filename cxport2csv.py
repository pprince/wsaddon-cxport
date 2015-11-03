#! python3


# If there is no data for a field (e.g., vendorSell field for an item that
# cannot be purchased from a vendor), we'll pass this value to the CSV writer.
# ... possible alternatives: 0, or None
BLANK_VALUE  = ""


SAVE_FMT_VERSION = 44


import os
import csv
import ctypes.wintypes
from pathlib import Path
from operator import itemgetter
import xml.etree.ElementTree as ET


columns = [
    'category1',    # Top-level categorization ("Family")
    'category2',    # Mid-level categorization ("Category")
    'category3',    # Low-level categorization ("Type")

    'itemId',       # In-game item ID number (decimal)
    'itemName',     # Item's name (string)

    'itemLink',     # Chatlink code, to link to the item in-game
                    #   (basically the itemId, although in hexidecimal)

    'cxSellOrders', # Total number of this item listed for sale on the CX
    'cxSellTop1',   # Lowest price you can 'BuyNow' the item for.
    'cxSellTop10',  #   ..
    'cxSellTop50',  #   ..

    'cxBuyOrders',  # Maximum qty of an item that you could 'Sell Now'
    'cxBuyTop1',    # Highest price currently offerred if you 'Sell Now'
    'cxBuyTop10',   #   ..
    'cxBuyTop50',   #   ..

    'vendorSell',   # The price vendor sell this item for; i.e.,
                    #   how much it costs you to buy it from a vendor.
    'vendorBuy',    # The price vendors buy this item for; i.e.,
                    #   how much you get if you sell this item to a vendor.
]


def find_and_dispatch_input_files():

    addonsavedata = Path(os.environ['APPDATA'], 'NCSOFT', 'WildStar', 'AddonSaveData')

    if addonsavedata.exists() and addonsavedata.is_dir():
        print("Found AddonSaveData folder:\n    " + str(addonsavedata) + "\n")
    else:
        raise RuntimeError("AddonSaveData path does not exist or is not a directory: " + addonsavedata)

    xml_files = {}
    for xml_file in addonsavedata.glob('*/*/CXport_0_Rlm.xml'):
        realm = xml_file.parent.name
        account = xml_file.parent.parent.name
        print(" ...found data for realm:  %-16s  (acct: %s)" % (realm, account))
        if realm in xml_files:
            if xml_file.stat().st_mtime > xml_files[realm].stat().st_mtime:
                print("    ... this one is newer, it's the new cantidate.")
                xml_files[realm] = xml_file
            else:
                print("    ... but it's older than cantidate; ignoring.")
        else:
            print("    ... it's a new cantidate to be converted.")
            xml_files[realm] = xml_file

    print("")
    print("Files to convert:")
    outputdir = find_output_folder()
    for realm in xml_files.keys():
        print("  - %-16s\n    %s" % (realm, str(xml_files[realm])))
        convert_file(xml_files[realm], outputdir.joinpath(realm + '.csv'))



def find_output_folder():
    # Recipie for finding user's Documents folder location, from
    # http://stackoverflow.com/questions/3858851/python-get-windows-special-folders-for-currently-logged-in-user/3859336#3859336
    CSIDL_PERSONAL = 5       # My Documents
    SHGFP_TYPE_CURRENT = 0   # Want current, not default value
    buf= ctypes.create_unicode_buffer(ctypes.wintypes.MAX_PATH)
    ctypes.windll.shell32.SHGetFolderPathW(0, CSIDL_PERSONAL, 0, SHGFP_TYPE_CURRENT, buf)

    mydocsdir = Path(buf.value, 'NCSOFT', 'WildStar')
    if not (mydocsdir.exists() and mydocsdir.is_dir()):
        raise RuntimeError("Unable to locate the default output location; specify manually.")
    outputdir = mydocsdir / 'CXport'

    if not outputdir.exists():
        outputdir.mkdir()

    return outputdir



def convert_file(input_file, output_file):

    if isinstance(input_file, str):
        input_file = Path(input_file)
    if isinstance(output_file, str):
        output_file = Path(output_file)

    with input_file.open('r') as xml_file:

        tree = ET.parse(xml_file)

        savefmtversion = int(tree.find('./N[@K="savefmtversion"]').attrib['V'])
        if savefmtversion != SAVE_FMT_VERSION:
            raise RuntimeError("Version mismatch between Lua addon and Python script")

        realm = tree.find('./N[@K="realm"]').attrib['V']
        timestamp = tree.find('./N[@K="timestamp"]').attrib['V']

        print("")
        print("Converting CX data...")
        print("")
        print("    %-16s  @ %s" % (realm, timestamp))

        items = []

        for elem in tree.iterfind('N[@K="items"]/N'):

            itemId = int(elem.attrib['F'])
            item = {
                'itemId': itemId,
                'itemLink': '<i%x>' % itemId,
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


        items.sort(key=itemgetter('category1', 'category2', 'category3', 'itemId'))


    with output_file.open('w', newline='') as csvfile:
        csvwriter = csv.DictWriter(csvfile, columns)
        csvwriter.writeheader()
        csvwriter.writerows(items)


find_and_dispatch_input_files()
