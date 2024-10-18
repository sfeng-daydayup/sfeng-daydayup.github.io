---
layout: post
title: Practice of Asymmetric-Key Alg
date: 2024-10-13 18:39 +0800
author: sfeng
categories: [Security]
tags: [alg, security]
lang: zh
---

&emsp;&emsp;继续趁热打铁，实践下非对称算法怎么在openssl里怎么用。 

## Generation of Key Pairs

&emsp;&emsp;同样的，非对称算法首先要生成公私钥对。对称算法的密钥随机生成即可，非对称算法的密钥却要符合一定的要求，比如RSA密钥的产生首先要找两个大素数，然后根据欧拉定理等等推出公钥和私钥。本例中通过openssl来生成RSA和SM2的公私钥。  

### RSA
&emsp;&emsp;先生成私钥：  
```shell
openssl genrsa -out rsa_4096_private.pem 4096
```

&emsp;&emsp;.pem文件里是base64 encoded data，大致结构为：  
```
    RSAPrivateKey ::= SEQUENCE {
      version   Version,
      modulus   INTEGER,  -- n
      publicExponent    INTEGER,  -- e
      privateExponent   INTEGER,  -- d
      prime1    INTEGER,  -- p
      prime2    INTEGER,  -- q
      exponent1 INTEGER,  -- d mod (p-1)
      exponent2 INTEGER,  -- d mod (q-1)
      coefficient   INTEGER,  -- (inverse of q) mod p
      otherPrimeInfos   OtherPrimeInfos OPTIONAL
    }
```

&emsp;&emsp;该结构里包含：  
1. 两个大素数p和q  
2. p和q的乘积n  
3. 随机选择的整数e（为了加快计算速度，一般为65537，即0x10001）  
4. 用欧拉函数和辗转相除法得到的d  
&emsp;&emsp;其中（n，e）为公钥，（n，d）为私钥。  

&emsp;&emsp;感兴趣的可以用以下命令查看：  
```shell
openssl pkey -in rsa_4096_private.pem -text -noout
```

&emsp;&emsp;根据私钥生成公钥，其实就是输出（n，e）：  
```shell
openssl rsa -in rsa_4096_private.pem -pubout -out rsa_4096_public.pem -outform PEM 
```

&emsp;&emsp;输出格式为：  
```
    RSAPublicKey ::= SEQUENCE {
      modulus   INTEGER,  -- n
      publicExponent    INTEGER   -- e
    }
```

&emsp;&emsp;可用以下命令查看：  
```shell
openssl pkey -pubin -in rsa_4096_public.pem -text -noout
```

### SM2
&emsp;&emsp;SM2是ECC的一种，原理和RSA完全不同，它的私钥是一串随机数，强度上256bit的密钥就可以媲美RSA-3072。密钥生成command如下：  
```shell
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:sm2 -out sm2_private.pem
```

&emsp;&emsp;导出公钥：  
```shell
openssl pkey -in sm2_private.pem -pubout -out sm2_public.pem
```

&emsp;&emsp;查看也是一样：  
```shell
openssl pkey -in sm2_private.pem -text -noout
openssl pkey -pubin -in sm2_public.pem -text -noout
```

## Encrypt and Decrypt

### RSA
&emsp;&emsp;公钥加密：  
```shell
openssl pkeyutl -encrypt -inkey rsa_4096_public.pem -pubin -in hello_world.txt -out hello_world.txt.rsa_4096.enc
```
&emsp;&emsp;私钥解密：  
```shell
openssl pkeyutl -decrypt -inkey rsa_4096_private.pem -in hello_world.txt.rsa_4096.enc -out hello_world.txt.rsa_4096.dec
```

### SM
&emsp;&emsp;公钥加密：  
```shell
openssl pkeyutl -encrypt -inkey sm2_public.pem -pubin -in hello_world.txt -out hello_world.txt.sm2.enc
```
&emsp;&emsp;私钥解密：  
```shell
openssl pkeyutl -decrypt -inkey sm2_private.pem -in hello_world.txt.sm2.enc -out hello_world.txt.sm2.dec
```

> 由于非对称加解密算法相比对称加解密算法性能相差很多，一般只对小数据进行加解密。OPENSSL本身就有这个限制。
{: .prompt-tip }  

## Sign and Verify

&emsp;&emsp;其实sign&verify和encrypt&decrypt的区别就是公私钥互换了以下，目的也不同：  
1. 签名由私钥对数据摘要进行加密，公钥分发出去，使用数据的用户用公钥验签保证拿到的数据完整性
2. 加解密则是用户用公钥把加密的数据发给接收端，接收端拿私钥解开以保证数据的私密性

### RSA
&emsp;&emsp;私钥签名：  
```shell
openssl pkeyutl -sign -inkey rsa_4096_private.pem -in hash.txt -out hash.txt.rsa_4096_sha256.sign -rawin -digest sha256
```

&emsp;&emsp;公钥验签：  
```shell
openssl pkeyutl -verify -inkey rsa_4096_public.pem -pubin -in hash.txt -sigfile hash.txt.rsa_4096_sha256.sign -rawin -digest sha256
```

### SM

&emsp;&emsp;私钥签名：  
```shell
openssl pkeyutl -sign -inkey sm2_private.pem -in hash.txt -out hash.txt.sm2.sign -rawin -digest sm3
```

&emsp;&emsp;公钥验签：  
```shell
openssl pkeyutl -verify -inkey sm2_public.pem -pubin -in hash.txt -sigfile hash.txt.sm2.sign -rawin -digest sm3
```

## Reference
[**RSA Private Key File**](https://mbed-tls.readthedocs.io/en/latest/kb/cryptography/asn1-key-structures-in-der-and-pem/#rsa-private-key-file-pkcs-1)  
[**openssl-pkey**](https://docs.openssl.org/3.0/man1/openssl-pkey/)  
[**Elliptic Curve Cryptography**](https://medium.com/@elusivprivacy/an-introduction-to-elliptic-curve-cryptography-19a6e5752fcf)  
[**opensll-pkeyutl**](https://docs.openssl.org/3.0/man1/openssl-pkeyutl)  