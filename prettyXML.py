import sys
import requests
import xml.dom.minidom
import xml.parsers.expat

url = sys.argv[1]
try:
    resp = requests.get(url)
    dom = xml.dom.minidom.parseString(resp.content)
    print(dom.toprettyxml())
    
except RequestException as err:
    print("@" + str(err))
except ExpatError as err:
    print("@" + str(err))
