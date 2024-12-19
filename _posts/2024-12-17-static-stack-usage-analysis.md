---
layout: post
title: Static Stack Usage Analysis
date: 2024-12-17 18:51 +0800
author: sfeng
categories: [Dev]
tags: [memory]
lang: zh
---

## Background

&emsp;&emsp;在嵌入式系统中，资源的有限性是不争的事实，特别是可用的内存（SRAM, DRAM，TCM etc.）大多数情况下都不是那么富裕，这就需要对内存的使用精打细算了。本文介绍一种方法来帮助开发者分析stack的大小。这是因为stack其实对开发者来说是个隐含条件，并没有标准简单的方法拿到合适的值。大多数会在stack溢出的时候才会通过加大stack的方法解决问题，而debug stack问题本身就是一个很棘手的事情，因为这类问题更像一个随机的bug，所以干脆在开始就指定一个比较大的stack，这样就造成一定的浪费。  

## Useful GCC Options
&emsp;&emsp;本着尽量简单和使用已有工具的原则，编译器就是首选的工具。因为编译器把源文件编译为最终的机器码，理论上编译器应该掌握所有的细节。只在于它是否把这些信息expose出来。来看看下面两个GCC option。  

>  Compiler: (Arm GNU Toolchain 13.3.Rel1 (Build arm-13.24)) 13.3.1 20240614
{: .prompt-info }  

### fstack-usage
> -fstack-usage
>   Makes the compiler output stack usage information for the program, on a per-function basis. The filename for the dump is made by appending .su to the auxname. auxname is generated from the name of the output file, if explicitly specified and it is not an executable, otherwise it is the basename of the source file. 
{: .prompt-info } 

&emsp;&emsp;在编译的时候加上-fstack-usage会在编译结果中额外生成以.su结尾的文件，它包含了每个function需要的最大的堆栈size。其输出的格式如下：  
```shell
<source_file>:<line_number>:<function_name> <size_in_bytes> <qualifiers>
```  
&emsp;&emsp;前面的都好理解，最后一个qualifiers为下面几个之一：  
- static 通常是指function的local variable都是固定的size，所以该function使用的stack也是固定的。  
- dynamic 与static相反，function的local variable的size在runtime是变化的话，例如基于输入数据或者递归调用，就是dynamic。  
- bounded 接着上面，虽然stack的使用依赖运行时条件，但使用stack的上限可预知，那就是bounded。  
&emsp;&emsp;直接来个例子更容易理解。  
```sass
int t = 0;

void func1_static(void)
{
        char d[4] = {0};
        int a = 0;
}

void func2_static(void)
{
        int i = 0;
        char b[10];

        for (i = 0; i < 10; i++)
                b[i] = 'a' + i;

        func1_static();
}

void func3_static(void)
{
        func2_static();
}

void func4_static(void)
{
        t = 5;
}

void func5_dynamic(int size)
{
        int i = 0;
        char c[size];

        for (i = 0; i < size; i++)
                c[i] = 'a' + i;
}

void func6_dynamic(void)
{
        alloca(64);
}

void main(void)
{
        func1_static();
        func2_static();
        func3_static();
        func4_static();
        func5_dynamic(10);
        func5_dynamic(32);
        func6_dynamic();
}
```  
{: file='test.c'}

> 注： 在上例中用了VLA（variable-length array），C语言中C99开始support这个feature。建议这里还是用malloc之类的function来动态分配内存并在随后释放。  
{: .prompt-info }  

&emsp;&emsp;带-fstack-usage编译后生成了.su文件。如下：  
```sass
test.c:6:6:func1_static 16      static
test.c:12:6:func2_static        32      static
test.c:23:6:func3_static        16      static
test.c:28:6:func4_static        0       static
test.c:33:6:func5_dynamic       64      dynamic
test.c:42:6:func6_dynamic       80      dynamic
test.c:47:6:main        16      static
```
{: file='test.su'}

