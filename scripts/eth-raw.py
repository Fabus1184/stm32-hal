import socket
import struct
from scapy.all import Ether, IP, ICMP, raw, sendp

def send_icmp_raw(interface, dest_mac, src_mac, src_ip, dest_ip):
    # Construct ICMP Echo Request packet
    icmp_packet = ICMP(type=8) / b'Raw ICMP Data'

    # Construct IP packet
    ip_packet = IP(src=src_ip, dst=dest_ip) / icmp_packet

    # Construct Ethernet frame
    eth_frame = Ether(src=src_mac, dst=dest_mac, type=0x0800) / ip_packet

    # Send the packet over the raw socket
    sendp(eth_frame, iface=interface, verbose=False)
    print(f"Sent ICMP Echo Request from {src_ip} to {dest_ip} via {interface}")

# Example usage
send_icmp_raw(
    interface="enp34s0",
    dest_mac="69:69:69:69:69:69",
    src_mac="aa:bb:cc:dd:ee:ff",
    src_ip="1.2.3.4",  # Replace with your source IP
    dest_ip="5.6.7.8"    # Replace with your target IP
)
