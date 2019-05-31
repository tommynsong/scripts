import json
import os
import socket
import base64
import logging
import gzip

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    """Convert AWS's VPC Flow Log to IPFIX format"""
    ipfixHost = os.environ['IPFIX_HOST']
    ipfixPort = os.environ['IPFIX_PORT']
    ipfixProto = os.environ['IPFIX_PROTO']

    logger.info(f'### Raw Event: {event}')
    payload = gzip.decompress(base64.b64decode(
        event['awslogs']['data'])).decode("ascii")
    payload = json.loads(payload)
    logger.info(f'### Decoded Event: {payload}')
    events = payload['logEvents']
    if len(events) > 0:

        if ipfixProto.lower() == 'tcp':
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        elif ipfixProto.lower() == 'udp':
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        else:
            logging.error(
                f'### Unsupported protocol "{ipfixProto}"###'
            )
            return
        # Connect the socket to the port where the server is listening
        server_address = (ipfixHost, int(ipfixPort))
        logger.info(
            f'### Opening Client Connection to {ipfixHost}:{ipfixPort} ###')
        sock.connect(server_address)

        try:

            for event in events:
                ipfixFormat = ''
                ipfixFormat = ipfixFormat + \
                    event['extractedFields']['srcaddr'] + ','
                ipfixFormat = ipfixFormat + \
                    event['extractedFields']['srcport'] + ','
                ipfixFormat = ipfixFormat + \
                    event['extractedFields']['dstaddr'] + ','
                ipfixFormat = ipfixFormat + \
                    event['extractedFields']['dstport'] + ','
                ipfixFormat = ipfixFormat + \
                    event['extractedFields']['protocol'] + ','
                ipfixFormat = ipfixFormat + \
                    event['extractedFields']['packets'] + ','
                ipfixFormat = ipfixFormat + \
                    event['extractedFields']['bytes'] + ','
                ipfixFormat = ipfixFormat + '0' + ','
                ipfixFormat = ipfixFormat + '0' + ','
                ipfixFormat = ipfixFormat + \
                    event['extractedFields']['start'] + ','
                ipfixFormat = ipfixFormat + \
                    event['extractedFields']['end'] + ','
                ipfixFormat = ipfixFormat + \
                    event['extractedFields']['interface_id'] + ','
                ipfixFormat = ipfixFormat + "\"unknown\"" + "\n"

                streamData = ipfixFormat.encode('utf-8')
                logger.info(f'### Sending {len(streamData)} bytes ###')
                sock.sendall(streamData)

        finally:
            logger.info('### Closing Socket ###')
            sock.close()
            return

    else:
        logger.info('No event found in payload')
        return
