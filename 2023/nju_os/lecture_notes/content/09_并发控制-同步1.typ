#import "../template.typ": *
#pagebreak()
= 并发控制：同步 (1)

== 同步问题

=== 同步 (Synchronization)

两个或两个以上随时间变化的量在变化过程中保持一定的相对关系

- 同步电路 (一个时钟控制所有触发器)
- iPhone/iCloud 同步 (手机 vs 电脑 vs 云端)
- 变速箱同步器 (合并快慢速齿轮)
- 同步电机 (转子与磁场转速一致)
- 同步电路 (所有触发器在边沿同时触发)

异步 (Asynchronous) = 不需要同步

- 上述很多例子都有异步版本 (异步电机、异步电路、异步线程)

=== 并发程序中的同步

并发程序的步调很难保持 “完全一致”

- 线程同步： *在某个时间点共同达到互相已知的状态*

再次把线程想象成我们自己

- NPY：等我洗个头就出门/等我打完这局游戏就来
- 舍友：等我修好这个 bug 就吃饭
- 导师：等我出差回来就讨论这个课题
- jyy: 等我成为卷王就躺平
  - “先到先等”， *在条件达成的瞬间再次恢复并行* 
  #tip("Tip")[
  线程的`join`, 就是一个同步
  ]
  - 同时开始出去玩/吃饭/讨论

=== 生产者-消费者问题：学废你就赢了

99% 的实际并发问题都可以用生产者-消费者解决。

```c
void Tproduce() { while (1) printf("("); }
void Tconsume() { while (1) printf(")"); }
```

在 `printf` 前后增加代码，使得打印的括号序列满足

- 一定是某个合法括号序列的前缀
- 括号嵌套的深度不超过 n
  - n=3, `((())())(((` 合法
  - n=3, `(((())))`, `(()))` 不合法 
  #tip("Tip")[
  `push` > `pop`
  ]

生产者-消费者问题中的同步

- `Tproduce`: 等到有空位时才能打印左括号
- `Tconsume`: 等到有多余的左括号时才能打印右括号

=== 计算图、调度器和生产者-消费者问题

为什么叫 “生产者-消费者” 而不是 “括号问题”？

- "(": 生产资源 (任务)、放入队列(push)
- ")": 从队列取出资源 (任务) 执行(pop)

并行计算基础：计算图

- 计算任务构成有向无环图
  - $(u,v) \in E$表示 u 要用到前 v 的值
- 只要调度器 (生产者)
  分配任务效率够高，算法就能并行(执行任务的时间远远比push和pop的时间长)
  - 生产者把任务放入队列中
  - 消费者 (workers) 从队列中取出任务

#image("./images/computional graph.png")

#tip("Tip")[
- 还是需要6步才能算完。 
- 把任何一个问题并行化，画出计算图。（万能方法）
]

```
Tproduce
t1  (   )(join)
t2  ((   ))(join)
t3  (((   )))(join)
```
#tip("Tip")[
线程t2要在t1结束后才能执行。拓扑排序。
]

实际上,
如果计算量小的话划分可以更灵活一点.例如把左上角三个节点划分成一个。如果节点太多，也可以分得更细一些。

=== 生产者-消费者：实现

能否用互斥锁实现括号问题？

- 左括号：嵌套深度 (队列) 不足 n 时才能打印
- 右括号：嵌套深度 (队列) > 1 时才能打印
  - 当然是等到满足条件时再打印了 (代码演示) - 用互斥锁保持条件成立

并发：小心！

- 压力测试 + 观察输出结果
- 自动观察输出结果：[ pc-check.py
  ](https://jyywiki.cn/pages/OS/2023/c/pc-check.py)
- 未来：copilot 观察输出结果，并给出修复建议
- 更远的未来：我们都不需要不存在了

pc-mutex.c

```c
int n, count = 0;
mutex_t lk = MUTEX_INIT();

#define CAN_PRODUCE (count < n)
#define CAN_CONSUME (count > 0)

void Tproduce() {
    while (1) {
    retry:
        mutex_lock(&lk);
        if (!CAN_PRODUCE) {
            mutex_unlock(&lk);
            goto retry;
        } else {
            count++;
            printf("(");  // Push an element into buffer
            mutex_unlock(&lk);
        }
    }
}

void Tconsume() {
    while (1) {
    retry:
        mutex_lock(&lk);
        if (!CAN_CONSUME) {
            mutex_unlock(&lk);
            goto retry;
        } else {
            count--;
            printf(")");  // Pop an element from buffer
            mutex_unlock(&lk);
        }
    }
}

int main(int argc, char *argv[]) {
    assert(argc == 2);
    n = atoi(argv[1]);
    setbuf(stdout, NULL);
    for (int i = 0; i < 8; i++) {
        create(Tproduce);
        create(Tconsume);
    }
}
```

- `gcc -pthread pc-mutex.c`
  - `./a.out 1`
  - `./a.out 2`

如何知道是否正确呢？

== 条件变量

刚刚的实现里面依然有一个spin的过程，浪费CPU资源 
#tip("Tip")[
自旋锁的时候避免浪费， 得不到锁就放弃CPU。
]

=== 同步问题：分析

#tip("Tip")[
线程同步由条件不成立等待和同步条件达成继续构成
]

线程 join

- Tmain 同步条件：`nexit == T`
- Tmain 达成同步：最后一个线程退出 `nexit++`

生产者/消费者问题

- Tproduce 同步条件：`CAN_PRODUCE (count < n)`
- Tproduce 达成同步：`Tconsume count--`
- Tconsume 同步条件：`CAN_CONSUME (count > 0)`
- Tconsume 达成同步：`Tproduce count++`

=== 理想中的同步 API

