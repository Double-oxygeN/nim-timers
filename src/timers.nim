import std/asyncdispatch

## Timer Utilities
## ===============
##
## :Author: Double-oxygeN
##
## This module provides asynchronous timers.
## The action is executed in a separate thread, so you must be careful about thread safety.
##
## Scheduled action
## ----------------
##
## `doAfter` proc schedules an action to be executed after a given delay.
## This is inspired by the `setTimeout` function in JavaScript.
runnableExamples:
  discard doAfter(1_000) do ():
    # This code will be executed after 1 second.
    echo "Ring!"

## `doAfter` returns a `ScheduledTimer` object that can be used to cancel the action.
runnableExamples:
  let timer = doAfter(1_000) do ():
    echo "Ring!"

  timer.cancel()
  # If the timer has not expired yet, the action will not be executed anymore.

## Periodic action
## ---------------
##
## `doEvery` proc schedules an action to be executed periodically.
## This is inspired by the `setInterval` function in JavaScript.
## Note that the first execution is delayed by the given delay.
runnableExamples:
  discard doEvery(1_000) do ():
    # This code will be executed every second.
    echo "Ring!"
## `doEvery` returns a `PeriodicTimer` object that can be used to cancel the action.
runnableExamples:
  let timer = doEvery(1_000) do ():
    echo "Ring!"

  timer.cancel()
  # The action will not be executed anymore.

type
  TimerStatus* {.pure.} = enum
    pending   ## The action is not executed yet.
    running   ## The action is being executed.
    cancelled ## The action is cancelled or expired.
    completed ## The action is completed.

  TimerEvent {.pure.} = enum
    alarm
    cancel

  TimerBase = object of RootObj
    status: ptr TimerStatus
    action: (proc () {.closure, gcsafe.})
    chan: ptr Channel[TimerEvent]

  ScheduledTimer* = ref object of TimerBase
    delay: Natural
    timerThread, actionThread: Thread[ScheduledTimer]

  PeriodicTimer* = ref object of TimerBase
    period: Natural
    timerThread, actionThread: Thread[PeriodicTimer]


proc execAfter*(delay: Natural; action: proc () {.closure, gcsafe.}): ScheduledTimer =
  ## Schedules an action to be executed after a given delay.
  ## Returns a `ScheduledTimer` object that can be used to cancel the action.
  proc timerAction(self: ScheduledTimer) {.thread, nimcall.} =
    waitFor sleepAsync(self.delay)
    if not self.chan.isNil:
      self.chan[].send(TimerEvent.alarm)

  proc doAction(self: ScheduledTimer) {.thread, nimcall.} =
    case self.chan[].recv()
    of TimerEvent.alarm:
      self.status[] = TimerStatus.running
      self.action()
      self.status[] = TimerStatus.completed

    of TimerEvent.cancel:
      self.status[] = TimerStatus.cancelled

  result = ScheduledTimer(action: action, delay: delay)
  result.status = cast[ptr TimerStatus](allocShared0(sizeof(TimerStatus)))
  result.chan = cast[ptr Channel[TimerEvent]](allocShared0(sizeof(Channel[TimerEvent])))
  result.chan[].open(1)
  result.actionThread.createThread(doAction, result)
  result.timerThread.createThread(timerAction, result)


template doAfter*(delay: Natural; actionStmt: untyped): ScheduledTimer =
  ## Schedules an action to be executed after a given delay.
  ## This is just a shorthand for ``doAfter``.
  execAfter(delay, proc () = actionStmt)


proc execEvery*(period: Natural; action: proc () {.closure, gcsafe.}): PeriodicTimer =
  ## Schedules an action to be executed periodically.
  ## Returns a `PeriodicTimer` object that can be used to cancel the action.
  proc timerAction(self: PeriodicTimer) {.thread, nimcall.} =
    waitFor sleepAsync(self.period)
    while self.chan[].trySend(TimerEvent.alarm):
      waitFor sleepAsync(self.period)

  proc doAction(self: PeriodicTimer) {.thread, nimcall.} =
    while true:
      case self.chan[].recv()
      of TimerEvent.alarm:
        self.status[] = TimerStatus.running
        self.action()
        self.status[] = TimerStatus.pending

      of TimerEvent.cancel:
        self.status[] = TimerStatus.cancelled
        break

  result = PeriodicTimer(action: action, period: period)
  result.status = cast[ptr TimerStatus](allocShared0(sizeof(TimerStatus)))
  result.chan = cast[ptr Channel[TimerEvent]](allocShared0(sizeof(Channel[TimerEvent])))
  result.chan[].open(1)
  result.actionThread.createThread(doAction, result)
  result.timerThread.createThread(timerAction, result)


template doEvery*(period: Natural; actionStmt: untyped): PeriodicTimer =
  ## Schedules an action to be executed periodically.
  ## This is just a shorthand for ``doEvery``.
  execEvery(period, proc () = actionStmt)


proc cancel*(timer: ref TimerBase) =
  ## Cancels the action.
  ## If the action is already executed, this proc does nothing.
  timer.chan[].send(TimerEvent.cancel)


func status*(timer: ref TimerBase): TimerStatus =
  ## Returns the status of the timer.
  result = timer.status[]
