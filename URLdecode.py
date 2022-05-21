import sys
import html
from urllib.parse import unquote

url = sys.argv[1]
print(html.unescape(unquote(url)))