```c
wait_until(CAN_PRODUCE) {
  count++;
  printf("(");
}

wait_until(CAN_CONSUME) {
  count--;
  printf(")");
}
```

若干实现上的难题

- 正确性
  - 大括号内代码执行时，其他线程不得破坏等待的条件
- 性能
  - 不能 spin check 条件达成
  - 已经在等待的线程怎么知道条件被满足？

=== 条件变量：理想与实现之间的折衷

一把互斥锁 + 一个 “条件变量” + 手工唤醒

- `wait(cv, mutex)` 💤
  - 调用时必须保证已经获得 mutex
  - wait 释放 mutex、进入睡眠状态
  - 被唤醒后需要重新执行 lock(mutex)
- `signal`/`notify(cv)` 💬
  - 随机私信一个等待者：醒醒
  - 如果有线程正在等待 cv，则唤醒其中一个线程
- `broadcast`/`notifyAll(cv)` 📣
  - 叫醒所有人
  - 唤醒全部正在等待 cv 的线程

==== 条件变量：实现生产者-消费者

错误实现：

```c
void Tproduce() {
  mutex_lock(&lk);
  if (!CAN_PRODUCE) cond_wait(&cv, &lk);
  printf("("); count++; cond_signal(&cv);
  mutex_unlock(&lk);
}

void Tconsume() {
  mutex_lock(&lk);
  if (!CAN_CONSUME) cond_wait(&cv, &lk);
  printf(")"); count--; cond_signal(&cv);
  mutex_unlock(&lk);
}
```

#tip("Tip")[
生产者和消费者一多就错了。
]

#image("./images/wrong-TC.png")

#tip("Tip")[
错误原因，`if`条件里，等待被唤醒的时候if条件未必依然成立。把`if`->`while`
]

代码演示 & 压力测试 & 模型检验

(Small scope hypothesis)

==== 条件变量：正确的打开方式

同步的本质：`wait_until(COND) { ... }`，因此：

需要等待条件满足时

```c
mutex_lock(&mutex);
while (!COND) { // 2
  wait(&cv, &mutex);    // 1
}
assert(cond);  // 互斥锁保证条件成立 3
mutex_unlock(&mutex);
```

任何改动使其他线可能被满足时

```c
mutex_lock(&mutex);
// 任何可能使条件满足的代码
broadcast(&cv);
mutex_unlock(&mutex);
```

绝对不会犯错：条件不成立的时候while等待，条件成立的时候broadcast

== 条件变量：应用

=== 条件变量：万能并行计算框架 (M2)

```c
struct work {
  void (*run)(void *arg);
  void *arg;
}

void Tworker() {
  while (1) {
    struct work *work;
    wait_until(has_new_work() || all_done) {
      work = get_work();
    }
    if (!work) break;
    else {
      work->run(work->arg); // 允许生成新的 work (注意互斥)
      release(work);  // 注意回收 work 分配的资源
    }
  }
}
```

=== 条件变量：更古怪的习题/面试题

有三种线程

- Ta 若干: 死循环打印 <
- Tb 若干: 死循环打印 >
- Tc 若干: 死循环打印 \_

任务：

- 对这些线程进行同步，使得屏幕打印出 `<><_` 和 `><>_` 的组合

解决同步问题， 回归本质`wait_until (cond) with (mutex)`使用条件变量，只要回答三个问题：

- 打印 “<” 的条件？
- 打印 “>” 的条件？
- 打印 “\_” 的条件？

状态机。
#image("./images/fish-SM.png")

```c
#define LENGTH(arr) (sizeof(arr) / sizeof(arr[0]))

enum {
    A = 1,
    B,
    C,
    D,
    E,
    F,
};

struct rule {
    int from, ch, to;
} rules[] = {
    {A, '<', B}, {B, '>', C}, {C, '<', D}, {A, '>', E},
    {E, '<', F}, {F, '>', D}, {D, '_', A},
};
int current = A, quota = 1;

mutex_t lk = MUTEX_INIT();
cond_t cv = COND_INIT();

int next(char ch) {
    for (int i = 0; i < LENGTH(rules); i++) {
        struct rule *rule = &rules[i];
        if (rule->from == current && rule->ch == ch) {
            return rule->to;
        }
    }
    return 0;
}

static int can_print(char ch) { return next(ch) != 0 && quota > 0; }

void fish_before(char ch) {
    mutex_lock(&lk);
    while (!can_print(ch)) {
        // can proceed only if (next(ch) && quota)
        cond_wait(&cv, &lk);
    }
    quota--;
    mutex_unlock(&lk);
}

void fish_after(char ch) {
    mutex_lock(&lk);
    quota++;
    current = next(ch);
    assert(current);
    cond_broadcast(&cv);
    mutex_unlock(&lk);
}

const char roles[] = ".<<<<<>>>>___";

void fish_thread(int id) {
    char role = roles[id];
    while (1) {
        fish_before(role);
        putchar(role);  // Not lock-protected
        fish_after(role);
    }
}

int main() {
    setbuf(stdout, NULL);
    for (int i = 0; i < strlen(roles); i++) create(fish_thread);
}
```

只要写出`can_print`函数，就ok。

== 总结

=== 把任何算法并行：计算图。

不管什么计算问题，都是由x算出y，接着画出计算图。

例如处理器的乱序执行，`x=0`,`y=2`,`t=x`.把每个指令看成一个节点。t和x形成一个依赖关系，RAW（Read
After Write），建立了一条边。其实就是拓扑排序，但是用硬件。

=== 实现同步：生产者消费者

任何一个线程总要做一件事，但是这个事儿不能随便做，要等条件满足的时候才可以。把多线程同步，这段代码执行的条件是什么，用万能的互斥锁。

并行不都丢掉了？计算图的时候，节点的本地计算远大于同步或者互斥的开销。
