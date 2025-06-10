import Base.Threads: @spawn
using LoggingZMQ
using ZMQ
using Test
import Logging
using Aqua

@testset "Aqua" begin
    Aqua.test_all(LoggingZMQ)
end

ctx = Context()
addr = "inproc://logger"

# receiver is asynchronous to prevent tests from hanging
function spawn_receiver(ctx, addr, msg_list)
    return @spawn begin
        receiver = Socket(ctx, SUB)
        subscribe(receiver, "")
        connect(receiver, addr)
        for msg in msg_list
            r = recv(receiver, String)
            # println("Got: " * r)
            # println("Expected: " * msg)
            if r != msg
                close(receiver)
                return false
            end
        end
        close(receiver)
        return true
    end
end

@testset "Main" begin
    test_task = spawn_receiver(ctx, addr, ["Error", "Warning", "Info", "Debug"])
    logsock = Socket(ctx, PUB)
    bind(logsock, addr)
    logger = ZMQLogger(logsock, Logging.BelowMinLevel)

    Logging.with_logger(logger) do
        Logging.@error "Error"
        Logging.@warn "Warning"
        Logging.@info "Info"
        Logging.@debug "Debug"
    end
    sleep(1)
    @test istaskdone(test_task) && fetch(test_task)

    test_task = spawn_receiver(ctx, addr, ["Error", "Warning"])
    logger = ZMQLogger(logsock, Logging.Warn)

    Logging.with_logger(logger) do
        Logging.@error "Error"
        Logging.@warn "Warning"
        Logging.@info "Info"
        Logging.@debug "Debug"
    end
    sleep(1)
    @test istaskdone(test_task) && fetch(test_task)
end
