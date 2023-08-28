# Package

version       = "0.1.0"
author        = "Double-oxygeN"
description   = "Timer utilities"
license       = "Apache-2.0"
srcDir        = "src"


# Dependencies

requires "nim >= 2.0.0"

# Tasks

task test, "Run tests":
  exec "testament category /"
