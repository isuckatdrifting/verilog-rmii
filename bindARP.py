import os

os.system('echo Binding dev board mac to temp arp list...')
os.system('arp -s 192.168.3.123 00:00:5e:00:fa:ce')
os.system('echo Binded 192.168.3.123 to 00:00:5e:00:fa:ce')
