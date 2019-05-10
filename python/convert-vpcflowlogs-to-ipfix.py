# This lambda function convert AWS VPC Flow Logs to IPFIX format and stream it to a TCP listener
import json
import os
import socket
import base64
import logging
import gzip
import json

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    ipfixHost = os.environ['IPFIX_HOST']
    ipfixPort = os.environ['IPFIX_PORT']

    logger.info(f"### Raw Event: {event}")
    # decoded the base64 enconded awslogs.data field and decode it into ASCII
    payload = gzip.decompress(base64.b64decode(
        event['awslogs']['data'])).decode("ascii")
    payload = json.loads(payload)
    logger.info(f"### Decoded Event: {payload}")
    events = payload['logEvents']
    if len(events) > 0:
        # Create a TCP/IP socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

        # Connect the socket to the port where the server is listening
        server_address = (ipfixHost, int(ipfixPort))
        logger.info(
            f"### Opening Client Connection to {ipfixHost}:{ipfixPort} ###")
        sock.connect(server_address)

        try:

            for event in events:
                ipfixFormat = ""
                ipfixFormat = ipfixFormat + \
                    event['extractedFields']['srcaddr'] + ","
                ipfixFormat = ipfixFormat + \
                    event['extractedFields']['srcport'] + ","
                ipfixFormat = ipfixFormat + \
                    event['extractedFields']['dstaddr'] + ","
                ipfixFormat = ipfixFormat + \
                    event['extractedFields']['dstport'] + ","
                ipfixFormat = ipfixFormat + \
                    event['extractedFields']['protocol'] + ","
                ipfixFormat = ipfixFormat + \
                    event['extractedFields']['packets'] + ","
                ipfixFormat = ipfixFormat + \
                    event['extractedFields']['bytes'] + ","
                ipfixFormat = ipfixFormat + "0" + ","
                ipfixFormat = ipfixFormat + "0" + ","
                ipfixFormat = ipfixFormat + \
                    event['extractedFields']['start'] + ","
                ipfixFormat = ipfixFormat + \
                    event['extractedFields']['end'] + ","
                ipfixFormat = ipfixFormat + \
                    event['extractedFields']['interface_id'] + ","
                ipfixFormat = ipfixFormat + "\"unknown\"" + "\n"

                streamData = ipfixFormat.encode('utf-8')
                logger.info(f"### Sending {len(streamData)} bytes ###")
                sock.sendall(streamData)

        finally:
            logger.info("### Closing Socket ###")
            sock.close()

    else:
        logger.info("No event found in payload")
