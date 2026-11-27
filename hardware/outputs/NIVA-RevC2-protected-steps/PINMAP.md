# NIVA pod Rev C.1: pin map (ESP32-C3-MINI-1)

Written 3 November 2026 from the netlist exported from `../NIVA-3D-engineering-prototype/electronics/NIVA-pod.kicad_sch` with `kicad-cli sch export netlist --format kicadxml` (KiCad 10.0.7). The Rev C.2 working copy uses the same pins and nets; only two land patterns and the board outline changed (see `CHANGELOG.md`).

**Status:** nothing on this board has been built, powered or measured. The pin map is what the schematic says, not what has been tested.

## 1. Every module pin

The module has 53 pads. Pads not listed in the GPIO table are power, ground or no-connect.

| Pads | Net | Notes |
|---|---|---|
| 1, 2, 11, 14, 36–53 | GND | 36–53 are the split thermal pad; each has its own via to the In1 plane (ELECTRICAL-REVIEW §6) |
| 3 | +3V3 | from U5 TLV75533; C2 22 µF + C3 100 nF at the pin |
| 4, 7, 9, 10, 15, 17, 24, 25, 28, 29, 32–35 | not connected | NC pads of the module footprint |

| Pad | GPIO (module pin name) | Net | Connected to | Function | Boot / strap notes |
|---|---|---|---|---|---|
| 12 | GPIO0 (ADC1_CH0, XTAL_32K_P) | I2C_SDA | U6 MAX17048 SDA (pin 8); R5 4.7 kΩ to +3V3 | fuel-gauge I²C data | No 32 kHz crystal is fitted, so the XTAL function is unused |
| 13 | GPIO1 (ADC1_CH1, XTAL_32K_N) | IMU_INT1 | U3 LSM6DSO32 INT1 (pin 4) | IMU interrupt (wake / data-ready) | as GPIO0 |
| 5 | GPIO2 (ADC1_CH2) | I2C_SCL | U6 SCL (pin 7); R4 4.7 kΩ to +3V3 | fuel-gauge I²C clock | strapping pin, must be high at reset: R4 holds it high (ELECTRICAL-REVIEW §3) |
| 6 | GPIO3 (ADC1_CH3) | BUTTON | SW1 KMR2 to GND; R6 10 kΩ to +3V3 | user button, active low | — |
| 18 | GPIO4 (ADC1_CH4) | SPI_SCK | U2 MCP3208 CLK (13); U3 SCL/SPC (13) | shared SPI clock | — |
| 19 | GPIO5 (ADC2_CH0) | SPI_MISO | U2 Dout (12); U3 SDO/SA0 (1) | shared SPI data in | — |
| 20 | GPIO6 | SPI_MOSI | U2 Din (11); U3 SDA/SDI (14) | shared SPI data out | — |
| 21 | GPIO7 | CS_ADC | U2 CS/SHDN (10) | ADC chip select | — |
| 16 | GPIO10 | CS_IMU | U3 CS (12) | IMU chip select | — |
| 22 | GPIO8 | BOOT8 | R2 10 kΩ to +3V3 only | spare (strap only) | strapping pin: must be high for UART download (ELECTRICAL-REVIEW §3) |
| 23 | GPIO9 | BOOT9 | R3 10 kΩ to +3V3; J3 pad 5 | boot-mode strap | the service jig pulls it low for download |
| 8 | EN (CHIP_PU) | CHIP_EN | R1 10 kΩ to +3V3, C1 1 µF to GND; J3 pad 2 | reset | RC delay τ = 10 kΩ × 1 µF = 10 ms (calculated) |
| 26 | GPIO18 (USB D−) | USB_DM | J3 pad 4 | USB Serial/JTAG, service pads only | no ESD protection: jig access only |
| 27 | GPIO19 (USB D+) | USB_DP | J3 pad 3 | USB Serial/JTAG, service pads only | as above |
| 30 | GPIO20 (U0RXD) | LED_R | R45 1 kΩ → D4 red LED → GND | status light, red, active high | input at boot, harmless |
| 31 | GPIO21 (U0TXD) | LED_G | R46 680 Ω → D5 yellow-green LED → GND | status light, green, active high | the ROM boot log flickers this LED at reset (ELECTRICAL-REVIEW §3) |

All 15 GPIOs the module exposes (0–10, 18–21) are used. A new function needs an I/O expander or a freed pin.

## 2. What sits behind the SPI and I²C buses

**U2 MCP3208 (12-bit, 8 channels), CS = GPIO7.** VREF (pin 15) is VEXC, so every channel reads as a fraction of the insole excitation (ratiometric in hardware). ELECTRICAL-REVIEW §3 limits SCLK to about 1 MHz at 2.7 V, so switch the SPI clock per chip select.

