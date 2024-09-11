---
layout: post
title: Hodgepodge of ARM
date: 2024-09-10 19:55 +0800
author: sfeng
categories: [Blogging, ARM]
tags: [arm]
lang: zh
---

## Preface
&emsp;&emsp;这篇来个ARM的大杂烩吧，主要是把收集到的一些和ARM相关的知识和信息做个汇总，以备查阅。发现Arm官网真是个宝藏，内容多的很可能穷尽职业生涯也学不完，只取所需吧。  

## Content
### Path of ARM Evolution
&emsp;&emsp;先上一张官网关于ARM架构的图：  
![Desktop View](/assets/img/Arm_architecture_diagram.jpg){: .normal }

&emsp;&emsp;从ARMv8开始，ARM更新太快了，一年一更（见Reference里引用blog里的 announcement），以至于上面这张图显得太简略了。在网上又搜了几张图，其实也不算最新，索性一并放上来。  

![Desktop View](/assets/img/Arm_architecture_diagram_new.jpeg){: .normal }

![Desktop View](/assets/img/arm_cpu_list.jpeg){: .normal }

![Desktop View](/assets/img/cortex-A_path.jpeg){: .normal }

&emsp;&emsp;从上面的图片可以看出从ARMv7开始形成了Cortex-A、Cortex-R和Cortex-M系列的路线图。相比于R和M系列，A系列则更是紧跟ARM发展的脚步，每一代的新技术都会有代表芯片出炉。  

### ARM Family
&emsp;&emsp;除了常用的A、R、M系列（咦，恰巧是ARM，然而它是Advanced RISC Machines的缩写），还有X和Neoverse系列等等。X系列其实还是A系列的衍生，N主要用于服务器端，我们做embeded system的目前没接触过，总体还是以A、R、M三个系列为主。  

> Cortex-A Series: These processors are designed for high-performance applications, such as smartphones, tablets, and laptops. They are known for their powerful processing capabilities and are often used in conjunction with GPUs for graphics-intensive tasks.
{: .prompt-info }

> Cortex-R Series: This series is tailored for real-time applications, such as automotive systems and industrial control. They offer a balance between performance and predictability, critical in safety-critical systems.
{: .prompt-info }

> Cortex-M Series: Designed for microcontroller and embedded applications, these processors are known for their energy efficiency and determinism. They are widely used in IoT devices, wearables, and other battery-powered gadgets.
{: .prompt-info }

> Cortex-X Series: Performance-First Design. Close collaboration with Arm enables program partners to influence products and achieve tangible improvements for market-specific use cases. Compatible with Arm Cortex-A CPUs for design flexibility and scalability with DynamIQ support for intelligent solutions.
{: .prompt-info }

> Neoverse: ARM's server-grade processors are part of the Neoverse family. They are designed to meet the demands of data centers and cloud computing, offering scalability and power efficiency.
{: .prompt-info }

## Reference
[**Arm Architectures and Processors blog**](https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog)  
[**Arm-M Profile Arch**](https://www.arm.com/architecture/cpu/m-profile)  
[**Arm-R Profile Arch**](https://www.arm.com/architecture/cpu/r-profile)  
[**ARMv8.1 overview**](https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog/posts/the-armv8-a-architecture-and-its-ongoing-development)  
[**Armv8.2 overview**](https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog/posts/armv8-a-architecture-evolution)  
[**Armv8.3-A overview**](https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog/posts/armv8-a-architecture-2016-additions)  
[**Armv8.4-A Introduction**](https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog/posts/introducing-2017s-extensions-to-the-arm-architecture)  
[**Armv8.5-A**](https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog/posts/arm-a-profile-architecture-2018-developments-armv85a)  
[**Armv8.6-A**](https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog/posts/arm-architecture-developments-armv8-6-a)  
[**Armv8.7-A**](https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog/posts/arm-a-profile-architecture-developments-2020)  
[**Armv8.8-A and Armv9.3-A**](https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog/posts/arm-a-profile-architecture-developments-2021)  
[**Armv8.9-A and Armv9.4-A**](https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog/posts/arm-a-profile-architecture-2022)  
[**Armv9.5-A**](https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog/posts/arm-a-profile-architecture-developments-2023)  

