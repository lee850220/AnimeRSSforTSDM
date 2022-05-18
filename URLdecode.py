import sys
import html

url = sys.argv[1]
print(html.unescape(url))