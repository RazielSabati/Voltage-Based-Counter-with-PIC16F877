# Voltage-Based Counter with PIC16F877

This project is a simple assembly program for the PIC16F877 microcontroller that reads an input voltage via the Analog-to-Digital Converter (ADC) and controls a 7-segment display to show a cyclic counter. The counter increases or decreases based on the input voltage level.

## Features
- Monitors input voltage via ADC.
- Displays a cyclic counter that increments or decrements depending on voltage ranges.
- Uses Timer 1 to maintain a 1-second delay between counter updates.
- Displays "UP" or "DOWN" on an LCD based on the voltage range.

## Hardware Requirements
- **PIC16F877 Microcontroller**
- **LCD Display** (for showing "UP" or "DOWN")
- **ADC input** (for measuring the input voltage)
- **7-segment display or other output** (for showing the cyclic counter)
- **Power source** for the microcontroller and display

## Software Requirements
- MPLAB X IDE or compatible development environment
- MPLAB XC8 or compatible assembler for PIC16F877
- PICkit or other programmer/debugger for flashing the microcontroller

## Description of Operation
- The program starts by initializing the ADC to read voltage values on PORTA.
- Timer 1 is used for creating 1-second intervals to control the update rate of the counter.
- The input voltage is checked to determine whether the counter should increment or decrement.
- If the voltage is within a specific range, the counter is updated accordingly.
- The counter values are displayed on the 7-segment display, and "UP" or "DOWN" is printed on the LCD.

## How to Use
1. Flash the program to a PIC16F877 microcontroller.
2. Connect the required hardware (ADC input, LCD, etc.).
3. The system will start monitoring the input voltage and adjust the counter accordingly.
