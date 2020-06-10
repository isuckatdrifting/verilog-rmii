import socket
import os

def main():
    data = "\x00\x00\x01\x00\x80\x64\x00\x81\x00\x00\x82\x00\x00\x83\x00\x00\x84\x00\x00\x85\x00\x00\x86\x00\x00\x87\x00\x00\x88\x00\x00\x89"
    # create a udp socket
    udp_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    # send data with the socket
    udp_socket.sendto(data.encode(), ("192.168.3.123", 1234))

    # close socket
    udp_socket.close()
	

if __name__ == "__main__":
    main()
