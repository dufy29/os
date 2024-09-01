#import "../template.typ": *
#pagebreak()
= 多处理器编程：从入门到放弃

== 多处理器编程入门

=== Three Easy Pieces: 并发

操作系统作为 “状态机的管理者”，引入了共享的状态

- 带来了并发
- (操作系统是最早的并发程序)

```py
def Tprint(name):
    sys_write(f'{name}')

def main():
    for name in 'AB':
        sys_spawn(Tprint, name)

= Outputs:
= AB
= BA
```

使用 model checker 绘制状态图

=== 多线程共享内存并发

线程：共享内存的执行流

- 执行流拥有独立的堆栈/寄存器

简化的线程 API (thread.h)

- `spawn(fn)` - 创建一个入口函数是 fn 的线程，并立即开始执行 - `void fn(int tid) { ... }` -
  参数 tid 从 1 开始编号 行为：`sys_spawn(fn, tid)`
- `join()`
  - 等待所有运行线程的返回 (也可以不调用)
  - 行为：`while (done != T) sys_sched()`

=== 多线程共享内存并发：入门

多处理器编程：一个 API 搞定

```c
#include "thread.h"

void Ta() { while (1) { printf("a"); } }
void Tb() { while (1) { printf("b"); } }

int main() {
  create(Ta);
  create(Tb);
}
```

- 这个程序可以利用系统中的多处理器
  - 操作系统会自动把线程放置在不同的处理器上
  - CPU 使用率超过了 100%

==== demo

```c
#include "thread.h"

void Thello(int id) {
    while (1) {
        // printf("%c", "_ABCDEFGHIJKLMNOPQRSTUVWXYZ"[id]);
    }
}

int main() {
    for (int i = 0; i < 2; i++) {
        spawn(Thello);
    }
}
```

`gcc hello.c && ./a.out`, 接着`htop`可以看到占用了 200% 的 cpu, 把循环次数改成 3
就变成了 300% .

=== 问出更多的问题

_问一个好的问题再去寻找答案, 这个比单纯地学习知识效率更高._

==== 证明共享内存

`Ta` 和 `Tb` 真的共享内存吗？ 如何证明/否证这件事？

`shared_men.c`

```c
#include "thread.h"

int x = 0;

void Thello(int id) {
    x++;
    printf("%d\n", x);
}

int main() {
    for (int i = 0; i < 10; i++) {
        spawn(Thello);
    }
}
```

output:

```sh
❯ gcc hello.c && ./a.out
1
3
2
5
4
6
7
8
9
10
```

==== 如何证明线程具有独立堆栈 (以及确定堆栈的范围)？

单线程的堆栈:

```
| stack      |
| stack down |
| heap up    |
| heap       |
| code       |
```

```c
#include "thread.h"

void add(int n) {
    int x = 0;
    x++;
    printf("x: %d\n", x);
}

int main(int argc, char *argv[]) {
    for (int i = 0; i < 10; i++) {
        spawn(add);
    }
    return 0;
}
```

output:

```sh
> gcc indp_stk.c && ./a.out
x: 1
x: 1
x: 1
x: 1
x: 1
x: 1
x: 1
x: 1
x: 1
x: 1
```

==== 线程的堆栈在哪?多大? 写一个程序来确定!(无穷递归!爆栈)

stack-probe.c

```c
#include "thread.h"

void *volatile low[64];
void *volatile high[64];

void update_range(int T, void *ptr) {
    if (ptr < low[T]) low[T] = ptr;
    if (ptr > high[T]) high[T] = ptr;
}

void probe(int T, int n) {
    update_range(T, &n);
    long sz = (uintptr_t)high[T] - (uintptr_t)low[T];
    if (sz % 1024 < 32) {
        printf("Stack(T%d) >= %ld KB\n", T, sz / 1024);
    }
    probe(T, n + 1);  // Infinite recursion
}

void Tprobe(int T) {
    low[T] = (void *)-1;
    high[T] = (void *)0;
    update_range(T, &T);
    probe(T, 0);
}

int main() {
    setbuf(stdout, NULL);
    for (int i = 0; i < 4; i++) {
        create(Tprobe);
    }
}
```

===== `setbuf`?

```c
int main(){
    printf("%d",1);
    crash();
}
```

为什么`1`打印不出来? 如果`printf("%d",1);`换成`printf("%d\n",1);`就可以打印出来.
OS 会给出答案!

