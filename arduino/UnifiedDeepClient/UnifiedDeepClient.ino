/*
    This sketch sends data via HTTP GET requests to data.sparkfun.com service.

    You need to get streamId and privateKey at data.sparkfun.com and paste them
    below. Or just customize this script to talk to other HTTP servers.

*/

#include <ESP8266WiFi.h>
#include <WiFiUdp.h>
#include <Wire.h>
#include <SPI.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BME280.h>
#include <Adafruit_Si7021.h>


ADC_MODE(ADC_VCC);


const char* ssid     = "GavWireless";
const char* password = "qazxswedcvfr";

const char remote_host[] = "192.168.135.255";
const int remote_port = 1234;
char local_host[16];

WiFiUDP Udp;
Adafruit_BME280 bme280;
bool bme280_avail;
Adafruit_Si7021 si7021;
bool si7021_avail;

void start_wifi() {
  // We start by connecting to a WiFi network
  Serial.println();
  Serial.println();
  Serial.print("Connecting to ");
  Serial.println(ssid);

  /* Explicitly set the ESP8266 to be a WiFi-client, otherwise, it by default,
     would try to act as both a client and an access-point and could cause
     network-issues with your other WiFi-devices on your WiFi-network. */
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {
    delay(2000);
    //Serial.print(".");
    Serial.print("Status: ");
    Serial.println(WiFi.status());
    WiFi.printDiag(Serial);
    Serial.println();
  }

  WiFi.localIP().toString().toCharArray(local_host, sizeof local_host);

  Serial.println("");
  Serial.println("WiFi connected");
  Serial.println("IP address: ");
  Serial.println(WiFi.localIP());
}

void start_sensors() {
  bme280_avail = bme280.begin();
  si7021_avail = si7021.begin();
}

void do_sensors() {
  float temp = NAN;
  float humidity = NAN;
  int batt = -1;
  int pressure = -1;
  
  batt = ESP.getVcc();

  if(bme280_avail) {
    Serial.println("BME280");
    
    float tempc = bme280.readTemperature();
    temp = (9.0/5.0) * tempc + 32.0;
    
    humidity = bme280.readHumidity();
    
    pressure = bme280.readPressure();
  }
  
  if(si7021_avail) {
    Serial.println("Si7021");
    
    float tempc = si7021.readTemperature();
    temp = (9.0/5.0) * tempc + 32.0;
    
    humidity = si7021.readHumidity();
  }

  char packet[1024];
  char* cursor = packet;
  sprintf(packet, "%s,%f,F,%f,%%RH,%d,mV,%d,Pa\n", local_host, temp, humidity, batt, pressure);

  cursor += sprintf(cursor, "%s,", local_host);
  if(!isnan(temp)) {
    cursor += sprintf(cursor, "%f", temp);
  }
  cursor += sprintf(cursor, ",F,");
  if(!isnan(humidity)) {
    cursor += sprintf(cursor, "%f", humidity);
  }
  cursor += sprintf(cursor, ",%%RH,%d,mV,", batt);
  if(pressure > 0) {
    cursor += sprintf(cursor, "%d", pressure);
  }
  cursor += sprintf(cursor, ",Pa\n");

  Udp.beginPacket(remote_host, remote_port);
  Udp.write(packet);
  Udp.endPacket();

  Serial.print(packet);
}

void setup() {
  Serial.begin(115200);
  delay(10);

  start_wifi();

  start_sensors();

  do_sensors();

  // Traditional sleep for 1 second to let the UDP send, then deep sleep for the rest of the minute
  delay(1000);
  ESP.deepSleep(59000000, WAKE_RF_DEFAULT);
}

void loop() {
  //do_sensors();
  //delay(60000);
}
