using BenchmarkTools
using LinearAlgebra
BLAS.set_num_threads(1)

function sleepy_producer(buffer::Channel)
    sleep(.001)
    put!(buffer, 1)
end

function svd_producer(buffer::Channel, stop::Channel, start::Int)
    i = start
    while !isready(stop)
        result = let  # some work here
            N = 200 * isqrt(i += 1)
            A = rand(N, N) .- 0.5
            b = svd(A' * A).S[1]
            abs(b[1] - round(b[1]))
        end
        put!(buffer, result)
    end
end

function svd_consumer(buffer::Channel{T}, result::Channel{T}, stop::Channel) where {T}
    sum = zero(T)
    while sum < 1.0
        sum += take!(buffer)
    end
    put!(stop, true)
    put!(result, sum)
end

function sleepy_consumer(buffer::Channel{T}, result::Channel{T}) where {T}
    sleep(.001)
    put!(result, take!(buffer) + 41)
end

function producer_consumer(producer::Function, n::Int,
                           consumer::Function, m::Int,
                           buffersize::Int)

    buffer = Channel{Float64}(buffersize)
    result = Channel{Float64}(buffersize)
    stop   = Channel{Bool}(1)

    producer_tasks = [@task producer(buffer, stop, i * (n - 1)) for i ∈ 1:n]
    consumer_tasks = [@task consumer(buffer, result, stop) for _ ∈ 1:m]

    all_tasks = [producer_tasks; consumer_tasks]

    for task ∈ all_tasks
        schedule(task)
    end

    for task ∈ all_tasks
        wait(task)
    end

    close(buffer)
    close(result)

    return collect(result)
end

function run_sequential(n::Int, m::Int, items_per_producer::Int, items_per_consumer::Int)
    @assert n * items_per_producer == m * items_per_consumer

    buffer = Channel{Int}(Inf)
    result = Channel{Int}(Inf)
    
    for _ ∈ 1:n
        for item_id ∈ 1:items_per_producer
            sleep(.001)
            put!(buffer, item_id)
        end
    end
    
    for _ ∈ 1:m
        for _ ∈ 1:items_per_consumer
            sleep(.001)
            put!(result, take!(buffer) + 42)
        end
    end

    close(result)

    return collect(result)
end

const num_producers = 8
const num_consumers = 8

# @benchmark run_sequential(num_producers, num_consumers, items_per_actor, items_per_actor)
# @benchmark producer_consumer(num_producers, num_consumers, items_per_actor, items_per_actor)

@info "Do producer_consumer run:"
@benchmark producer_consumer(svd_producer, 2, svd_consumer, 1, 32)

