import binascii

def crc2hex(crc):
    return '%08x' % (binascii.crc32(binascii.a2b_hex(crc)) & 0xffffffff)

#data = "00005e00 facef076 1ca94d2e 08060001 08000604 00020f76 1ca94d2e 0ca80366 00005e00 face0ca8 037b0000 00000000 00000000 00000000 00000000"

data = "ffffffff fffff076 1ca94d2e 08060001 08000604 0001f076 1ca94d2e c0a80366 00000000 0000c0a8 037b0000 00000000 00000000 00000000 00000000"
print("-" * 50)
print("data to process: " + "\033[31m" + "Note that the Least significant Byte in a word comes first (Big Endian) in CRC calculating" + "\033[0m")
print("-" * 50)
print(data)
print("-" * 50)
data_ = data.replace(" ","")
print("CRC32d4 result: " + "\033[4m" + crc2hex(data_) + "\033[0m")
