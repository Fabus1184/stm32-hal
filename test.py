import socket
import struct

def send_raw_ethernet_frame(interface, dest_mac, payload):
    # Convert MAC address from string format to binary
    dest_mac_bytes = bytes.fromhex(dest_mac.replace(":", ""))
    src_mac_bytes = b'\xaa\xbb\xcc\xdd\xee\xff'  # Replace with your source MAC
    ethertype = b'\x08\x00'  # Example Ethertype (0x0800 for IPv4)

    # Construct Ethernet frame
    frame = dest_mac_bytes + src_mac_bytes + ethertype + payload

    # Create a raw socket
    s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW)
    s.bind((interface, 0))

    # Send the frame
    s.send(frame)
    s.close()
    print(f"Sent raw frame to {dest_mac} via {interface}")

send_raw_ethernet_frame("enp34s0", "69:69:69:69:69:69", b'Hello, Ethernet!')
