# This lambda function convert AWS VPC Flow Logs to IPFIX format and stream it to a TCP listener
import json
import os
import socket
import base64

def lambda_handler(event, context):
    ipfixHost = os.environ['IPFIX_HOST']
    ipfixPort = os.environ['IPFIX_PORT']

    # decoded the base64 enconded awslogs.data field and decode it into ASCII
    message = base64.b64decode(event['awslogs']['data']).decode("ascii")
    messageSplit = message.split()

    # rearranage the fields from the VPC's log format to IPFIX format, setting the <- bytes/packets to 0, the application "unknown"
    # and the exporter IP to the IP configured above
    ipfixFormat = ""
    ipfixFormat = ipfixFormat + messageSplit[3] + ","
    ipfixFormat = ipfixFormat + messageSplit[5] + ","
    ipfixFormat = ipfixFormat + messageSplit[4] + ","
    ipfixFormat = ipfixFormat + messageSplit[6] + ","
    ipfixFormat = ipfixFormat + messageSplit[7] + ","
    ipfixFormat = ipfixFormat + messageSplit[8] + ","
    ipfixFormat = ipfixFormat + messageSplit[9] + ","
    ipfixFormat = ipfixFormat + "0" + ","
    ipfixFormat = ipfixFormat + "0" + ","
    ipfixFormat = ipfixFormat + messageSplit[10] + ","
    ipfixFormat = ipfixFormat + messageSplit[11] + ","
    ipfixFormat = ipfixFormat + "127.0.0.1" + ","
    ipfixFormat = ipfixFormat + "\"unknown\""
    
    streamData = ipfixFormat.encode('utf-8')
    # Create a TCP/IP socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    # Connect the socket to the port where the server is listening
    server_address = (ipfixHost, int(ipfixPort))
    sock.connect(server_address)

    try:
    
        # Send data
        sock.sendall(streamData)

        # Look for the response
        amount_received = 0
        amount_expected = len(streamData)
        
        while amount_received < amount_expected:
            data = sock.recv(16)
            amount_received += len(data)

    finally:
        sock.close()