- 对于终端（包括
  stdin、stdout）等交互式设备，通常采用行缓冲：即只有当遇到换行符或者缓冲区满时，才会进行实际的输入/输出操作。
- 对于其他非交互式设备（如文件、管道等），通常采用全缓冲：即只有当缓冲区满时，才会进行实际的输入/输出操作。

`setbuf` 是 C 语言标准库中的一个函数，用于设置文件流的缓冲策略。其原型如下：

```c
void setbuf(FILE *stream, char *buffer);
```

1. `stream`：这是一个指向 `FILE` 类型的指针，表示要设置缓冲策略的文件流。
2. `buffer`：这是一个指向字符的指针，表示要用作缓冲区的内存地址。如果这个参数为 `NULL`，那么 `stream` 将不会有缓冲区，也就是说，每次读写操作都会直接对文件进行。

在 C 语言中，文件 I/O 操作通常是缓冲的, 即当你调用一个输出函数（比如 `printf` 或 `putchar`）时，数据并不是立即写入文件，而是先写入一个缓冲区。只有当缓冲区满了，或者你显式地刷新缓冲区（比如通过调用 `fflush`），数据才会真正写入文件。

#tip("Tip")[
需要注意的是，`setbuf` 必须在打开文件流后、进行任何其他操作前调用。否则，其行为是未定义的。
]

```c
#include <stdio.h>
int main(int argc, char *argv[]) {
    setbuf(stdout, NULL);
    void *ptr = 0;
    printf("%d", 1);
    printf("%d", *(int *)ptr);
    return 0;
}
```

这样`1`不需要换行符也可以被成功打印出来了!

===== continue stack-probe

```c
void *volatile low[64];
void *volatile high[64];
```

假设不超过 64 个线程, `low`代表看见的最低的地址的位置, `high`代表看见的最高的地址的位置.

```c
void update_range(int T, void *ptr) {
    if (ptr < low[T]) low[T] = ptr;
    if (ptr > high[T]) high[T] = ptr;
}

void probe(int T, int n) {
    update_range(T, &n);
    long sz = (uintptr_t)high[T] - (uintptr_t)low[T];
    if (sz % 1024 < 32) {
        printf("Stack(T%d) >= %ld KB\n", T, sz / 1024);
    }
    probe(T, n + 1);  // Infinite recursion
}

void Tprobe(int T) {
    low[T] = (void *)-1;
    high[T] = (void *)0;
    update_range(T, &T);
    probe(T, 0);
}
```

`Tprobe` 中调用`Tprobe`赋初值, low 是当前看到的最低地址的位置, `high`是当前看到的最高地址的位置.

`update_range` 函数的参数 `ptr` 是一个指向某个内存地址的指针。这个函数的目的是更新线程 `T` 的栈的最低和最高地址。

当你在 `probe` 函数中调用 `update_range(T, &n);` 时，`&n` 是局部变量 `n` 在栈上的地址。因为每次递归调用 `probe` 都会创建一个新的 `n` 变量，所以 `n` 的地址可以用来追踪栈的增长。
回到 `update_range` 函数，如果传入的 `ptr` 指向的地址比当前线程的栈的最低地址还要低，那么就将 `low[T]` 更新为 `ptr`。同样，如果 `ptr` 指向的地址比当前线程的栈的最高地址还要高，那么就将 `high[T]` 更新为 `ptr`。
总的来说，`ptr` 参数的作用是提供一个参考点，用于更新线程 `T` 的栈的最低和最高地址。通过这种方式，程序可以追踪每个线程栈的使用情况。

```sh
gcc stack-probe.c && ./a.out | grep T1 | sort -nk3
```

可以看到 8192KB, 但是 8192KB 不总是够用的, 于是可以进一步配置线程栈的大小.

