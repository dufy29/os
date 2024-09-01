def main():
  x = sys_fork()
  sys_sched()
  y = sys_fork()
  sys_sched()
  sys_write(f'{x} {y}; ')

# Outputs:
# 0 0; 0 1003; 1002 0; 1002 1004;
# 0 0; 0 1003; 1002 1004; 1002 0;
# 0 0; 0 1004; 1002 0; 1002 1003;
# 0 0; 0 1004; 1002 1003; 1002 0;
# 0 0; 1002 0; 0 1003; 1002 1004;
# 0 0; 1002 0; 0 1004; 1002 1003;
# 0 0; 1002 0; 1002 1003; 0 1004;
# 0 0; 1002 0; 1002 1004; 0 1003;
# 0 0; 1002 1003; 0 1004; 1002 0;
# 0 0; 1002 1003; 1002 0; 0 1004;
# 0 0; 1002 1004; 0 1003; 1002 0;
# 0 0; 1002 1004; 1002 0; 0 1003;
# 0 1003; 0 0; 1002 0; 1002 1004;
# 0 1003; 0 0; 1002 1004; 1002 0;
# 0 1003; 1002 0; 0 0; 1002 1004;
# 0 1003; 1002 0; 1002 1004; 0 0;
# 0 1003; 1002 1004; 0 0; 1002 0;
# 0 1003; 1002 1004; 1002 0; 0 0;
# 0 1004; 0 0; 1002 0; 1002 1003;
# 0 1004; 0 0; 1002 1003; 1002 0;
# 0 1004; 1002 0; 0 0; 1002 1003;
# 0 1004; 1002 0; 1002 1003; 0 0;
# 0 1004; 1002 1003; 0 0; 1002 0;
# 0 1004; 1002 1003; 1002 0; 0 0;
# 1002 0; 0 0; 0 1003; 1002 1004;
# 1002 0; 0 0; 0 1004; 1002 1003;
# 1002 0; 0 0; 1002 1003; 0 1004;
# 1002 0; 0 0; 1002 1004; 0 1003;
# 1002 0; 0 1003; 0 0; 1002 1004;
# 1002 0; 0 1003; 1002 1004; 0 0;
# 1002 0; 0 1004; 0 0; 1002 1003;
# 1002 0; 0 1004; 1002 1003; 0 0;
# 1002 0; 1002 1003; 0 0; 0 1004;
# 1002 0; 1002 1003; 0 1004; 0 0;
# 1002 0; 1002 1004; 0 0; 0 1003;
# 1002 0; 1002 1004; 0 1003; 0 0;
# 1002 1003; 0 0; 0 1004; 1002 0;
# 1002 1003; 0 0; 1002 0; 0 1004;
# 1002 1003; 0 1004; 0 0; 1002 0;
# 1002 1003; 0 1004; 1002 0; 0 0;
# 1002 1003; 1002 0; 0 0; 0 1004;
# 1002 1003; 1002 0; 0 1004; 0 0;
# 1002 1004; 0 0; 0 1003; 1002 0;
# 1002 1004; 0 0; 1002 0; 0 1003;
# 1002 1004; 0 1003; 0 0; 1002 0;
# 1002 1004; 0 1003; 1002 0; 0 0;
# 1002 1004; 1002 0; 0 0; 0 1003;
# 1002 1004; 1002 0; 0 1003; 0 0;