&emsp;&emsp;今天不讨论为什么每个function的stack大小是上面所列数值（回头另写一篇文章仔细分析），唯一要注意的是使用了VLA的function的stack size是不准确的，同时再次建议用malloc从heap动态分配。  

&emsp;&emsp;test.su中列出了每个function要用到的stack大小，那如何计算stack的极限近似值呢？这就又涉及到另外一个GCC Option了。  

### fcallgraph-info

> -fcallgraph-info
> -fcallgraph-info=MARKERS
>   Makes the compiler output callgraph information for the program, on a per-object-file basis. The information is generated in the common VCG format. It can be decorated with additional, per-node and/or per-edge information, if a list of comma-separated markers is additionally specified. When the su marker is specified, the callgraph is decorated with stack usage information; it is equivalent to -fstack-usage. When the da marker is specified, the callgraph is decorated with information about dynamically allocated objects.
> 注：这个选项要比较新的GCC编译器才支持。
{: .prompt-info }

&emsp;&emsp;编译的时候加上这个选项会生成一个.ci文件，它可以用VCG viewer生成可视化的call graph图片。本文并不需要生成图片，只需要理清调用关系就可以了。上例中生成的.ci文件如下：  
```sass
graph: { title: "test.c"
node: { title: "func1_static" label: "func1_static\ntest.c:6:6" }
node: { title: "func2_static" label: "func2_static\ntest.c:12:6" }
edge: { sourcename: "func2_static" targetname: "func1_static" label: "test.c:20:2" }
node: { title: "func3_static" label: "func3_static\ntest.c:23:6" }
edge: { sourcename: "func3_static" targetname: "func2_static" label: "test.c:25:2" }
node: { title: "func4_static" label: "func4_static\ntest.c:28:6" }
node: { title: "func5_dynamic" label: "func5_dynamic\ntest.c:33:6" }
node: { title: "func6_dynamic" label: "func6_dynamic\ntest.c:42:6" }
node: { title: "main" label: "main\ntest.c:47:6" }
edge: { sourcename: "main" targetname: "func1_static" label: "test.c:49:2" }
edge: { sourcename: "main" targetname: "func2_static" label: "test.c:50:2" }
edge: { sourcename: "main" targetname: "func3_static" label: "test.c:51:2" }
edge: { sourcename: "main" targetname: "func4_static" label: "test.c:52:2" }
edge: { sourcename: "main" targetname: "func5_dynamic" label: "test.c:53:2" }
edge: { sourcename: "main" targetname: "func5_dynamic" label: "test.c:54:2" }
edge: { sourcename: "main" targetname: "func6_dynamic" label: "test.c:55:2" }
}
```
{: file='test.ci'}

&emsp;&emsp;其实到这里已经可以结合test.ci和test.su算出需要的最大stack了，然而callgraph-info还支持MARKERS，当MARKDERS设为su时，stack-usage的信息也会出现在.ci中。如下：  
```sass
graph: { title: "test.c"
node: { title: "func1_static" label: "func1_static\ntest.c:6:6\n16 bytes (static)" }
node: { title: "func2_static" label: "func2_static\ntest.c:12:6\n32 bytes (static)" }
edge: { sourcename: "func2_static" targetname: "func1_static" label: "test.c:20:2" }
node: { title: "func3_static" label: "func3_static\ntest.c:23:6\n16 bytes (static)" }
edge: { sourcename: "func3_static" targetname: "func2_static" label: "test.c:25:2" }
node: { title: "func4_static" label: "func4_static\ntest.c:28:6\n0 bytes (static)" }
node: { title: "func5_dynamic" label: "func5_dynamic\ntest.c:33:6\n64 bytes (dynamic)" }
node: { title: "func6_dynamic" label: "func6_dynamic\ntest.c:42:6\n80 bytes (dynamic)" }
node: { title: "main" label: "main\ntest.c:47:6\n16 bytes (static)" }
edge: { sourcename: "main" targetname: "func1_static" label: "test.c:49:2" }
edge: { sourcename: "main" targetname: "func2_static" label: "test.c:50:2" }
edge: { sourcename: "main" targetname: "func3_static" label: "test.c:51:2" }
edge: { sourcename: "main" targetname: "func4_static" label: "test.c:52:2" }
edge: { sourcename: "main" targetname: "func5_dynamic" label: "test.c:53:2" }
edge: { sourcename: "main" targetname: "func5_dynamic" label: "test.c:54:2" }
edge: { sourcename: "main" targetname: "func6_dynamic" label: "test.c:55:2" }
}
```
{: file='test.ci'}