- 更多的 “好问题” 和解决
  - 创建线程使用的是哪个系统调用？
    - 能不能用 gdb 调试？
    - 基本原则：有需求，就能做到 ([ RTFM
      ](https://sourceware.org/gdb/onlinedocs/gdb/Threads.html))

=== thread.h 背后：POSIX Threads

想进一步配置线程？

- 设置更大的线程栈
- 设置 detach 运行 (不在进程结束后被杀死，也不能 join)
- ……

POSIX 为我们提供了线程库 (pthreads)

- `man 7 pthreads`
- 练习：改写 thread.h，使得线程拥有更大的栈
  - 可以用 stack probe 的程序验证

== 放弃 (1)：原子性

=== 状态机的隐含假设

“世界上只有一个状态机”

- 没有其他任何人能 “干涉” 程序的状态
  - 推论：对变量的 load 一定返回本线程最后一次 store 的值
  - 这也是编译优化的基本假设

```c
int i = 0;

// assume i==0;
for(; i < n; i++){
}
```

但*共享内存*推翻了这个假设

```c
int Tworker() {
  printf("%d\n", x);  // Global x
  printf("%d\n", x);
}
```

- 其他线程随时可以修改 `x`
  - 导致两次可能读到不同的 `x`

=== 潘多拉的魔盒已经打开……

两个线程并发支付 ¥100 会发生什么 (代码演示)

```c
#include "thread.h"

unsigned long balance = 100;

void Alipay_withdraw(int amt) {
    if (balance >= amt) {
        usleep(1);  // Unexpected delays
        balance -= amt;
    }
}

void Talipay(int id) { Alipay_withdraw(100); }

int main() {
    create(Talipay);
    create(Talipay);
    join();
    printf("balance = %lu\n", balance);
}
```

```sh
❯ gcc alipay.c && ./a.out
balance = 18446744073709551516
```

- 账户里会多出用不完的钱！
- Bug/漏洞不跟你开玩笑：Mt. Gox Hack 损失 650,000 BTC
  - 时值 ~\$28,000,000,000

    ```c
    create(Talipay);
    ```

    会发生什么？正常

    ```c
    create(Talipay);
    join();
    create(Talipay);
    join();
    ```

    会发生什么？正常

#example("求和")[
分两个线程，计算 `1+1+1+…+1` (共计 `2n` 个 `1`)

```c
#define N 100000000
long sum = 0;

void Tsum() { for (int i = 0; i < N; i++) sum++; }

int main() {
create(Tsum);
create(Tsum);
join();
printf("sum = %ld\n", sum);
}
```

可能的结果

- `119790390`, `99872322` (结果可以比 `N` 还要小), ...
- 直接使用汇编指令也不行
]

=== 放弃 (1)：指令/代码执行原子性假设

_“处理器一次执行一条指令” 的基本假设在今天的计算机系统上不再成立 (我们的模型作出了简化的假设)。_

- 单处理器多线程
- 线程在运行时可能被中断，切换到另一个线程执行
- 多处理器多线程
- 线程根本就是并行执行的
- (历史) 1960s，大家争先在共享内存上实现原子性 (互斥)
- 但几乎所有的实现都是错的，直到 #link("https://en.wikipedia.org/wiki/Dekker's_algorithm")[ Dekker's Algorithm ]，还只能保证两个线程的互斥

=== 放弃原子性假设的后果

我们都知道 `printf` 是有缓冲区的 (为什么？), 那`printf` 还能在多线程程序里调用吗？如果执行 `buf[pos++] = ch` (`pos` 共享) 不就 💥 了吗？

```c
void thread1() { while (1) { printf("a"); } }
void thread2() { while (1) { printf("b"); } }
```

RTFM! -> 我们发现`printf`是thread safe的.

== 放弃 (2)：执行顺序

=== 例子：求和 (再次出现)

分两个线程，计算 1+1+1+…+1 (共计 2n 个 1)

```c
#define N 100000000
long sum = 0;

void Tsum() { for (int i = 0; i < N; i++) sum++; }

int main() {
create(Tsum);
create(Tsum);
join();
printf("sum = %ld\n", sum);
}
```

如果添加编译优化？

- -O1: 100000000 😱😱
- -O2: 200000000 😱😱😱

`gcc -O1 sum.c && objdump -d ./a.out > O1.txt`
`gcc -O2 sum.c && objdump -d ./a.out > O2.txt`

O1.txt:

```
000000000000117f <Tsum>:
117f: 48 8b 15 da 2e 00 00 mov 0x2eda(%rip),%rdx = 4060 <sum>

1186: 48 8d 42 01 lea 0x1(%rdx),%rax
118a: 48 81 c2 01 e1 f5 05 add $0x5f5e101,%rdx 1191: 48 89 c1 mov %rax,%rcx
1194: 48 83 c0 01 add $0x1,%rax
1198: 48 39 d0 cmp %rdx,%rax
119b: 75 f4 jne 1191 <Tsum+0x12>

119d: 48 89 0d bc 2e 00 00 mov %rcx,0x2ebc(%rip) = 4060 <sum>
11a4: c3 ret
```

中间是个循环， 循环完之后再赋值

```
%rdx = sum

loop

sum = %rcx
```

O2.txt:

```
00000000000011e0 <Tsum>:
11e0: 48 81 05 75 2e 00 00 addq $0x5f5e100,0x2e75(%rip) = 4060 <sum> 11e7: 00 e1
f5 05 11eb: c3 ret 11ec: 0f 1f 40 00 nopl 0x0(%rax)
```

直接赋值, 循环都没了。

```
sum += 0x5f5e100 ret
```

#tip("Tip")[
不同的编译器也许是不同地结果。
]

