---
layout: post
title: Practice of Symmetric-Key Alg
date: 2024-10-06 15:02 +0800
author: sfeng
categories: [Security]
tags: [alg, security]
lang: zh
---

&emsp;&emsp;上篇罗列了常用的算法，这篇趁热打铁实践下对称算法怎么在openssl里怎么用。  

## Generation of Secret Key

&emsp;&emsp;使用对称加解密算法首先是要生成密钥。一般都会用随机数生成器来产生一串随机数作为密钥，当然也可以通过KDF从已经存在的密钥衍生出新的密钥。  

> 在嵌入式系统中，密钥可以离线生成，也可以利用SoC自身的TRNG硬件模块在线生成。对于离线生成的密钥一定要从流程上防止暴露的可能性，重点关注密钥注入SoC的流程。密钥在SoC中一般保存在只有高安子系统才能访问或者解密的存储介质上，比如OTP或者Secure Storage。
{: .prompt-tip }  

&emsp;&emsp;在本例中，直接从/dev/uramdom产生密钥。另外有些工作模式需要IV，也用urandom生成。  
```shell
dd if=/dev/urandom of=sk bs=16 count=1
dd if=/dev/urandom of=iv bs=16 count=1
```  

## Encryption
&emsp;&emsp;本文中分别用AES和SM4配合几种工作模式在openssl中加密数据。  

