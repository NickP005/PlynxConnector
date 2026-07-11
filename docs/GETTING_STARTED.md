# Getting started with Plynx

From a bare board to live data on your iPhone in about 15 minutes.

You need:

- An iPhone with [Plynx](https://apps.apple.com/us/app/plynx-diy-iot/id6756375448) installed (free)
- An ESP32, ESP8266 or Arduino with a network connection
- The Arduino IDE

## 1. Create your account and project

Open Plynx and register. The default server is the free public cloud, which is
fine to start with (you can move to your own server later, see below).

Create a project, add a widget (a Button is a good first one) and bind it to a
pin, for example virtual pin `V1`. Open the project settings to find your
device **auth token**: that string is how your board identifies itself.

## 2. Install the right library

This is the step where most people trip. Plynx boards use the **classic Blynk
library, version 0.6.1**. The version the Arduino Library Manager suggests
first (1.x and later) talks to a different cloud and will NOT work.

Install it manually:

1. Download [blynk-library 0.6.1](https://github.com/blynkkk/blynk-library/releases/tag/v0.6.1) (Source code zip)
2. Arduino IDE → Sketch → Include Library → Add .ZIP Library
3. Pick the downloaded zip

## 3. Flash the sketch

ESP32:

```cpp
#define BLYNK_PRINT Serial
#include <WiFi.h>
#include <BlynkSimpleEsp32.h>

char auth[] = "YOUR_AUTH_TOKEN";      // from the app, project settings
char ssid[] = "YOUR_WIFI";
char pass[] = "YOUR_WIFI_PASSWORD";

void setup() {
  Serial.begin(115200);
  Blynk.begin(auth, ssid, pass, "plynx.cc", 8080);
}

void loop() {
  Blynk.run();
}
```

ESP8266: same sketch, but include `<ESP8266WiFi.h>` and
`<BlynkSimpleEsp8266.h>` instead.

Flash it, open the Serial Monitor, and within a few seconds you should see
`Ready`. In the app, your device dot turns green.

## 4. Make it do something

React to the button you created on `V1`:

```cpp
BLYNK_WRITE(V1) {
  int state = param.asInt();          // 1 pressed, 0 released
  digitalWrite(LED_BUILTIN, state);
}
```

Send a sensor value to the phone every 5 seconds (add a Gauge or Value
widget on `V2` in the app):

```cpp
BlynkTimer timer;

void sendReading() {
  Blynk.virtualWrite(V2, analogRead(A0));
}

void setup() {
  // ...as above, then:
  timer.setInterval(5000L, sendReading);
}

void loop() {
  Blynk.run();
  timer.run();
}
```

That's the whole loop: widgets in the app talk to pins, your code reads and
writes those pins. Everything else (charts, sliders, RGB, terminal, Home
Screen widgets, Apple Watch) builds on this.

## Run your own server (optional)

The public cloud is convenient, but the server is a single open source jar you
can run on any Raspberry Pi:

```bash
java -jar server-0.41.18.jar -dataFolder ./data
```

Then in the app: login screen → server pill → add your host. Your boards
connect to port 8080, the app to 9443. Your data never leaves your network.

## Troubleshooting

- **Board prints `Connecting to...` forever**: wrong server or port, or the
  1.x library instead of 0.6.1. Check both.
- **`Invalid auth token`**: the token in the sketch doesn't match the one in
  the project settings. Copy it again.
- **Device connects but widgets don't move**: widget bound to the wrong pin
  type (virtual vs digital) or wrong pin number.
- Anything else: open an issue here or write to the developer through the App
  Store page. Real user reports have driven most releases so far.
