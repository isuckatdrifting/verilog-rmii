import binascii

def crc2hex(crc):
    return '%08x' % (binascii.crc32(binascii.a2b_hex(crc)) & 0xffffffff)

data = "00005e00 facef076 1ca94d2e 08004500 004651f7 40004011 6096c0a8 0366c0a8 037bbda7 04d20032 00000000 01000080 64000081 14000082 02000083 01000084 19900185 19900186 00f0ff87 01000088 01000089"

print("-" * 50)
print("data to process: " + "\033[31m" + "Note that the Least significant Byte in a word comes first in CRC calculating" + "\033[0m")
print("-" * 50)
print(data)
print("-" * 50)
data_ = data.replace(" ","")
print("CRC32d4 result: " + "\033[4m" + crc2hex(data_) + "\033[0m")