> 为了直观的显示某些加密特性，本例中选用了图片作为操作的原始数据。图片的几个要求为：
> 1. 格式为[BMP](https://www.ece.ualberta.ca/~elliott/ee552/studentAppNotes/2003_w/misc/bmp_file_format/bmp_file_format.htm)
> 2. BMP中每个pix所占长度应为分组长度的公约数，本例中为8 bits (图片稍有失真)
> 3. 加解密应忽略header
{: .prompt-info }  

&emsp;&emsp;原始图片为：  
![example.bmp](/assets/img/aes/test/example.bmp){: .normal }  

&emsp;&emsp;用AES 128 ECB加密：  
```shell
openssl enc -aes-128-ecb -e -in example.data.bmp -out example.aes_128_ecb.data.bmp -K $(xxd -ps sk) 
```

&emsp;&emsp;加密后图片显示：  
![example_aes_128_ecb.bmp](/assets/img/aes/test/example_aes_128_ecb.bmp){: .normal }

&emsp;&emsp;用SM4 ECB加密（密钥相同）：  
```shell
openssl enc -sm4-ecb -e -in example.data.bmp -out example.sm4_ecb.data.bmp -K $(xxd -ps sk) 
```

&emsp;&emsp;加密后图片显示：  
![example_sm4_ecb.bmp](/assets/img/aes/test/example_sm4_ecb.bmp){: .normal }

&emsp;&emsp;从显示图片可以看出，经过用ecb模式处理后，数据虽然被加密，但是大致轮廓还清晰可见，hacker可能通过明文和密文的对比，猜出大致的内容。所以ecb模式虽然快，但是**相对**容易被破解。对security要求比较高的应该采用其他工作模式。  

&emsp;&emsp;其他模式的机密命令如下：  
```shell
// aes 128 ctr
openssl enc -aes-128-ctr -e -in example.data.bmp -out example.aes_128_ctr.data.bmp -K $(xxd -ps sk) -iv $(xxd -ps iv) 
// aes 128 cbc
openssl enc -aes-128-cbc -e -in example.data.bmp -out example.aes_128_cbc.data.bmp -K $(xxd -ps sk) -iv $(xxd -ps iv) 
// aes 128 ofb
openssl enc -aes-128-ofb -e -in example.data.bmp -out example.aes_128_ofb.data.bmp -K $(xxd -ps sk) -iv $(xxd -ps iv) 
// aes 128 cfb
openssl enc -aes-128-cfb -e -in example.data.bmp -out example.aes_128_cfb.data.bmp -K $(xxd -ps sk) -iv $(xxd -ps iv) 
// sm4 ctr
openssl enc -sm4-ctr -e -in example.data.bmp -out example.sm4_ctr.data.bmp -K $(xxd -ps sk) -iv $(xxd -ps iv) 
// sm4 cbc
openssl enc -sm4-cbc -e -in example.data.bmp -out example.sm4_cbc.data.bmp -K $(xxd -ps sk) -iv $(xxd -ps iv) 
// sm4 ofb
openssl enc -sm4-ofb -e -in example.data.bmp -out example.sm4_ofb.data.bmp -K $(xxd -ps sk) -iv $(xxd -ps iv) 
// sm4 cfb
openssl enc -sm4-cfb -e -in example.data.bmp -out example.sm4_cfb.data.bmp -K $(xxd -ps sk) -iv $(xxd -ps iv) 
```

&emsp;&emsp;这里任选一张加密后图片，可以看出，加密数据基本无序化。  
![example_aes_128_ctr.bmp](/assets/img/aes/test/example_aes_128_ctr.bmp){: .normal }

## Decryption

&emsp;&emsp;解密比较简单，基本上格式都差不多，命令如下：  
```shell
// aes 128 ecb
openssl enc -aes-128-ecb -d -in example.aes_128_ecb.data.bmp -out example.aes_128_ecb.pdata.bmp -K $(xxd -ps sk)
// aes 128 ctr
openssl enc -aes-128-ctr -d -in example.aes_128_ctr.data.bmp -out example.aes_128_ctr.pdata.bmp -K $(xxd -ps sk) -iv $(xxd -ps iv) 
// aes 128 cbc
openssl enc -aes-128-cbc -d -in example.aes_128_cbc.data.bmp -out example.aes_128_cbc.pdata.bmp -K $(xxd -ps sk) -iv $(xxd -ps iv) 
// aes 128 ofb
openssl enc -aes-128-ofb -d -in example.aes_128_ofb.data.bmp -out example.aes_128_ofb.pdata.bmp -K $(xxd -ps sk) -iv $(xxd -ps iv) 
// aes 128 cfb
openssl enc -aes-128-cfb -d -in example.aes_128_cfb.data.bmp -out example.aes_128_cfb.pdata.bmp -K $(xxd -ps sk) -iv $(xxd -ps iv) 
// sm4 ecb
openssl enc -sm4-ecb -d -in example.sm4_ecb.data.bmp -out example.sm4_ecb.pdata.bmp -K $(xxd -ps sk) 
// sm4 ctr
openssl enc -sm4-ctr -d -in example.sm4_ctr.data.bmp -out example.sm4_ctr.pdata.bmp -K $(xxd -ps sk) -iv $(xxd -ps iv) 
// sm4 cbc
openssl enc -sm4-cbc -d -in example.sm4_cbc.data.bmp -out example.sm4_cbc.pdata.bmp -K $(xxd -ps sk) -iv $(xxd -ps iv) 
// sm4 ofb
openssl enc -sm4-ofb -d -in example.sm4_ofb.data.bmp -out example.sm4_ofb.pdata.bmp -K $(xxd -ps sk) -iv $(xxd -ps iv) 
// sm4 cfb
openssl enc -sm4-cfb -d -in example.sm4_cfb.data.bmp -out example.sm4_cfb.pdata.bmp -K $(xxd -ps sk) -iv $(xxd -ps iv) 
```

&emsp;&emsp;最后补一张表，对照[Brief of Cryptography Algorithm](https://sfeng-daydayup.github.io/posts/brief-of-cryptography-algorithm/)里的图来理解。  

| Work Mode | Encryption Parallelizable | Decryption Parallelizable | Random Read Access |
|:---------:|:-------------------------:|:-------------------------:|:------------------:|
|    ECB    |            Yes            |            Yes            |         Yes        |
|    CTR    |            Yes            |            Yes            |         Yes        |
|    CBC    |             No            |            Yes            |         Yes        |
|    PCBC   |             No            |             No            |         No         |
|    OFB    |             No            |             No            |         No         |
|    CFB    |             No            |            Yes            |         Yes        |
|    GSM    |            Yes            |            Yes            |         Yes        |