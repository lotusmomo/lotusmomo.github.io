---
title: 我们是怎么发现C++异常从堆栈追踪中消失的原因的
date: 2022-07-30 16:51:00
updated: 2022-08-01 23:26:04
tags: []
categories: 程序人生
---
每当我的程序崩溃的时候，我都会用核心转储 (core dump) 文件来找出来崩溃发生的具体位置。（关于怎么产生和使用核心转储可以看[我的文章](#)。）一直以来我调程序的时候都是很开心的……直到我遇到了这个新的 bug。当我把它的核心转储文件载入到 GDB 之后，我很失望地发现所有的堆栈追踪 (stack trace) 都是关于系统库的，没有一行是关于我的代码的。

<!--more-->

> TLDR: [这个补丁](https://gcc.gnu.org/viewcvs/gcc/trunk/libstdc%2B%2B-v3/src/c%2B%2B11/thread.cc?r1=249130&r2=249129&pathrev=249130)就好了。

让我们踏上探索未知的旅程吧。

# 背景介绍

为了帮助我亲爱的读者朋友们理解我日常的调程序过程，让我们来看看这个简短的 C++ 代码：

```c++
// compile with:
//   g++ -g -std=c++11 sigsegv.cc -o sigsegv -pthread
#include <thread>
#include <vector>
#include <iostream>
void foo() {
    std::vector<int> v;
    std::cout << v[100] << std::endl;
}
int main() {
    std::thread t(foo);
    t.join();
}
```

不出意外，这里应该要有一个段错误 (segmentation fault)。想要知道哪里触发了段错误，如果这个问题不是很容易触发的话，你可以把核心转储文件载入到 GDB 里面，或者如果这个问题很容易重现的话，你也可以直接在 GDB 里面重新跑一遍。那这里就让我们直接在 GDB 里面跑一遍：

```shell
    $ gdb ./sigsegv
    GNU gdb (Ubuntu 7.11.1-0ubuntu1~16.5) 7.11.1
    Reading symbols from ./sigsegv...done.
    (gdb) r
    Starting program: /tmp/sigsegv
    [Thread debugging using libthread_db enabled]
    Using host libthread_db library "/lib/x86_64-linux-gnu/libthread_db.so.1".
    [New Thread 0x7ffff6f4e700 (LWP 68189)]
    
    Thread 2 "sigsegv" received signal SIGSEGV, Segmentation fault.
    [Switching to Thread 0x7ffff6f4e700 (LWP 68189)]
    0x0000000000400f5d in foo () at sigsegv.cc:8
    8	    std::cout << v[100] << std::endl;
    
    (gdb) bt
    #0  0x0000000000400f5d in foo () at sigsegv.cc:8
    #1  0x00000000004027dd in std::_Bind_simple<void (*())()>::_M_invoke<>(std::_Index_tuple<>) (this=0x617c48)
        at /usr/include/c++/5/functional:1531
    #2  0x0000000000402736 in std::_Bind_simple<void (*())()>::operator()() (this=0x617c48)
        at /usr/include/c++/5/functional:1520
    #3  0x00000000004026c6 in std::thread::_Impl<std::_Bind_simple<void (*())()> >::_M_run() (this=0x617c30)
        at /usr/include/c++/5/thread:115
    #4  0x00007ffff7b0dc80 in ?? () from /usr/lib/x86_64-linux-gnu/libstdc++.so.6
    #5  0x00007ffff76296ba in start_thread (arg=0x7ffff6f4e700) at pthread_create.c:333
    #6  0x00007ffff735f41d in clone () at ../sysdeps/unix/sysv/linux/x86_64/clone.S:109
```

可以看到，GDB 一如既往能够显示出来是在我们代码中的哪一行崩溃的。
到目前为止一切正常。但是在这一次的 bug 里面，我的代码用了 [vector::at](https://en.cppreference.com/w/cpp/container/vector/at) 来访问数组元素。如果访问越界，它会抛出 `std::out_of_range` 异常。

```c++
    // compile with:
    //   g++ -g -std=c++11 exception.cc -o exception -pthread
    #include <thread>
    #include <vector>
    #include <iostream>
    
    void foo() {
        std::vector<int> v;
        std::cout << v.at(100) << std::endl;
    }
    
    int main() {
        std::thread t(foo);
        t.join();
    }
```

看起来使用 at 是一个比 operator[] 更安全的写法。然而，这一次 GDB 却不会告诉我程序在哪里崩溃了：

```console
    $ gdb ./exception
    GNU gdb (Ubuntu 7.11.1-0ubuntu1~16.5) 7.11.1
    Reading symbols from ./exception...done.
    (gdb) r
    Starting program: /tmp/exception
    [Thread debugging using libthread_db enabled]
    Using host libthread_db library "/lib/x86_64-linux-gnu/libthread_db.so.1".
    [New Thread 0x7ffff6f4e700 (LWP 68143)]
    terminate called after throwing an instance of 'std::out_of_range'
      what():  vector::_M_range_check: __n (which is 100) >= this->size() (which is 0)
    
    Thread 2 "exception" received signal SIGABRT, Aborted.
    [Switching to Thread 0x7ffff6f4e700 (LWP 68143)]
    0x00007ffff728d428 in __GI_raise (sig=sig@entry=6) at ../sysdeps/unix/sysv/linux/raise.c:54
    54	../sysdeps/unix/sysv/linux/raise.c: No such file or directory.
    
    (gdb) bt
    #0  0x00007ffff728d428 in __GI_raise (sig=sig@entry=6) at ../sysdeps/unix/sysv/linux/raise.c:54
    #1  0x00007ffff728f02a in __GI_abort () at abort.c:89
    #2  0x00007ffff7ae484d in __gnu_cxx::__verbose_terminate_handler() () from /usr/lib/x86_64-linux-gnu/libstdc++.so.6
    #3  0x00007ffff7ae26b6 in ?? () from /usr/lib/x86_64-linux-gnu/libstdc++.so.6
    #4  0x00007ffff7ae2701 in std::terminate() () from /usr/lib/x86_64-linux-gnu/libstdc++.so.6
    #5  0x00007ffff7b0dd38 in ?? () from /usr/lib/x86_64-linux-gnu/libstdc++.so.6
    #6  0x00007ffff76296ba in start_thread (arg=0x7ffff6f4e700) at pthread_create.c:333
    #7  0x00007ffff735f41d in clone () at ../sysdeps/unix/sysv/linux/x86_64/clone.S:109
```

乍一看一切正常，我的程序在临死之前告诉我 vector 抛出了 std::out_of_range 异常。我简直被我的程序感动了。但是我想知道具体是那哪里抛出了异常。
让我们看看这个堆栈追踪，里面竟然没有一行是我的代码。虽然说在这个例子里面，直接看一眼代码你就可以看出来问题出现在哪里了，但是在我真正的项目里面有1万行 C++ 代码，我真的需要 GDB 来告诉我具体是在哪一行出了问题。
现在你应该明白为什么我对这个事情这么执着了。

## 系统库里面有 Bug？

坐在我边上的哥们 Niel 告诉我这有可能是因为底层的库里面有 bug。
说实话，我一般来说不相信编译器、操作系统或者底层库会出现大到足以影响到我日常使用的 bug。我觉得这几乎是不可能发生的事情，因为这些都是广泛使用的基础设施。
但是 Niel 说他以前有遇到过底层库的 bug，而且他说他愿意帮我看一下这个问题，而且他人又超级好的，所以我们就一起开始看这个问题了。

## 恢复 ?? 符号

盯着 GDB 里面的 ?? 符号看是不会有任何帮助的。所以我决定把这些符号的名字找出来。我自以为我对 Ubuntu 已经有了足够的了解，所以我很自然地就打出来了 `sudo apt install libstdc++-gdb`。然而这个包并不存在。我花了点时间才找到了这个包正确的名字叫做 libstdc++6-5-dbg，其中6对应了 libstdc++.so.6，5指的是 GCC 5.4，因为我用的是 Ubuntu 16.04。
在安装好了调试符号之后，GDB 就给了我们更多的线索：
```console
    $ gdb ./exception
    GNU gdb (Ubuntu 7.11.1-0ubuntu1~16.5) 7.11.1
    Reading symbols from ./exception...done.
    (gdb) r
    Starting program: /tmp/exception
    [Thread debugging using libthread_db enabled]
    Using host libthread_db library "/lib/x86_64-linux-gnu/libthread_db.so.1".
    [New Thread 0x7ffff6f4e700 (LWP 68314)]
    terminate called after throwing an instance of 'std::out_of_range'
      what():  vector::_M_range_check: __n (which is 100) >= this->size() (which is 0)
    
    Thread 2 "exception" received signal SIGABRT, Aborted.
    [Switching to Thread 0x7ffff6f4e700 (LWP 68314)]
    0x00007ffff728d428 in __GI_raise (sig=sig@entry=6) at ../sysdeps/unix/sysv/linux/raise.c:54
    54	../sysdeps/unix/sysv/linux/raise.c: No such file or directory.
    
    (gdb) bt
    #0  0x00007ffff728d428 in __GI_raise (sig=sig@entry=6) at ../sysdeps/unix/sysv/linux/raise.c:54
    #1  0x00007ffff728f02a in __GI_abort () at abort.c:89
    #2  0x00007ffff7ae484d in __gnu_cxx::__verbose_terminate_handler ()
        at ../../../../src/libstdc++-v3/libsupc++/vterminate.cc:95
    #3  0x00007ffff7ae26b6 in __cxxabiv1::__terminate (handler=<optimized out>)
        at ../../../../src/libstdc++-v3/libsupc++/eh_terminate.cc:47
    #4  0x00007ffff7ae2701 in std::terminate () at ../../../../src/libstdc++-v3/libsupc++/eh_terminate.cc:57
    #5  0x00007ffff7b0dd38 in std::execute_native_thread_routine (__p=<optimized out>)
        at ../../../../../src/libstdc++-v3/src/c++11/thread.cc:92
    #6  0x00007ffff76296ba in start_thread (arg=0x7ffff6f4e700) at pthread_create.c:333
    #7  0x00007ffff735f41d in clone () at ../sysdeps/unix/sysv/linux/x86_64/clone.S:109
```

# Glibc

我们决定跟着堆栈追踪从底向上地一层一层看过去。clone() 听起来并不十分有趣，所以我们就跳过了它。所以我们现在要看的是 pthread_create.c:333。一番搜索之后，我意识到了它是在 glibc 里面的。但是我用的是哪个版本的 glibc 呢？我的想法是用 ldd 先把 .so 文件找出来：

```console
    $ ldd ./exception
    	linux-vdso.so.1 =>  (0x00007ffc77f54000)
    	libstdc++.so.6 => /usr/lib/x86_64-linux-gnu/libstdc++.so.6 (0x00007f23ae730000)
    	libgcc_s.so.1 => /lib/x86_64-linux-gnu/libgcc_s.so.1 (0x00007f23ae51a000)
    	libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007f23ae150000)
    	libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6 (0x00007f23ade47000)
    	/lib64/ld-linux-x86-64.so.2 (0x00007f23aeab2000)
```

现在我们知道 .so 文件在哪里了，那具体是哪个版本呢？

```console
    $ ls -la /lib/x86_64-linux-gnu/libc.so.6
    lrwxrwxrwx 1 root root 12 Mar  4 18:36 /lib/x86_64-linux-gnu/libc.so.6 -> libc-2.23.so
```

好了，现在我们就可以在 glibc 2.23 的源代码里面看一眼 [pthread_create.c:333](https://sourceware.org/git/?p=glibc.git;a=blob;f=nptl/pthread_create.c;h=521604173325fdc222599f2902f4c1d796b8ef5d;hb=refs/heads/release/2.23/master#l333)：

```c
    THREAD_SETMEM (pd, result, CALL_THREAD_FCT (pd));  // pthread_create.c:333
```

现在我想知道 `CALL_THREAD_FCT` 是做什么的，这看起来像是一个宏，我得找到这个宏的定义：

```console
    $ grep '#define CALL_THREAD_FCT' -r glibc-2.23
    glibc-2.23/sysdeps/i386/nptl/tls.h:#define CALL_THREAD_FCT(descr) \
```

很幸运的是，这个符号真的是用 `#define CALL_THREAD_FCT` 定义出来的，但不幸的是我找到的结果跟我的机器并不是一个架构。但又非常幸运的是，我成功地猜到了我想要的在 `glibc-2.23/sysdeps/x86_64/nptl/tls.h`：
```c
    # define CALL_THREAD_FCT(descr) \
      ({ void *__res;                                                             \
         asm volatile ("movq %%fs:%P2, %%rdi\n\t"                                 \
                       "callq *%%fs:%P1"                                          \
                       : "=a" (__res)                                             \
                       : "i" (offsetof (struct pthread, start_routine)),          \
                         "i" (offsetof (struct pthread, arg))                     \
                       : "di", "si", "cx", "dx", "r8", "r9", "r10", "r11",        \
                         "memory", "cc");                                         \
         __res; })
```
我不太懂汇编，这看起来像是在调用 start_routine 并把 args 作为参数传进去。看起来也不是很有趣。
我们决定看一下下一层调用堆栈。

## libstdc++

所以说我们需要找到 libstdc++ 的源代码。我意识到 libstdc++ 其实是 GCC 的一部分，所以说我们需要的是 GCC 5.4 的源代码。让我们看一看 `../../../../../src/libstdc++-v3/src/c++11/thread.cc:92`：
```cpp
    extern "C"
    {
      static void*
      execute_native_thread_routine(void* __p)
      {
        thread::_Impl_base* __t = static_cast<thread::_Impl_base*>(__p);
        thread::__shared_base_type __local;
        __local.swap(__t->_M_this_ptr);
    
        __try
          {
            __t->_M_run();
          }
        __catch(const __cxxabiv1::__forced_unwind&)
          {
            __throw_exception_again;
          }
        __catch(...)
          {
            std::terminate();  // line 92
          }
    
        return nullptr;
      }
    } // extern "C"
```

当我打开这个文件的时候，我已经惊呆了。为什么 libstdc++ 想要捕获所有的异常？！就不能直接让用户程序崩溃吗！
这段代码说明了一切。我的代码肯定是跑在 `try` 代码块里面的。当它抛出一个异常之后，它会被92行的 `catch` 代码块捕获。但是到了程序的控制流已经被 `catch` 代码块捕获了的时候，所有的堆栈都已经被展开了 (stack unwind)，所有能帮助我调试程序的信息都被扔掉了。

# Bug 报告


对我来说这看起来可以被称作 libstdc++ 的 bug。我搜索了一下，然后发现有人在2013年就报告了这个 Bug #55917，但是这个问题直到 GCC 8 才被修复。而且补丁本身非常简单，就是把 try-catch 删掉，直接让用户代码崩溃。

## 升级到 GCC 8

既然我们知道了这个问题已经在 GCC 8 里面修好了，我们就可以重新把程序用 GCC 8 编译一遍。因为 Ubuntu 16.04 的软件源里面没有包含 GCC 8，所以我们得用 ubuntu-toolchain-r/test PPA:

```bash
    sudo add-apt-repository ppa:ubuntu-toolchain-r/test
    sudo apt-get update
    sudo apt-get install g++-8
```

现在让我们重新编译一下之前的代码然后放到 GDB 里面试试：
```console
    $ g++-8 -g -std=c++11 exception.cc -o exception -pthread
    $ gdb ./exception
    GNU gdb (Ubuntu 7.11.1-0ubuntu1~16.5) 7.11.1
    Reading symbols from ./exception...done.
    (gdb) r
    Starting program: /tmp/exception
    [Thread debugging using libthread_db enabled]
    Using host libthread_db library "/lib/x86_64-linux-gnu/libthread_db.so.1".
    [New Thread 0x7ffff6f42700 (LWP 69463)]
    terminate called after throwing an instance of 'std::out_of_range'
      what():  vector::_M_range_check: __n (which is 100) >= this->size() (which is 0)
    
    Thread 2 "exception" received signal SIGABRT, Aborted.
    [Switching to Thread 0x7ffff6f42700 (LWP 69463)]
    0x00007ffff7281428 in __GI_raise (sig=sig@entry=6) at ../sysdeps/unix/sysv/linux/raise.c:54
    54	../sysdeps/unix/sysv/linux/raise.c: No such file or directory.
    
    (gdb) bt
    #0  0x00007ffff7281428 in __GI_raise (sig=sig@entry=6) at ../sysdeps/unix/sysv/linux/raise.c:54
    #1  0x00007ffff728302a in __GI_abort () at abort.c:89
    #2  0x00007ffff7ad78f7 in ?? () from /usr/lib/x86_64-linux-gnu/libstdc++.so.6
    #3  0x00007ffff7adda46 in ?? () from /usr/lib/x86_64-linux-gnu/libstdc++.so.6
    #4  0x00007ffff7adda81 in std::terminate() () from /usr/lib/x86_64-linux-gnu/libstdc++.so.6
    #5  0x00007ffff7addcb4 in __cxa_throw () from /usr/lib/x86_64-linux-gnu/libstdc++.so.6
    #6  0x00007ffff7ad97f5 in ?? () from /usr/lib/x86_64-linux-gnu/libstdc++.so.6
    #7  0x0000000000401274 in std::vector<int, std::allocator<int> >::_M_range_check (this=0x7ffff6f41e00, __n=100)
        at /usr/include/c++/8/bits/stl_vector.h:960
    #8  0x0000000000401033 in std::vector<int, std::allocator<int> >::at (this=0x7ffff6f41e00, __n=100)
        at /usr/include/c++/8/bits/stl_vector.h:981
    #9  0x0000000000400dd7 in foo () at exception.cc:8
    #10 0x00000000004013a7 in std::__invoke_impl<void, void (*)()>(std::__invoke_other, void (*&&)()) (
        __f=<unknown type in /tmp/exception, CU 0x0, DIE 0x6a01>) at /usr/include/c++/8/bits/invoke.h:60
    #11 0x0000000000401093 in std::__invoke<void (*)()>(void (*&&)()) (__fn=<unknown type in /tmp/exception, CU 0x0, DIE 0x6e68>)
        at /usr/include/c++/8/bits/invoke.h:95
    #12 0x00000000004019da in std::thread::_Invoker<std::tuple<void (*)()> >::_M_invoke<0ul> (this=0x615c28)
        at /usr/include/c++/8/thread:234
    #13 0x000000000040199b in std::thread::_Invoker<std::tuple<void (*)()> >::operator() (this=0x615c28)
        at /usr/include/c++/8/thread:243
    #14 0x0000000000401970 in std::thread::_State_impl<std::thread::_Invoker<std::tuple<void (*)()> > >::_M_run (this=0x615c20)
        at /usr/include/c++/8/thread:186
    #15 0x00007ffff7b0857f in ?? () from /usr/lib/x86_64-linux-gnu/libstdc++.so.6
    #16 0x00007ffff761d6ba in start_thread (arg=0x7ffff6f42700) at pthread_create.c:333
    #17 0x00007ffff735341d in clone () at ../sysdeps/unix/sysv/linux/x86_64/clone.S:109
```
注意看堆栈9，里面就是我们的代码！问题解决了！

# 经验教训


尽管底层的软件和库自身的问题影响到一般的程序的可能性很低，但它确实发生了，而且未来还有可能继续发生。所以说，不要害怕去深入底层看一看。
最后再次感谢 Niel 老哥。要不是有他帮我，我肯定不会深挖这个问题的。