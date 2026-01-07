---
layout: post
title: JTAG Connector
date: 2026-01-06 19:20 +0800
author: sfeng
categories: [JTAG Debugging Fundamentals]
tags: [JTAG]
lang: en
---

## Preface

This part focuses on comparing **JTAG and SWD**, describing **standard connectors**, and highlighting **board-level design considerations** for reliable debugging.

---

## 1. JTAG vs SWD

## 1.1 JTAG (IEEE 1149.1)

JTAG is a **multi-wire debug and test interface** widely used on Cortex-A and complex SoCs.

**Key signals:**

* **TCK** – Test Clock
* **TMS** – Test Mode Select
* **TDI** – Test Data In
* **TDO** – Test Data Out
* **nTRST** – Optional TAP reset
* **nRESET** – System reset

**Characteristics:**

* Supports multi-device scan chains
* Enables boundary scan and manufacturing test
* Well-suited for multi-core and high-performance SoCs

### 1.2 SWD (Serial Wire Debug)

SWD is an ARM-specific **2-wire interface**, primarily for Cortex-M devices.

**Signals:**

* **SWCLK** – Clock
* **SWDIO** – Bidirectional data

**Characteristics:**

* Fewer pins, simpler routing, lower power
* Limited multi-core and Cortex-A support
* No boundary scan

### 1.3 Feature Comparison

| Feature                        | JTAG                      | SWD      |
| ------------------------------ | ------------------------- | -------- |
| Pin count                      | High                      | Low      |
| Multi-core support             | Excellent                 | Limited  |
| Boundary scan                  | Yes                       | No       |
| Cortex-A support               | Yes                       | Rare     |
| Cortex-M support               | Yes                       | Yes      |
| Debug speed                    | High                      | Moderate |
| Complex system debug           | Excellent                 | Limited  |
| Secure-world/TrustZone support | Yes (with proper adapter) | Rare     |

**CPU support and debug capabilities:**

* **Cortex-A/AArch64:** JTAG recommended, full debug including multi-core and secure world
* **Cortex-R:** JTAG preferred, SWD may be unsupported
* **Cortex-M:** SWD sufficient for most applications, JTAG optional for advanced features
* **Legacy ARM cores:** JTAG only, SWD unsupported

For complex SoCs, especially ARM Cortex-A, **JTAG is preferred**. For microcontrollers or space-constrained boards, SWD is often sufficient.

---

## 2. Standard Debug Connectors

### 2.1 ARM 20-Pin JTAG Connector (0.1")

Used on most Cortex-A boards for professional probes such as J-Link, DSTREAM, TRACE32.

**Official ARM 20-pin JTAG pinout (per Table D3-1, Arm CoreSight Architecture Spec):**

| Pin | Signal       | Pin | Signal |
| --- | ------------ | --- | ------ |
| 1   | VTREF        | 2   | NC     |
| 3   | nTRST        | 4   | GND    |
| 5   | TDI          | 6   | GND    |
| 7   | TMS/SWDIO    | 8   | GND    |
| 9   | TCK/SWCLK    | 10  | GND    |
| 11  | RTCK         | 12  | GND    |
| 13  | TDO/SWO      | 14  | GND    |
| 15  | nSRST        | 16  | GND    |
| 17  | DBGRQ/TRIGIN | 18  | GND    |
| 19  | DBGACK       | 20  | GND    |

**Notes:**

* VTREF (Pin 1) must match target voltage (1.8V–3.3V typical)
* Odd/even arrangement simplifies ribbon cable design
* DBGRQ/TRIGIN and DBGACK are optional for advanced debugging

### 2.2 SWD Connector

SWD usually uses a **10-pin 0.05" or 0.1" connector**, sometimes sharing pins with JTAG for flexible headers.

**Typical signals:**

* SWCLK
* SWDIO
* nRESET
* VTref
* GND

### 2.3 Connector Variations

Different adapters may use proprietary pinouts. Always verify with vendor documentation:

* J-Link: follows ARM standard 20-pin JTAG
* DSTREAM / TRACE32: ARM standard
* FTDI-based adapters: may have non-standard pin assignments

---

## 3. Board-Level Design Considerations

Reliable JTAG/SWD debugging depends on proper **PCB design** and signal routing.

### 3.1 Signal Integrity

* Keep TCK/TMS/TDI/TDO or SWCLK/SWDIO lines short and direct
* Use ground vias/pairs for return paths
* Minimize stubs and long traces to avoid reflections

### 3.2 Voltage Matching

* Adapter must detect and match VTref
* Avoid driving lines without VTref present

### 3.3 Reset and Pull-Ups

* nRESET and optional nTRST should have appropriate pull-ups/pull-downs
* Prevent accidental floating pins

### 3.4 Test Points and Headers

* Provide clear, accessible headers for debugging
* Include extra GND pins for stability
* Consider orientation and polarity markings

### 3.5 EMI and Crosstalk

* Keep debug traces away from high-speed signals
* Use differential routing if supported for trace signals
* Use decoupling capacitors near target device for clean reference

---

## 4. Summary

* **JTAG**: multi-wire, robust, suitable for Cortex-A and complex SoCs
* **SWD**: 2-wire, simpler, ideal for microcontrollers
* **Connectors**: follow official ARM 20-pin standard for JTAG; verify adapter pinout
* **Board design**: signal integrity, voltage matching, proper grounding, and test points are essential for reliable debugging
* **CPU support and debug capability** must guide interface choice

Proper interface selection and thoughtful board design are critical for **high-performance and stable debug operations**.

