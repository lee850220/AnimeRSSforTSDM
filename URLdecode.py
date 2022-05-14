import sys
from urllib.parse import unquote

url = sys.argv[1]
print(unquote(url))