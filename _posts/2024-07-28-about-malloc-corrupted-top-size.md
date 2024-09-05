---
layout: post
title: 'About "malloc(): corrupted top size"'
date: 2024-07-28 16:28 +0800
author: sfeng
categories: [Blogging, Dev]
tags: [linux, malloc]
lang: zh
---

&emsp;&emsp;上周碰到一个很奇怪的问题，一直出现"malloc(): corrupted top size"这个错误，导致application异常退出。反复检查malloc的size，甚至手动变化这个size的大小，还是一直出错。百思不得其解。这个周末闲来无事，认真检查了整个代码，发现竟然是之前malloc的buffer小了，导致memory操作越界，但竟然没有当场出错，而是再次的malloc的时候才报错误。示例代码如下：  

```shell
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char *argv[])
{
        unsigned char *buff = NULL;
        unsigned char *buff1 = NULL;

        buff = malloc(10);

        printf("%s %d\n", __func__, __LINE__);
        memset(buff, 0xff, 5000);
        printf("%s %d\n", __func__, __LINE__);

        if (argc == 2) {
                printf("%s %d\n", __func__, __LINE__);
                buff1 = malloc(4);
                printf("%s %d\n", __func__, __LINE__);
                free(buff1);
        }

        free(buff);

        return 0;
}
```

&emsp;&emsp;先不带参数运行：  
```shell
# ./malloc_test  
main 12
main 14
```

&emsp;&emsp;惊讶不，申请了10个字节，memset 5000个字节，竟然没有错误。随意带一个参数再运行： 

```shell
# ./malloc_test 1
main 12
main 14
main 17
malloc(): corrupted top size
Aborted
```

&emsp;&emsp;这次出错了，第二次malloc没有成功，没有运行到19行打印就直接退出。  

&emsp;&emsp;另外，博主只能用arm gcc cross compiler编译好binary在arm开发板可以重复这个问题。在Linux主机上用gcc编译，同样的程序会crash。但是把memset的size从5000改小到20，运行没有任何错误提示。同样，把5000该小到20，arm开发板上也没有错误发生。  
&emsp;&emsp;测试程序比较简单，如果是在一个比较大的项目里，是否就此埋下了一个坑就不得而知了。总之，嵌入式开发中对memory的操作还是要小心，比如我的测试程序里就没有检查malloc是否返回了一个有效值:smirk:。  

> CPU: ARM Cortex-A55  
> Compiler: GNU Toolchain for the A-profile Architecture 8.3-2019.02
{: .prompt-info }

&emsp;&emsp;另外，把编译器换成最新的Arm GNU Toolchain 13.3，编译的时候有warning，但是，运行的时候连错误都没有......  

&emsp;&emsp;有什么方法可以提早发现这种错误呢？

&emsp;&emsp;记录一下，以防遗忘。