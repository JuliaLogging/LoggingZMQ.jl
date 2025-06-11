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
const log_addr = "inproc://testlogger"
const trigger_addr = "inproc://trigger"
const timeout_sec = 30

# receiver is asynchronous to prevent tests from hanging
function spawn_receiver(ctx, msg_list, c)
    return @spawn begin
        receiver = Socket(ctx, SUB)
        subscribe(receiver, "")
        connect(receiver, log_addr)
        # Indicate to the main testing code that task is ready to receive logs
        # Without this, CI doesn't run for some reason
        trigger = Socket(ctx, REQ)
        connect(trigger, trigger_addr)
        send(trigger, "Ready")
        recv(trigger)
        for msg in msg_list
            r = recv(receiver, String)
            # println("Got: " * r)
            # println("Expected: " * msg)
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

# cause tests to fail when timeout
function timeout(s, c)
    sleep(s)
    return put!(c, "Timeout")
end

@testset "Main" begin
    c = Channel{String}(32)
    test_task = spawn_receiver(ctx, ["Error", "Warning", "Info", "Debug"], c)

    logsock = Socket(ctx, PUB)
    bind(logsock, log_addr)
    logger = ZMQLogger(logsock, Logging.BelowMinLevel)

    # Wait until receiver indicates ok to start
    trigger = Socket(ctx, REP)
    bind(trigger, trigger_addr)
    recv(trigger)
    send(trigger, "Ok")

    Logging.with_logger(logger) do
        Logging.@error "Error"
        Logging.@warn "Warning"
        Logging.@info "Info"
        Logging.@debug "Debug"
    end

    @spawn timeout(timeout_sec, c)
    @test take!(c) == "Ok"

    c = Channel{String}(32)
    test_task = spawn_receiver(ctx, ["Error", "Warning"], c)
    logger = ZMQLogger(logsock, Logging.Warn)

    # Wait until receiver indicates ok to start
    recv(trigger)
    send(trigger, "Ok")

    Logging.with_logger(logger) do
        Logging.@error "Error"
        Logging.@warn "Warning"
        Logging.@info "Info"
        Logging.@debug "Debug"
    end
    @spawn timeout(timeout_sec, c)
    @test take!(c) == "Ok"
end
