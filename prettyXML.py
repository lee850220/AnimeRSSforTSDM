import sys
import requests
import xml.dom.minidom

url = sys.argv[1]
try:
    resp = requests.get(url)
    dom = xml.dom.minidom.parseString(resp.content)
    print(dom.toprettyxml())
    
except requests.RequestException as err:
    print("@" + str(err))
