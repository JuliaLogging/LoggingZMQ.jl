# ZMQLoggers

[![Test workflow status](https://github.com/JuliaLogging/ZMQLoggers.jl/actions/workflows/Test.yml/badge.svg?branch=main)](https://github.com/JuliaLogging/LoggingZMQ.jl/actions/workflows/Test.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaLogging/ZMQLoggers.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaLogging/LoggingZMQ.jl)
[![BestieTemplate](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/JuliaBesties/BestieTemplate.jl/main/docs/src/assets/badge.json)](https://github.com/JuliaBesties/BestieTemplate.jl)

This package provides a logger that writes its output to a ZMQ socket.

The logger is **not** thread safe because ZMQ sockets are not thread safe.

## Usage
```julia
import Logging
using ZMQLoggers
using ZMQ

ctx = Context()
addr = "inproc://logger"

receiver = Socket(ctx, SUB)
subscribe(receiver, "")
bind(receiver, addr)

logsock = Socket(ctx, PUB)
connect(logsock, addr)
logger = ZMQLogger(logsock, Logging.Info)

Logging.with_logger(logger) do
	@info "This is a test"
end
println(recv(receiver, String)) # This is a test
```
