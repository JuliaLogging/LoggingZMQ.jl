# LoggingZMQ.jl

This package provides a logger that writes its output to a ZMQ socket.

The logger is **not** thread safe because ZMQ sockets are not thread safe.

## Usage
```julia
import Logging
using LoggingZMQ
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
