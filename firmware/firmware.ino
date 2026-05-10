#include <Arduino.h>
#include <TinyGPS++.h>
#include <HardwareSerial.h>
#include <ArduinoJson.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEScan.h>
#include <BLEAdvertiser.h>
#include <set>
#include <queue>

// PIN CONFIGURATION
#define GPS_RX 16
#define GPS_TX 17
#define SOS_BUTTON_PIN 4

// CONSTANTS
const char* HIKER_ID = "hiker-001";
const int GPS_INTERVAL = 5000;
const int HEARTBEAT_INTERVAL = 30000;
const int SCAN_TIME = 2; // seconds

// GLOBALS
TinyGPSPlus gps;
HardwareSerial gpsSerial(2);
std::set<String> seenUuids;
unsigned long lastGpsMillis = 0;
unsigned long lastHbMillis = 0;

enum PacketType { GPS, HEARTBEAT, SOS };

struct Packet {
  String uuid;
  PacketType type;
  double lat;
  double lon;
  long timestamp;
  
  bool operator>(const Packet& other) const {
    return type > other.type; // Higher value enum = lower priority in min-heap
  }
};

std::priority_queue<Packet, std::vector<Packet>, std::greater<Packet>> packetQueue;

// FUNCTIONS
String generateUuid() {
  String uuid = "";
  for (int i = 0; i < 36; i++) {
    if (i == 8 || i == 13 || i == 18 || i == 23) {
      uuid += "-";
    } else {
      uuid += String(random(0, 16), HEX);
    }
  }
  return uuid;
}

void broadcastPacket(Packet p) {
  StaticJsonDocument<256> doc;
  doc["uuid"] = p.uuid;
  doc["hiker_id"] = HIKER_ID;
  doc["lat"] = p.lat;
  doc["lon"] = p.lon;
  doc["timestamp"] = p.timestamp;
  
  switch(p.type) {
    case SOS: doc["type"] = "sos"; break;
    case HEARTBEAT: doc["type"] = "heartbeat"; break;
    default: doc["type"] = "gps"; break;
  }

  String output;
  serializeJson(doc, output);
  
  BLEAdvertisementData advData;
  advData.setName("HikotNode");
  advData.setManufacturerData(output.c_str());
  
  BLEAdvertiser *pAdvertiser = BLEDevice::getBLEAdvertiser();
  pAdvertiser->setAdvertisementData(advData);
  pAdvertiser->start();
  delay(100);
  pAdvertiser->stop();
  
  Serial.println("Broadcasted: " + output);
}

class MyAdvertisedDeviceCallbacks: public BLEAdvertisedDeviceCallbacks {
    void onResult(BLEAdvertisedDevice advertisedDevice) {
      if (advertisedDevice.getName() == "HikotNode") {
        String data = advertisedDevice.getManufacturerData();
        StaticJsonDocument<256> doc;
        DeserializationError error = deserializeJson(doc, data);
        
        if (!error) {
          String uuid = doc["uuid"];
          if (seenUuids.find(uuid) == seenUuids.end()) {
            seenUuids.insert(uuid);
            Serial.println("New packet received, relaying: " + uuid);
            
            Packet p;
            p.uuid = uuid;
            p.lat = doc["lat"];
            p.lon = doc["lon"];
            p.timestamp = doc["timestamp"];
            String type = doc["type"];
            if (type == "sos") p.type = SOS;
            else if (type == "heartbeat") p.type = HEARTBEAT;
            else p.type = GPS;
            
            packetQueue.push(p);
          }
        }
      }
    }
};

void setup() {
  Serial.begin(115200);
  gpsSerial.begin(9600, SERIAL_8N1, GPS_RX, GPS_TX);
  pinMode(SOS_BUTTON_PIN, INPUT_PULLUP);
  
  BLEDevice::init("HikotNode");
  BLEScan* pBLEScan = BLEDevice::getScan();
  pBLEScan->setAdvertisedDeviceCallbacks(new MyAdvertisedDeviceCallbacks());
  pBLEScan->setActiveScan(true);
  
  Serial.println("Hikot IoT Firmware Started");
}

void loop() {
  // 1. Read GPS
  while (gpsSerial.available() > 0) {
    gps.encode(gpsSerial.read());
  }

  // 2. Handle SOS Button
  if (digitalRead(SOS_BUTTON_PIN) == LOW) {
    Packet p = {generateUuid(), SOS, gps.location.lat(), gps.location.lng(), (long)gps.time.value()};
    packetQueue.push(p);
    delay(500); // Debounce
  }

  // 3. Periodic Packets
  unsigned long currentMillis = millis();
  if (currentMillis - lastGpsMillis >= GPS_INTERVAL && gps.location.isValid()) {
    Packet p = {generateUuid(), GPS, gps.location.lat(), gps.location.lng(), (long)gps.time.value()};
    packetQueue.push(p);
    lastGpsMillis = currentMillis;
  }

  if (currentMillis - lastHbMillis >= HEARTBEAT_INTERVAL) {
    Packet p = {generateUuid(), HEARTBEAT, gps.location.lat(), gps.location.lng(), (long)gps.time.value()};
    packetQueue.push(p);
    lastHbMillis = currentMillis;
  }

  // 4. Process Queue (Broadcast highest priority)
  if (!packetQueue.empty()) {
    Packet p = packetQueue.top();
    packetQueue.pop();
    broadcastPacket(p);
  }

  // 5. Scan for neighbors
  BLEDevice::getScan()->start(SCAN_TIME, false);
}
