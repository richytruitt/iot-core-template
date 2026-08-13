import network
import time
import ssl
from umqtt.simple import MQTTClient
import ntptime
import time



# =========================
# Configuration
# =========================

WIFI_SSID = "wifi-ssid"
WIFI_PASSWORD = "jwifi-password"
AWS_ENDPOINT = "aws-endpoint"
DEVICE_NAME = "device-name"


TOPIC = f"devices/{DEVICE_NAME}/telemetry".encode()


# =========================
# WiFi
# =========================

wifi = network.WLAN(network.STA_IF)
wifi.active(True)

print("Connecting to WiFi...")

wifi.connect(WIFI_SSID, WIFI_PASSWORD)

while not wifi.isconnected():
    time.sleep(1)

ntptime.settime()  # sync RTC before TLS context creation
print("Time synced:", time.localtime())

print("WiFi connected")
print("IP:", wifi.ifconfig()[0])


print("Loading TLS...")
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
ctx.verify_mode = ssl.CERT_REQUIRED

with open(f"/{DEVICE_NAME}/AmazonRootCA1.der", "rb") as f:
    ca_bytes = f.read()
ctx.load_verify_locations(cadata=ca_bytes)

with open(f"/{DEVICE_NAME}/device.der", "rb") as f:
    cert_bytes = f.read()
with open(f"/{DEVICE_NAME}/device-pkcs8.der", "rb") as f:
    key_bytes = f.read()
ctx.load_cert_chain(cert_bytes, key_bytes)

print("TLS loaded")


# =========================
# MQTT
# =========================

print("Connecting to AWS IoT...")

client = MQTTClient(
    client_id=DEVICE_NAME,
    server=AWS_ENDPOINT,
    port=8883,
    ssl=ctx
)

client.connect()

print("Connected to AWS IoT!")


# =========================
# Publish
# =========================

while True:

    message = b"Hello from pico-01!"

    client.publish(
        TOPIC,
        message
    )

    print("Published:", message)

    time.sleep(10)