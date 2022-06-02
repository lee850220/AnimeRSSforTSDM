import bencoding
from io import BytesIO
import binascii
import hashlib, sys

with open(sys.argv[1], "rb") as f:
    data = bencoding.bdecode(f.read())
info = data[b'info']
hashed_info = hashlib.sha1(bencoding.bencode(info)).hexdigest()
print(hashed_info)