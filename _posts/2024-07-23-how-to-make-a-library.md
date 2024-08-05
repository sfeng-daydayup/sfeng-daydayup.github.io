---
layout: post
title: How to Make a Library
date: 2024-08-03 18:45 +0800
author: sfeng
categories: [Blogging, Dev]
tags: [lib]
lang: zh
---
## Preface
&emsp;&emsp;嗯，最近在做OPTEE，其中有个编译宏叫做CFG_ULIBS_SHARED，后续准备写一篇关于这个宏的一些东西，这篇作为先导，复习一下知识。  

## Content
&emsp;&emsp;关于c中的Libary，有两种，一种是static library，一种是dynamic library。其中static libary是直接打包在目标文件里的，而dynamic libary则只是在Daynamic Section里留下一个NEEDED的记录，等到真正运行的时候从系统的LD_LIBRARY_PATH或者指定的rpath去寻找。接下来看下如何生成和使用它们。  

### Prerequisite
&emsp;&emsp;我们先准备几个作为test的库文件或者叫库函数。  

```sass
int mix(int a, int b)
{
        return (add(a, b) + mul(a, b));
}
```
{: file='lib1.c'}

```sass
int add(int a, int b)
{       
        return (a + b);
}
```
{: file='lib2.c'}

```sass
int mul(int a, int b)
{
        return (a * b);
}
```
{: file='lib3.c'}

```sass
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv)
{
        int a = 5;  //simply set to a fixed value
        int b = 7;

        printf("%d + %d = %d\n", a, b, add(a, b));
        printf("%d * %d = %d\n", a, b, mul(a, b));
        printf("mix = %d\n", mix(a, b));

        return 0;
}
```
{: file='main.c'}

&emsp;&emsp;先一把编译出一个可执行文件。  

```shell
gcc main.c lib1.c lib2.c lib3.c -o testlib
```

&emsp;&emsp;objdump下看下Dynamic Section和Dynamic Symbol Table：  

```
Dynamic Section:
  NEEDED               libc.so.6
  INIT                 0x00000000004003c8
  FINI                 0x00000000004006b4
  INIT_ARRAY           0x0000000000600e10
  .......
```

```
DYNAMIC SYMBOL TABLE:
0000000000000000      DF *UND*  0000000000000000  GLIBC_2.2.5 printf
0000000000000000      DF *UND*  0000000000000000  GLIBC_2.2.5 __libc_start_main
0000000000000000  w   D  *UND*  0000000000000000              __gmon_start__
```

&emsp;&emsp;另外如果加了-static编译，这两个都没有内容了。

