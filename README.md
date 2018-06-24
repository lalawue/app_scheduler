

[![MIT licensed][1]][2]

[1]: https://img.shields.io/badge/license-MIT-blue.svg
[2]: LICENSE






# About

app_scheduler was a app-group launcher and monitor, manage mutiple app
job as a group.

app jobs was started from Lua's os.execute() in background, so every app
job has its own working dir, shell env.

with jobs' PID, we can monitor the jobs with 'ps u -p PID1 -p PID2', get
every job's CPU, MEM usage, detect stopped jobs, or restart jobs.

all these defined in app jobs' spec, with pre-defined variables, launcher
and monitor functions.

support Linux/FreeBSD/macOS, Lua 5.2/5.3, LuaJIT-2.0.5, other version
and environment not test.




# Features

- launch, monitor app job in group
- independent working dir, shell env
- start/stop job dynamically
- monitor job's CPU, MEM, running or stopped state
- pure Lua/shell command





# Running Example

1. first comple busy_app_demo.c, then start 3 app jobs

```
# gcc -Wall -O2 busy_app_demo.c -o busy_app.out # cc in FreeBSD
# lua app_scheduler.lua start job_spec.lua &
```

2. try kill one of them with PID, cause all of 3 app jobs stop

```
# kill [one PID of busy_app.out]
```

or, to stop all 3 app jobs with

```
# lua app_scheduler.lua stop job_spec.lua
```

more in [job_spec.lua](https://github.com/lalawue/app_scheduler/blob/master/job_spec.lua).
