---
layout: post
title: JTAG Scan Chain
date: 2026-01-06 18:52 +0800
author: sfeng
categories: [JTAG Debugging Fundamentals]
tags: [JTAG]
lang: en
---

## Introduction

The Joint Test Action Group (JTAG) interface, standardized as **IEEE 1149.1**, is a fundamental technology for board-level testing, debugging, and in-system programming of integrated circuits. A key concept in JTAG-based systems is the **scan chain**, which defines how multiple JTAG-enabled devices are interconnected and accessed through a single Test Access Port (TAP).

As system complexity increases—with multiple processors, FPGAs, SoCs, and peripheral devices—the choice of JTAG scan chain architecture becomes an important design consideration. This blog introduces JTAG scan chain fundamentals and discusses two common architectures:

- Daisy Chain  
- Star (Switch) Chain  

A comparison is provided to highlight their respective advantages and trade-offs.

---

## JTAG Scan Chain Fundamentals

A standard JTAG interface consists of the following signals:

- **TCK** – Test Clock  
- **TMS** – Test Mode Select  
- **TDI** – Test Data In  
- **TDO** – Test Data Out  
- **TRST** (optional) – Test Reset  

Each JTAG-compliant device includes a **Test Access Port (TAP) controller** and a set of scan registers. By connecting devices together, a scan chain is formed that allows serial data to pass through all devices under test.

---

## Daisy Chain Architecture

### Overview

In a **daisy chain** configuration, all JTAG devices are connected serially. The TDI signal enters the first device, shifts through each device’s scan registers, and exits from the final device’s TDO.


   ![Desktop View](/assets/img/jtag/jtag-daisy-chain1.png){: .normal }


### Characteristics

- Single, continuous scan path
- All devices share TCK and TMS
- Total scan length is the sum of all device scan registers

### Advantages

- Simple implementation and routing
- No additional components required
- Broad tool compatibility

### Limitations

- Longer scan times as device count increases
- One faulty or unpowered device can block the chain
- Limited flexibility for isolating individual devices

---

## Star (Switch) Chain Architecture

### Overview

A **star chain**, also known as a **switch-based JTAG architecture**, uses a JTAG switch, hub, or multiplexer to selectively connect the JTAG master to individual devices or sub-chains.


   ![Desktop View](/assets/img/jtag/jtag-switch-chain.png){: .normal }


Only one device or branch is active at a given time.

### Characteristics

- Centralized JTAG control
- Devices are accessed independently
- Scan chain length is minimized per operation

### Advantages

- Faster test and programming times
- Improved fault isolation
- Greater flexibility for debugging
- Better scalability for complex systems

### Limitations

- Additional hardware increases cost
- More complex design and configuration
- Requires tool support for JTAG switching

---

## Daisy Chain vs. Star (Switch) Chain Comparison

| Aspect | Daisy Chain | Star / Switch Chain |
|------|------------|---------------------|
| Wiring Complexity | Low | Medium to High |
| BOM Cost | Low | Higher |
| Scan Length | Long | Short |
| Test Time | Longer | Shorter |
| Fault Isolation | Poor | Good |
| Scalability | Limited | High |
| Debug Flexibility | Low | High |
| Tool Complexity | Minimal | Moderate |

---

## Choosing the Right Architecture

- **Daisy Chain is suitable when:**
  - The number of JTAG devices is small
  - Simplicity and low cost are priorities
  - Test time is not critical

- **Star or Switch Chain is suitable when:**
  - There are many JTAG devices
  - Fast programming and testing are required
  - Fault isolation and independent access are important
  - The system is expected to scale

---

## Conclusion

The JTAG scan chain architecture has a direct impact on system testability, debug efficiency, and maintainability. Daisy chains offer simplicity and low cost, while star (switch) chains provide improved performance, scalability, and robustness for complex designs.

Selecting the appropriate architecture early in the design phase ensures effective use of JTAG throughout the product lifecycle.

---

## Reference
[**JTAG Switcher**](https://repo.lauterbach.com/projects_download/jtag_switcher/jswitch_doc_current.pdf)  
[**JTAG Testability**](https://www.ti.com/lit/an/ssya002c/ssya002c.pdf)  