=== 放弃 (2)：程序的顺序执行假设

_编译器对内存访问 “eventually consistent” 的处理导致共享内存作为线程同步工具的失效。_

刚才的例子:

- -O1: `R[eax] = sum; R[eax] += N; sum = R[eax]`
- -O2: `sum += N;`
- (你的编译器也许是不同的结果)

另一个例子

```c while (!done);// would be optimized to
if (!done) while (1);
```

==== 保证执行顺序

回忆 “编译正确性”

- C 状态和汇编状态机的 “可观测行为等价”
- 方法 1：插入 “不可优化” 代码
  - `asm volatile ("" ::: "memory");`
    - “Clobbers memory”(该位置上可能有其他任何东西改变共享的内存值)
    ```c int x = 0; void Tsum() { x = 1; asm volatile("" ::: "memory"); x = 1; }
```
- 方法 2：标记变量 load/store 为不可优化

  - 使用 `volatile` 变量

    ```c extern int volatile done;

while (!done) ;
```

== 放弃 (3)：处理器间的可见性

#example("Example")[
```c int x = 0, y = 0;

void T1() { x = 1; int t = y;// Store(x); Load(y)
printf("%d", t); }

void T2() { y = 1; int t = x;// Store(y); Load(x)
printf("%d", t); }
```

遍历模型告诉我们：`01`, `10`, `11`

- 机器永远是对的
- Model checker 的结果和实际的结果不同 → 假设错了
]

=== 🌶️ 现代处理器也是 (动态) 编译器！

- 错误 (简化) 的假设: 一个 CPU 执行一条指令到达下一状态
- 实际的实现:电路将连续的指令 “编译” 成更小的 $μ$ ops
  - `RF[9] = load(RF[7] + 400)`
  - `store(RF[12], RF[13])`
  - `RF[3] = RF[4] + RF[5]`

在任何时刻，处理器都维护一个 $μ$op 的 “池子”

- 与编译器一样，做 “顺序执行” 假设：没有其他处理器 “干扰”
- 每一周期执行尽可能多的 $μ$op - 多路发射、乱序执行、按序提交
  #tip("Tip")[
  通过流水线可以实现IPC>1, 同时执行多个指令。
  ]

=== 放弃 (3)：多处理器间内存访问的即时可见性

_满足单处理器 eventual memory consistency 的执行，在多处理器系统上可能无法序列化！_

当 `x != y` 时，对 x, y 的内存读写可以交换顺序

- 它们甚至可以在同一个周期里完成 (只要 load/store unit 支持)
- 如果写 x 发生 cache miss，可以让读 y 先执行
  - 满足 “尽可能执行 $μ$op” 的原则，最大化处理器性能

```
= <-----------+
movl $1, (x) = |
movl (y), %eax = --+
```

- 在多处理器上的表现
- 两个处理器分别看到 y=0 和 x=0

```
cpu1 cpu2 cpu3 cpu4
1:x=1 2:x=2 load(x) load(x)
=2 =1
=1 =2
```

=== 宽松内存模型 (Relaxed/Weak Memory Model)

_宽松内存模型的目的是使单处理器的执行更高效。_

目前各大架构的系统模拟器最困难的地方就是模拟内存模型, 他们不知道哪个地方会被插入执行， 只能每行代码都加一个`fence`。

#tip("Tip")[
x86 已经是市面上能买到的 “最强” 的内存模型了 😂
]

- 这也是 Intel 自己给自己加的包袱
- 看看 #link("https://research.swtch.com/mem-weak@2x.png")[ ARM/RISC-V ] 吧，根本就是个分布式系统
#image("images/2023-11-04-10-15-39.png")
#tip("Tip")[
- 通过队列, 可以看到total store order.
- 全局状态：`1 2`还是`2 1`
]

(x86-TSO in #link("https://research.swtch.com/hwmm")[ Hardware memory models ] by Russ Cox)
