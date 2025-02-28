---
layout: post
title: Share Data Among Processors Without Cache Coherent
date: 2025-02-11 19:32 +0800
author: sfeng
categories: [Dev]
tags: [cache]
lang: zh
---

## Preface
&emsp;&emsp;在嵌入式开发中，经常可以碰到一个SoC中不同系统间进行data的share，正好有同事需要一个example，就用这篇文章做个总结。  

## Share Flow
&emsp;&emsp;这里提到在不同processor间贡献数据，一定是至少有一方有cache存在，并且share的双方不在一个cache coherent domain里。如果都没有cache，或者在一个cache domain里或者使用了例如SMMU之类的硬件做到了cache coherent，也不需要额外的操作保证一致性，直接读写数据就可以了。  
&emsp;&emsp;这里举个例子，在一个带cache的CPU A和没有cache的CPU B之间share data。  
- A share data to B  
  1. 首先要知道CPU A的cache line大小是多少，这点很重要，涉及到刷cache的操作是否正确；  
  2. A准备share data的buffer。这里要注意的是，该buffer的start address和size都要至少cache line size对齐；  
  3. A填充data到buffer里，然后对buffer做cache flush或clean；  
  4. B读取A传过来的buffer里的data；  
- B share data to A  
  1. B也要知道A的cache line size，准备buffer的时候也要start address和size都cache line size aligned；  
  2. B填充data到buffer；  
  3. A拿到buffer的start address和size后，先进行cache invalidate操作，这样A就可以拿到B送过来的数据了；  

## Summary
&emsp;&emsp;实际上上面的例子是具有普遍性的，比如Arm CPU送data给DSP/GPU/DPU等处理音视频数据，处理完以后把data拿回来再做其他操作。  
&emsp;&emsp;上面的操作步骤不能省略，不然容易出问题，而且还是不容易debug的奇怪问题。  

