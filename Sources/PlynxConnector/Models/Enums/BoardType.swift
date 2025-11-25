//
//  BoardType.swift
//  PlynxConnector
//
//  Hardware board types supported by Plynx.
//

import Foundation

/// Supported hardware board types.
public enum BoardType: String, Codable, Sendable, CaseIterable {
    case ESP8266 = "ESP8266"
    case arduinoUno = "Arduino UNO"
    case nodeMCU = "NodeMCU"
    case raspberryPi3B = "Raspberry Pi 3 B"
    case wemosD1Mini = "WeMos D1 mini"
    case arduinoNano = "Arduino Nano"
    case arduinoMega = "Arduino Mega"
    case ESP32DevBoard = "ESP32 Dev Board"
    case wemosD1 = "WeMos D1"
    case genericBoard = "Generic Board"
    case raspberryPi2AB = "Raspberry Pi 2/A+/B+"
    case particlePhoton = "Particle Photon"
    case arduinoMKR1000 = "Arduino MKR1000"
    case arduino101 = "Arduino 101"
    case arduinoYun = "Arduino Yun"
    case raspberryPiABv2 = "Raspberry Pi A/B (Rev2)"
    case arduinoProMini = "Arduino Pro Mini"
    case arduinoLeonardo = "Arduino Leonardo"
    case raspberryPiBv1 = "Raspberry Pi B (Rev1)"
    case arduinoDue = "Arduino Due"
    case sparkFunBlynkBoard = "SparkFun Blynk Board"
    case orangePi = "Orange Pi"
    case bbcMicrobit = "BBC Micro:bit"
    case arduinoMini = "Arduino Mini"
    case arduinoMicro = "Arduino Micro"
    case onionOmega = "Onion Omega"
    case arduinoProMicro = "Arduino Pro Micro"
    case particleCore = "Particle Core"
    case sparkFunESP8266Thing = "SparkFun ESP8266 Thing"
    case stm32f103cBluePill = "STM32F103C Blue Pill"
    case wiPy = "WiPy"
    case particleElectron = "Particle Electron"
    case arduinoZero = "Arduino Zero"
    case intelEdison = "Intel Edison"
    case teensy3 = "Teensy 3"
    case linkItONE = "LinkIt ONE"
    case nanoPi = "NanoPi"
    case lightBlueBean = "LightBlue Bean"
    case intelGalileo = "Intel Galileo"
    case redBearLabBLENano = "RedBearLab BLE Nano"
    case redBearDuo = "RedBear Duo"
    case tiCC3200LaunchXL = "TI CC3200-LaunchXL"
    case digistumpOak = "Digistump Oak"
    case seeedWioLink = "Seeed Wio Link"
    case tiTivaCConnected = "TI Tiva C Connected"
    case samsungARTIK5 = "Samsung ARTIK 5"
    case microduinoCoreUSB = "Microduino CoreUSB"
    case espruinoPico = "Espruino Pico"
    case tinyDuino = "TinyDuino"
    case microduinoCorePlus = "Microduino Core+"
    case chipKITUno32 = "chipKIT Uno32"
    case theAirBoard = "The AirBoard"
    case microduinoCore = "Microduino Core"
    case simblee = "Simblee"
    case leMakerBananaPro = "LeMaker Banana Pro"
    case wildfireV2 = "Wildfire v2"
    case lightBlueBeanPlus = "LightBlue Bean+"
    case sparkFunPhotonRedBoard = "SparkFun Photon RedBoard"
    case microduinoCoreRF = "Microduino CoreRF"
    case redBearLabCC3200Mini = "RedBearLab CC3200/Mini"
    case bluz = "Bluz"
    case leMakerGuitar = "LeMaker Guitar"
    case panStampEspOutput = "panStamp esp-output"
    case digistumpDigispark = "Digistump Digispark"
    case redBearLabBlendMicro = "RedBearLab Blend Micro"
    case tiLM4F120LaunchPad = "TI LM4F120 LaunchPad"
    case wildfireV3 = "Wildfire v3"
    case wildfireV4 = "Wildfire v4"
    case konektDashPro = "Konekt Dash Pro"
    
    /// Default board type for unknown values
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let label = try container.decode(String.self)
        self = BoardType.allCases.first { $0.rawValue == label } ?? .genericBoard
    }
}
