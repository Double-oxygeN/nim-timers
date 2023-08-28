discard """
  target: "c"
  matrix: "--mm:orc;--mm:orc -d:nimStressOrc;--mm:refc"
  output: '''
0 pending
1 completed
1 completed
'''
"""

import std/asyncdispatch
import timers

var x = 0

let timer = execAfter(100) do ():
  inc x

waitFor sleepAsync(90)
echo x, " ", timer.status
waitFor sleepAsync(20)
echo x, " ", timer.status
waitFor sleepAsync(100)
echo x, " ", timer.status
