discard """
  target: "c"
  matrix: "--mm:orc;--mm:orc -d:nimStressOrc;--mm:refc"
  output: '''
0 cancelled
'''
"""

import std/asyncdispatch
import timers

var x = 0

let timer = execEvery(100) do ():
  inc x

waitFor sleepAsync(90)
timer.cancel()
waitFor sleepAsync(20)
echo x, " ", timer.status