### Static Library
&emsp;&emsp;生成static library需要用到ar这个GNU compiler命令。ar的man可以看这里[**ar**](https://linux.die.net/man/1/ar)。  
&emsp;&emsp;主要用到的option有以下几个：  

```
r
Insert the files member... into archive (with replacement). This operation differs from q in that any previously existing members are deleted if their names match those being added.

c
Create the archive. The specified archive is always created if it did not exist, when you request an update. But a warning is issued unless you specify in advance that you expect to create it, by using this modifier.

s
Write an object-file index into the archive, or update an existing one, even if no other change is made to the archive. You may use this modifier flag either with any operation, or alone. Running ar s on an archive is equivalent to running ranlib on it.

t
Display a table listing the contents of archive, or those of the files listed in member... that are present in the archive.
```

&emsp;&emsp;生成一个static library的步骤如下：  

```shell
gcc -c lib*.c
ar -crs libtest.a lib1.o lib2.o lib3.o
ar -t libtest.a
lib1.o
lib2.o
lib3.o
```

&emsp;&emsp;把lib.a link到最终的执行文件：  

```shell
gcc main.c -o testlib -L. -ltest
```
&emsp;&emsp;对比以下Dynamic Section和Dynamic Symbol Table：  

```
Dynamic Section:
  NEEDED               libc.so.6
  INIT                 0x00000000004003c8
  FINI                 0x00000000004006b4
  INIT_ARRAY           0x0000000000600e10
```

```
DYNAMIC SYMBOL TABLE:
0000000000000000      DF *UND*  0000000000000000  GLIBC_2.2.5 printf
0000000000000000      DF *UND*  0000000000000000  GLIBC_2.2.5 __libc_start_main
0000000000000000  w   D  *UND*  0000000000000000              __gmon_start__
```

&emsp;&emsp;发现和上面一把生成没啥区别。这样做的好处是不用再重新编译static library里的文件，直接link就可以了。也适用于有些同学不想暴露自己的code，只给lib，毕竟反汇编也是需要一定门槛的。

### Dynamic Library

&emsp;&emsp;关于Dynamic Libary的生成，一般大家都是用gcc直接生成，比如本例中可以用以下命令：  
```shell
gcc -fPIC -shared -o libtest.so lib1.c lib2.c lib3.c
```

&emsp;&emsp;但实际上最终link的时候还是call了ld命令。下面的命令和上面是等同的：   
```shell
gcc -fPIC -c lib*.c
ld -shared libtest.so lib1.o lib2.o lib3.o
```

&emsp;&emsp;Link Dynamic Library的编译命令如下：
```shell
gcc main.c -o testlib -L. -ltest
```

&emsp;&emsp;同样看下Dynamic Section和Dynamic Symbol Table：  

```
Dynamic Section:
  NEEDED               libtest.so
  NEEDED               libc.so.6
  INIT                 0x00000000004005d0
  FINI                 0x0000000000400874
  INIT_ARRAY           0x0000000000600e00
```

```
DYNAMIC SYMBOL TABLE:
0000000000000000  w   D  *UND*  0000000000000000              _ITM_deregisterTMCloneTable
0000000000000000      DF *UND*  0000000000000000              add
0000000000000000      DF *UND*  0000000000000000  GLIBC_2.2.5 printf
0000000000000000      DF *UND*  0000000000000000              mix
0000000000000000      DF *UND*  0000000000000000  GLIBC_2.2.5 __libc_start_main
0000000000000000  w   D  *UND*  0000000000000000              __gmon_start__
0000000000000000      DF *UND*  0000000000000000              mul
0000000000000000  w   D  *UND*  0000000000000000              _Jv_RegisterClasses
0000000000000000  w   D  *UND*  0000000000000000              _ITM_registerTMCloneTable
0000000000601050 g    D  .data  0000000000000000  Base        _edata
0000000000601058 g    D  .bss   0000000000000000  Base        _end
0000000000601050 g    D  .bss   0000000000000000  Base        __bss_start
00000000004005d0 g    DF .init  0000000000000000  Base        _init
0000000000400874 g    DF .fini  0000000000000000  Base        _fini
```

&emsp;&emsp;Dynamic Section里多了一项要动态链接的库文件名，DYNAMIC SYMBOL TABLE多了动态链接的函数列表。  

&emsp;&emsp;运行的时候发现找不到动态链接库，有三种解决方法：  
1. 把上一步生成的libtest.so copy到系统默认的lib目录下；  
2. 通过LD_LIBRARY_PATH指定Dynamic Library的路径（运行时）；  
3. 通过-rpath指定Dynamic Library的路径（编译时）；  

&emsp;&emsp;关于Dynamic Library还有一个名字的问题，这里介绍另外一个option叫soname，可以通过以下命令指定：  
```shell
ld -shared -soname=libtest.so.1 libtest.so lib1.o lib2.o lib3.o
```  
or
```shell
gcc -fPIC -shared -Wl,-soname=libtest.so.1 -o libtest.so lib1.c lib2.c lib3.c
```  

&emsp;&emsp;这个名字有啥用？之前几次都有把Dynamic Section打出来看，这次在用soname指定名字后重新编译链接再看以下：  
```
Dynamic Section:
  NEEDED               libtest.so.1
  NEEDED               libc.so.6
  INIT                 0x00000000004005d0
  FINI                 0x0000000000400874
  INIT_ARRAY           0x0000000000600e00
```

&emsp;&emsp;有没有发现这里要动态链接的库由libtest.so变成了指定的名字libtest.so.1？！然后运行下，发现又发生找不到的库的错误。这时把生成的libtest.so改名为libtest.so.1，再运行，成功。  

&emsp;&emsp;另外，大家发现没有，不管link static library还是dynamic library，用的是同一条命令：  
```shell
gcc main.c -o testlib -L. -ltest
```  

&emsp;&emsp;这时候libtest.a和libtest.so在本目录下都存在，最终生成的文件link的却是libtest.so，可见动态链接库是有优先使用权的。  

## Reference
[**ar**](https://linux.die.net/man/1/ar)  
[**ld**](https://linux.die.net/man/1/ld)  
[**rpath**](https://en.wikipedia.org/wiki/Rpath)  