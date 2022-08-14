import os
import sys, errno
import time
import threading
import requests
import xml.dom.minidom
from requests.adapters import HTTPAdapter

# Constant
program_timeout = 60
timeout_errno = 100

# Definition
# whole program timeout
def timeout_handler():
    #print(time.strftime('%Y-%m-%d %H:%M:%S'))
    print("@prettyXML.py [timeout_handler]: connection timeout")
    os._exit(timeout_errno)

url = sys.argv[1]
s = requests.Session()
s.mount('http://', HTTPAdapter(max_retries=3))
s.mount('https://', HTTPAdapter(max_retries=3))

# Start timer for whole program
t = threading.Timer(program_timeout, timeout_handler)
t.start()

try:
    
    resp = s.get(url, timeout=(5, 10))                  # get RSS response
    dom = xml.dom.minidom.parseString(resp.content)     # formatting XML
    print(dom.toprettyxml())
    os._exit(0)

# request timeout
except requests.exceptions.RequestException as e:
    #print(time.strftime('%Y-%m-%d %H:%M:%S'))
    print("@" + str(e))
    os._exit(timeout_errno)

except IOError as e:
    print(123)