| Channel (pin) | Net | Source | Insole region (flex P-number, from `hardware/work/build_niva_insole_flex.py` SENSORS) |
|---|---|---|---|
| CH0 (1) | F1_ADC | J1 pin 2, 10 kΩ divider + 3.3 kΩ/1 µF RC | P1 big toe |
| CH1 (2) | F2_ADC | J1 pin 3 | P2 medial forefoot |
| CH2 (3) | F3_ADC | J1 pin 4 | P3 lateral forefoot |
| CH3 (4) | F4_ADC | J1 pin 5 | P4 lateral midfoot |
| CH4 (5) | F5_ADC | J1 pin 6 | P5 heel |
| CH5 (6) | PIEZO_ADC | J1 pin 7 PVDF → 100 kΩ → MCP6001 follower → 1 kΩ/470 nF | heel PVDF film |
| CH6 (7) | V33_HALF | +3V3 / 2 (R31/R32), read against VREF = VEXC | tail-fault monitor: normal reading 2048–2299, a tail short drives it toward full scale (ELECTRICAL-REVIEW §4) |
| CH7 (8) | INSERT_ID | R30 10 kΩ from VEXC, ID resistor on the insert | insert ID: right medium 4.7 kΩ → code 1310, left medium 47 kΩ → 3378; open tail reads 4095 (ELECTRICAL-REVIEW §4) |

**U3 LSM6DSO32 (±32 g IMU) on SPI, CS = GPIO10, INT1 = GPIO1.** INT2, OCS_Aux and SDO_Aux are unconnected; SDx and SCx (sensor-hub pins) are tied to GND, which gives the one ERC warning.

**U6 MAX17048 fuel gauge on I²C, SDA = GPIO0, SCL = GPIO2.** It is powered from VBAT (CELL and VDD), with CTG and QSTRT to GND and ALRT unconnected, which the ADI datasheet allows (see `STATUS-CLOSURE.md` §2). Its 7-bit address is 0x36 according to Espressif's `max17048` component README (components.espressif.com/components/espressif/max17048); confirm it in the datasheet's I²C section before relying on it.

**Power:** VBAT reaches the board through J2 (pads 1–2 VBAT, 3–4 GND) from the cartridge. U5 TLV75533 has EN tied to VBAT, so the 3.3 V rail is always on while a cartridge is fitted. There is no charger and no USB port on the pod.

## 3. Porting from the classic-ESP32 prototype

The current prototype pins come from `startup/niva arduino/README.md` (both sketches) and `niva_protected_steps/ps_device.h` (read-only reference). The Rev C.1 pod has no OLED.

| Prototype signal | Prototype pin (classic ESP32) | Rev C.1 pod | Port note |
|---|---|---|---|
| FSR heel | GPIO32, internal ADC | MCP3208 CH4 (F5, P5 heel) over SPI | `analogRead` becomes an MCP3208 SPI read. Codes are ratiometric to VEXC; the prototype's divider is not the same circuit, so thresholds must be re-derived. |
| FSR inner | GPIO33 | CH1 (P2 medial forefoot) is the nearest by name | The positions are not the same; the mapping is by name only. |
| FSR outer | GPIO34 | CH2 (P3 lateral forefoot) is the nearest by name | as above |
| FSR toe | GPIO35 | CH0 (P1 big toe) | as above |
| (none) | — | CH3 (P4 lateral midfoot) | New fifth region. |
| Piezo | GPIO36, peak-hold at 500 Hz | CH5 via the MCP6001 buffer and a 339 Hz filter | The filter and sample rate are still open (ELECTRICAL-REVIEW §4, E3 test). |
| MPU6050 (I²C 0x68) | SDA 21 / SCL 22 | LSM6DSO32 on SPI, CS GPIO10, INT1 GPIO1 | New driver. The LSM6DSO32 accelerometer goes to ±32 g full scale (ST product title); the prototype MPU6050 is set to ±16 g (firmware README). |
| SH1106 OLED | SDA 21 / SCL 22 | none | Status shows on the two LEDs and in the app. |
| Status LED | GPIO2 | LED_R GPIO20, LED_G GPIO21 (both on = amber) | GPIO2 is now I2C_SCL. Do not drive it as an LED. |
| Button (BOOT) | GPIO0 (`PS_PIN_BUTTON`) | BUTTON GPIO3 | GPIO0 is now I2C_SDA. |
| Battery % | none (USB powered) | MAX17048 on GPIO0/GPIO2 | Feeds the `batt` field of PROTOCOL.md. |
| USB serial log | on-board USB-UART | USB Serial/JTAG on GPIO18/19, service pads J3 only | `Serial` maps to USB CDC on the C3; there is no USB socket on the pod. |
| Insole connected? | — | CH7 INSERT_ID (4095 = no tail) and CH6 (tail fault) | Lets the role check in `ROLE-DESIGN-NOTE.md` work. |

The ESP32-C3 has one core and no classic Bluetooth, and Arduino needs the ESP32-C3 board package. Check the partition size again, because BLE plus Wi-Fi already needed the "Huge APP" scheme on the classic ESP32.
