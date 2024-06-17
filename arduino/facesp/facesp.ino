#include <WiFi.h>
#include <MQTT.h>
#include <SPI.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>


// -------------------------------------------
// Configuration
// -------------------------------------------
// WIFI
const char WIFI_SSID[] = "YOUR_WIFI_SSID";
const char WIFI_PASS[] = "YOUR_WIFI_PASSWORD";

// MQTT
const char MQTT_HOST[] = "YOUR_MQTT_HOST";
const int MQTT_PORT = 4040;
const char MQTT_USER[] = "facesp";
const char MQTT_PASSWORD[] = "facesp_MQTT_passwd_should_be_replaced!";
// -------------------------------------------
// End configuration
// -------------------------------------------


// identifier needs to be unique in case multiple devices connect at the same time
// generated in setup
char MQTT_IDENTIFIER[16];

#define SCREEN_WIDTH 128 // OLED display width, in pixels
#define SCREEN_HEIGHT 64 // OLED display height, in pixels
#define OLED_RESET -1    // Reset pin # (or -1 if sharing Arduino reset pin)
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

String _frame = "";
unsigned long _no_frame_loops = 0;
String _dots_progress = ".";

WiFiClient net;
MQTTClient client(10000);

/**
 * Initialize display
*/
void init_display()
{
  // SSD1306_SWITCHCAPVCC = generate display voltage from 3.3V internally
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C))
  { // Address 0x3D for 128x64
    Serial.println(F("SSD1306 allocation failed"));
    for (;;)
      ; // Don't proceed, loop forever
  }

  display.clearDisplay();
  display.setCursor(0, 0); // Start at top-left corner
  display.setTextSize(1);  // Draw 2X-scale text
  display.setTextColor(SSD1306_WHITE);
}

/**
 * Connect to WIFI
*/
void connect_wifi()
{
  WiFi.begin(WIFI_SSID, WIFI_PASS);

  while (WiFi.status() != WL_CONNECTED)
  {
    display_text_dots("Connecting to WIFI");
    delay(1000);
  }
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());
}

/**
 * Connect to MQTT server
*/
void connect_mqtt()
{
  while (!client.connect(MQTT_IDENTIFIER, MQTT_USER, MQTT_PASSWORD))
  {
    display_text_dots("Connecting to MQTT");
    Serial.print("Failed to connect to MQTT broker. State: ");
    Serial.print(client.lastError());
    delay(1000);
  }
  client.subscribe("facesp");
}

/**
 * MQTT message received callback
*/
void mqtt_message_received(String &topic, String &payload)
{
  // the payload received is our actual frame (will be rebuilt properly on draw)
  _frame = payload;
}

/**
 * Draw the current frame to display
*/
void draw_frame()
{
  char c;
  int k = 0;
  String temp_bl = "";  // temp buffer length
  while (true)
  {
    c = _frame[k];
    if (c == '|')
      break;
    k += 1;
    temp_bl += c;
  }
  int buffer_length = temp_bl.toInt();

  // create image array
  // ------------------------------------
  uint8_t img[buffer_length];
  int i = 0;
  int index = 0;
  String temp = "";
  while (true)
  {
    char c = _frame[i];
    if (c == '\n')
    {
      if (temp == "")
        break;
      // we still have a number, add it too, if we don't have too many yet
      if (index < buffer_length)
      {
        img[index] = temp.toInt();
        temp = "";
        index += 1;
      }
      break;
    }

    // check for space (end of number)
    if (c == ' ')
    {
      // we still have a number, add it too, if we don'  t have too many yet
      if (index < buffer_length)
      {
        img[index] = temp.toInt();
        temp = "";
        index += 1;
      }
    }
    temp += c;
    i += 1;
  }

  display.clearDisplay();
  display.drawBitmap(0, 0, img, 128, 64, 1);
  display.display();
}

/**
 * Show a `fresh` (clear display, move cursor to beginning) text in display
 * Print to Serial too
*/
void display_text(String line1, String line2 = "")
{
  display.clearDisplay();
  display.setCursor(0, 0); // Start at top-left corner
  display.println(line1);
  Serial.println(line1);
  if (line2 != "") {
    display.println();
    display.println(line2);
    Serial.println(line2);
  }
  display.display();
}

/**
 * Helper method to increase dots for nicer and `responsive` display
 * .
 * ..
 * ...
*/
void display_text_dots(String text)
{
  switch (_dots_progress.length()) {
    case 1:
      _dots_progress = "..";
      break;
    case 2:
      _dots_progress = "...";
      break;
    default:
      _dots_progress = ".";
      break;
  }
  // add dots to the input text
  text.concat(_dots_progress);
  // print to display
  display_text(text);
}

void setup()
{
  Serial.begin(115200);

  init_display();
  display_text("facesp started");
  delay(1000);

  connect_wifi();
  display_text("WIFI connected!");
  delay(1000);

  // generate identifier for MQTT
  randomSeed(analogRead(0)); // Initialize random number generator
  snprintf(MQTT_IDENTIFIER, sizeof(MQTT_IDENTIFIER), "facesp_%d", random(1, 1000));
  Serial.print("MQTT identifier: ");
  Serial.println(MQTT_IDENTIFIER);

  client.begin(MQTT_HOST, MQTT_PORT, net);
  client.setKeepAlive(60); // Set keep-alive to 60 seconds
  client.onMessage(mqtt_message_received);

  connect_mqtt();
  display_text("MQTT connected!");
  delay(1000);
  display_text("Waiting for frames...");
}

void loop()
{
  client.loop();
  delay(10);

  // if MQTT got disconnected, reconnect
  if (!client.connected())
  {
    connect_mqtt();
  }

  // if we have a frame, draw it
  if (_frame != "")
  {
    draw_frame();
    return;
  }
  
  // display a message after a while
  _no_frame_loops += 1;
  if (_no_frame_loops > 1000) {
    display_text("No frames received   yet", "Make sure the UI is  running");
  }
}
