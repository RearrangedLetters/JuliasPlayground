using BenchmarkTools

function producer(buffer::Channel{T}, num_items::Int) where {T}
    for n ∈ 1:num_items
        sleep(.001)
        put!(buffer, n)
    end 
end

function consumer(buffer::Channel{T}, num_items::Int, result::Channel{T}) where {T}
    for _ ∈ 1:num_items
        sleep(.001)
        put!(result, take!(buffer) + 42)
    end
end

function run_producer_consumer(n::Int, m::Int, items_per_producer::Int, items_per_consumer::Int)
    @assert n * items_per_producer == m * items_per_consumer

    buffer = Channel{Int}(n * items_per_producer)
    result = Channel{Int}(n * items_per_producer)

    producer_tasks = [@task producer(buffer, items_per_producer) for _ ∈ 1:n]
    consumer_tasks = [@task consumer(buffer, items_per_consumer, result) for _ ∈ 1:m]

    all_tasks = vcat(producer_tasks, consumer_tasks)

    for t ∈ all_tasks
        schedule(t)
    end

    for t ∈ all_tasks
        wait(t)
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

const num_producers = 2
const num_consumers = 2
const items_per_actor = 10

@benchmark run_sequential(num_producers, num_consumers, items_per_actor, items_per_actor)
@benchmark run_producer_consumer(num_producers, num_consumers, items_per_actor, items_per_actor)
