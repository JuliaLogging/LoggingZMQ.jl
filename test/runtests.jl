import Base.Threads: @spawn
using LoggingZMQ
using ZMQ
using Test
import Logging
using Aqua

@testset "Aqua" begin
    Aqua.test_all(LoggingZMQ)
end

const ctx = Context()
const addr = "inproc://logger"
const timeout_sec = 30

# receiver is asynchronous to prevent tests from hanging
function spawn_receiver(ctx, addr, msg_list, c)
    return @spawn begin
        receiver = Socket(ctx, SUB)
        subscribe(receiver, "")
        connect(receiver, addr)
        for msg in msg_list
            r = recv(receiver, String)
            println("Got: " * r)
            println("Expected: " * msg)
            if r != msg
                close(receiver)
                put!(c, "Failed")
                return
            end
        end
        close(receiver)
        put!(c, "Ok")
        return
    end
end

function timeout(s, c)
    sleep(s)
    return put!(c, "Timeout")
end

@testset "Main" begin
    c = Channel{String}(2)
    test_task = spawn_receiver(ctx, addr, ["Error", "Warning", "Info", "Debug"], c)

    logsock = Socket(ctx, PUB)
    bind(logsock, addr)
    logger = ZMQLogger(logsock, Logging.BelowMinLevel)

    Logging.with_logger(logger) do
        Logging.@error "Error"
        Logging.@warn "Warning"
        Logging.@info "Info"
        Logging.@debug "Debug"
    end

    @spawn timeout(timeout_sec, c)
    @test take!(c) == "Ok"

    c = Channel{String}(2)
    test_task = spawn_receiver(ctx, addr, ["Error", "Warning"], c)
    logger = ZMQLogger(logsock, Logging.Warn)

    Logging.with_logger(logger) do
        Logging.@error "Error"
        Logging.@warn "Warning"
        Logging.@info "Info"
        Logging.@debug "Debug"
    end
    @spawn timeout(timeout_sec, c)
    @test take!(c) == "Ok"
end
