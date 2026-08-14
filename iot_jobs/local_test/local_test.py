import ssl
import json
import time
import paho.mqtt.client as mqtt



DEVICE_NAME = "device name from json file"  # or a distinct name like "dev-machine-01" if this is a separate identity
AWS_ENDPOINT = "iot core endpoint"
TOPIC = f"devices/{DEVICE_NAME}/telemetry"

# uses the standard pem, key, and crt files that are included in the cert bundle. 
CA_PATH = f"../../credentials/{DEVICE_NAME}/AmazonRootCA1.pem"
CERT_PATH = f"../../credentials/{DEVICE_NAME}/device.crt"
KEY_PATH = f"../../credentials/{DEVICE_NAME}/device.key"

client = mqtt.Client(client_id=DEVICE_NAME, protocol=mqtt.MQTTv311)

client.tls_set(
    ca_certs=CA_PATH,
    certfile=CERT_PATH,
    keyfile=KEY_PATH,
    tls_version=ssl.PROTOCOL_TLS_CLIENT,
    cert_reqs=ssl.CERT_REQUIRED,
)

client.connect(AWS_ENDPOINT, port=8883)
client.loop_start()

while True:
    payload = json.dumps({
        "temperature": 92,
        "device": DEVICE_NAME
    })
    client.publish(TOPIC, payload)
    print("Published:", payload)
    time.sleep(10)