# Design and Development of a System for Biofeedback Experiments

## Overview
This thesis describes the design and development of a low-cost, embedded system for biofeedback experiments. The system measures physiological parameters — heart rate and galvanic skin response (GSR) — using sensors connected to an Arduino Nano 33 BLE Sense board paired with a rechargeable battery module, making it fully stand-alone.

Collected data is transmitted in real time via Bluetooth Low Energy (BLE) to a custom mobile application built with the [Flutter](https://flutter.dev/) framework using the Dart programming language. The app displays live charts of the measured signals and periodically uploads data via HTTP to the [Measurify](https://github.com/measurify/measurify.github.io) IoT cloud framework, developed by the Elios Lab at the University of Genova, where it can be stored and further processed.

## Hardware

The main components:

- **Microcontroller** — [Arduino Nano 33 BLE Sense](https://docs.arduino.cc/hardware/nano-33-ble-sense)
- **Battery module** — LIR2450 Li-Ion rechargeable cell (3.6V), soldered onto the back of the board by Elios Lab
- **Heart rate sensor** — [Pulse Sensor](https://pulsesensor.com/)
- **Skin conductance sensor** — [Grove GSR Sensor](https://files.seeedstudio.com/wiki/Grove-GSR_Sensor/res/Grove-GSR_Sensor_WiKi.pdf)


The complete wiring diagram is shown below:

```
GSR SENSOR  ──► A2
PULSE SENSOR ──► A0
Both sensors ──► GND, +3.3V
```

The assembled device is housed in a repurposed pill box with cutouts for the board, the GSR chip, a reset button access hole, and cable pass-throughs. The lid allows battery replacement and system power control.

## Software

### Firmware (Arduino)

The firmware is developed in the [Arduino IDE](https://docs.arduino.cc/software/ide/) and follows a modular structure using header (`.h`) and source (`.cpp`) files. A central configuration file (`config.h`) controls which modules are compiled:


**Pulse Sensor** — reads the PPG signal from pin A0 using the `PulseSensorPlayground` library. The firmware detects beats, reads BPM estimates, and timestamps each beat. An adaptive threshold was implemented after testing to accommodate inter-individual variation.

**GSR Sensor** — reads 20 samples and averages them to reduce noise. Skin resistance is calculated using the formula from the sensor datasheet and converted to conductance (µS). A median filter removes outliers, and the signal is decomposed into:
- *Tonic component* (SCL) — slow baseline, computed via a first-order IIR low-pass filter
- *Phasic component* (SCR) — fast transient responses, obtained by subtracting the tonic from the raw signal

**Heart Rate Variability (HRV)** — computed from RR intervals using three time-domain metrics:
- `SDRR` — Standard Deviation of RR Intervals (ms)
- `RMSSD` — Root Mean Square of Successive RR Differences (ms)
- `pNN50` — percentage of successive RR intervals differing by more than 50 ms

**BLE** — the Arduino acts as a BLE *peripheral*, advertising a `Biofeedback-BLE Service` with characteristics for each measured signal (Pulse Sensor, BPM, GSR, Tonic, Phasic, SDRR, RMSSD, pNN50) and a `CTRL` characteristic. Data sharing is triggered by the mobile app writing `0x01` to `CTRL` (streaming mode) and stopped with `0x02` (idle mode). Updates are rate-limited per characteristic using a macro-defined interval.

### Mobile Application (Flutter)

The application is developed in [Visual Studio Code](https://code.visualstudio.com/) using [Flutter](https://flutter.dev/) and Dart, and is built on top of the [smart-collector](https://github.com/measurify/smart-collector) app developed by Elios Lab, extended with the following new pages:

| Page | Description |
|---|---|
| `main.dart` | Entry point; requests permissions and initiates BLE scanning |
| `default.dart` | Default parameters (auth tokens, service/characteristic UUIDs) |
| `globals.dart` | Global state and connection settings |
| `configPage.dart` | In-app settings editor |
| `PeripheralDetailPage.dart` | Connect/disconnect from selected device |
| `startPage.dart` | Browse BLE services and characteristics; start/stop data streaming; send data to Measurify |
| `SelectedCharacteristicsPage.dart` | Ordered list of characteristics selected for charting |
| `chartCartesianPage.dart` | Real-time scrolling chart (300-point window); landscape/portrait toggle; pause/resume |

BLE connectivity uses the cross-platform [Quick Blue](https://github.com/woodemi/quick_blue) plugin. Data is sent to Measurify in configurable batches via HTTP POST, with any remaining samples flushed on stop.

The Pulse Sensor chart displays the PPG waveform, current BPM (with animated heartbeat icon), and computed HRV metrics. The GSR chart overlays the raw conductance signal alongside its tonic and phasic components on a single graph.

### Measurify

[Measurify](https://github.com/measurify/measurify.github.io) is an open-source RESTful cloud API developed by Elios Lab, University of Genova, used to store and visualize IoT measurements.

Data is uploaded as a JSON array of timestamped samples:

```json
[
  { "timestamp": "1684833177652.00", "values": [0.1, -0.2] },
  { "timestamp": "1684833177752.00", "values": [0.7, -0.4] }
]
```

The `feature` is named `Biofeedback`, the `thing` is `User`, and the `device` is `DeviceA`. Sessions are authenticated with a token valid for 30 minutes.
## Quick Start

### 1. Set up the hardware

- Solder Dupont cables to the Arduino Nano 33 BLE Sense pins: **A0**, **A2**, **GND**, **+3.3V**
- Connect the Pulse Sensor cables (purple → A0, red → +3.3V, black → GND)
- Connect the GSR sensor cables (yellow → A2, red → +3.3V, black → GND)
- Insert the LIR2450 battery with the **+** pole facing outward
- House the assembled board in the enclosure and route cables through the provided openings

### 2. Flash the firmware

- Install the [Arduino IDE](https://docs.arduino.cc/software/ide/)
- Add the **Arduino Mbed OS Nano Boards** core via *Tools → Board → Boards Manager*
- Install the required libraries via *Sketch → Include Library → Manage Libraries*:
  - `ArduinoBLE`
  - `PulseSensorPlayground`
- Open `biofeedback_main.ino`, select the board (**Arduino Nano 33 BLE Sense**) and the correct port
- Click **Upload** and wait for *Done uploading*

### 3. Run the mobile application

- Install [Visual Studio Code](https://code.visualstudio.com/) with the Flutter and Dart plugins
- Install the [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Open the `smart-collector` project folder in VS Code
- Connect an Android device via USB and enable **Developer Mode** (Settings → About Phone → tap *Build Number* 7 times) and **USB Debugging**
- Select the device in the bottom-right of VS Code and run:
  ```bash
  flutter run
  ```

### 4. Collect data

1. Power on the Arduino (flip the switch on the battery module)
2. Open the app — ensure Bluetooth is enabled on the phone
3. Press **startScan** and select `Arduino-BIOFEEDBACK` from the list
4. On the *PeripheralDetailPage*, press **connect**, then **Go to services page**
5. On the *startPage*, select the characteristics of interest using the checkboxes
6. Press **Obtain all data** to begin streaming — the Arduino enters STREAMING mode
7. Press **Selected** to navigate to the chart list and tap any characteristic to view its live graph
8. Press **Stop collecting** to end the session — remaining data is flushed to Measurify

### 5. Visualize stored data

- Log in to the [Measurify](https://measurify.org/) dashboard with the credentials provided by Elios Lab
- Navigate to **Visualize Timeseries**, select the `Biofeedback` measurement, and choose the number of samples to display
- The pulse signal appears in blue and the GSR signal in red; each can be toggled independently

## Applying the sensors correctly

- **Pulse Sensor** — fix to the fingertip using the included Velcro strap; avoid overtightening (reduces blood flow) or too loose a fit (introduces noise)
- **GSR fingertip pads** — slide fully onto the fingers; positioning too close to the fingertip causes signal artefacts

## Future Improvements

- Add Machine Learning models on the Measurify cloud to automatically detect emotional states or stress patterns from stored data
- Implement Fast Fourier Transform (FFT) for frequency-domain HRV analysis
- Redesign the enclosure for a more compact and functional usage
- Enrich the mobile app with additional UI features and guidance for clinical or self-monitoring use