&emsp;&emsp;这样，只要解析test.ci就可以了（需要写个脚本，其中node为函数信息，edge为调用关系）。过程如下：  
1. 找到入口函数，这里为“main”  
2. 依次查找被调用的函数，并累计stack size  
3. 重复#2，直到本函数为此次执行的结尾，也就是没有下级调用函数  
4. 与之前统计的最大stack的值比较，大于则更新最大stack的值  
5. 返回上级函数，重复#2  
6. 直到没有上级函数，也就是main没有上级函数  
7. 这个时候最大stack的值就是最终值  

## Note
&emsp;&emsp;看起来是不是很简单，实际上还有其他因素需要考虑。  
1. 对于bootloader类型的单线程任务，计算从entry开始的最大stack就可以了。但对跑RTOS的系统，要根据每个thread/task的入口函数计算各自的stack值。  
2. assembly code的分析并不到位。如果之后的c文件中有调用assembly function，call graph可能就断了，需要手动操作连起来。  
3. 如前面提到的，对于动态内存需求，从heap分配，而避免使用诸如VLA或者alloca之类的方案。  
4. 要考虑interrupt带来的额外stack开销。  
5. 如果开启了FPU，NEON之类的功能，stack也要考虑相应增加的开销。  
6. 递归调用会造成偏差。  
7. 每个source文件都会生成一个.ci文件，parse的时候需要把他们cat到一起。  

&emsp;&emsp;总之stack size的确定并不简单，本文介绍了其中一种可能的方法，适用范围其实是有限的。还有一种动态检测的方法，但也存在其他问题，有兴趣可以研究下这篇文章[**Stack Analysis**](https://www.adacore.com/uploads/techPapers/Stack_Analysis.pdf)。  

## End
&emsp;&emsp;最后，博主通过查看dump出的asm文件，发现stack的操作及函数调用关系在asm文件中都有体现，是否可以通过parse asm文件来确定？留待后续实践。  

## Reference
[**Static Stack Usage Analysis**](https://gcc.gnu.org/onlinedocs/gnat_ugn/Static-Stack-Usage-Analysis.html)  
[**GCC Options**](https://gcc.gnu.org/onlinedocs/gcc/Developer-Options.html)  
[**fstack-usage**](https://developer.arm.com/documentation/101754/0623/armclang-Reference/armclang-Command-line-Options/-fstack-usage)  
[**gcc flags for analyzing memory usage**](https://embeddedartistry.com/blog/2020/08/17/three-gcc-flags-for-analyzing-memory-usage/)  
[**VLA**](https://en.wikipedia.org/wiki/Variable-length_array)  
[**Stack Analysis**](https://www.adacore.com/uploads/techPapers/Stack_Analysis.pdf)  
[**Stack Analyzer Demo**](https://www.youtube.com/watch?v=cO3kj9M514M)  
[**introduce -fcallgraph-info option**](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=3cf3da88be453f3fceaa596ee78be8d1e5aa21ca)  
[**Arm Linker - Callgraph**](https://developer.arm.com/documentation/ka004928/latest/)  
[**GNU cflow**](https://www.gnu.org/software/cflow/)  