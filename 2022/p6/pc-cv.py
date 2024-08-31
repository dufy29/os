
"""
参照 pc-cv.c ,
构造 1p + 2c， 运行 model_check

python3  model-checker.py   ../p6/pc-cv.py

"""

class ProducerConsumer:
    locked, count, log, waits = '', 0, '', ''

    def tryacquire(self):
        self.locked, seen = '🔒', self.locked
        return seen == ''

    def release(self):
        self.locked = ''

    @thread
    def tp(self):
        for _ in range(2):
            while not self.tryacquire(): pass # mutex_lock()

            if self.count == 1:
                # cond_wait
                _, self.waits = self.release(), self.waits + '1'
                while '1' in self.waits: pass # 只要在等待队列里，不能继续执行
                while not self.tryacquire(): pass  # 重新获得互斥锁

            self.log, self.count = self.log + '(', self.count + 1
            self.waits = self.waits[1:] # cond_signal
            self.release() # mutex_unlock()

    @thread
    def tc1(self):
        while not self.tryacquire(): pass

        if self.count == 0:
            _, self.waits = self.release(), self.waits + '2'
            while '2' in self.waits: pass
            while not self.tryacquire(): pass

        self.log, self.count = self.log + ')', self.count - 1

        self.waits = self.waits[1:]
        self.release()

    @thread
    def tc2(self):
        while not self.tryacquire(): pass

        if self.count == 0:
            _, self.waits = self.release(), self.waits + '3'
            while '3' in self.waits: pass
            while not self.tryacquire(): pass

        self.log, self.count = self.log + ')', self.count - 1

        self.waits = self.waits[1:]
        self.release()

    @marker
    def mark_negative(self, state):
        count = 0
        for ch in self.log:
            if ch == '(': count += 1
            if ch == ')': count -= 1
            if count < 0: return 'red'
