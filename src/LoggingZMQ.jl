module LoggingZMQ

import Logging
import ZMQ

export ZMQLogger

"""
Logger that sends logs data over a zmq socket.
"""
struct ZMQLogger <: Logging.AbstractLogger
    sock::ZMQ.Socket
    lock::ReentrantLock
    min_level::Base.CoreLogging.LogLevel
    message_limits::Dict{Any, Int}
end

function ZMQLogger(sock, min_level, message_limits)
    return ZMQLogger(sock, ReentrantLock(), min_level, message_limits)
end

function ZMQLogger(sock, min_level)
    return ZMQLogger(sock, ReentrantLock(), min_level, Dict{Any, Int}())
end

function Logging.min_enabled_level(logger::ZMQLogger)
    return logger.min_level
end

function Logging.shouldlog(logger::ZMQLogger, level, _module, group, id)
    return @lock logger.lock get(logger.message_limits, id, 1) > 0
end

function Logging.catch_exceptions(::ZMQLogger)
    return false
end

function Logging.handle_message(logger::ZMQLogger, lvl::Logging.LogLevel, msg, _mod, group, id, file, line; kwargs...)
    @nospecialize
    maxlog = get(kwargs, :maxlog, nothing)
    if maxlog isa Core.BuiltinInts
        @lock logger.lock begin
            remaining = get!(logger.message_limits, id, Int(maxlog)::Int)
            remaining == 0 && return
            logger.message_limits[id] = remaining - 1
        end
    end
    sock::ZMQ.Socket = logger.sock
    @lock logger.lock begin
        ZMQ.send(sock, string(msg))
    end
    return nothing
end

end # module LoggingZMQ
