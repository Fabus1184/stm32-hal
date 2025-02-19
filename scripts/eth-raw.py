import socket
import struct
from scapy.all import Ether, IP, ICMP, raw, sendp

def send_icmp_ping(interface, dest_mac, src_mac, src_ip, dest_ip):
    # Create the ICMP packet
    packet = Ether(dst=dest_mac, src=src_mac) / IP(src=src_ip, dst=dest_ip) / ICMP()

    # Send the packet
    sendp(packet, iface=interface)
    

# Example usage
send_icmp_ping(
    interface="enp34s0",
    dest_mac="69:69:69:69:69:69",
    src_mac="aa:bb:cc:dd:ee:ff",
    src_ip="1.2.3.4",  # Replace with your source IP
    dest_ip="5.6.7.8"    # Replace with your target IP
)
