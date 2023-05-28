using ThreadPools
using BenchmarkTools
using Random
using LinearAlgebra
BLAS.set_num_threads(1)

const N = 50

function do_constant_work(channel::Channel)
    #@info "Doing work on thread $(Threads.threadid())"
    result = let
        # N = 500
        A = rand(N, N) .- 0.5
        b = svd(A' * A).S[1]
        abs(b[1] - round(b[1]))
    end
    put!(channel, take!(channel) + result)
    #@info fetch(result)
end

function do_constant_work(channel::Channel, available_workers, iam)
    # @info "Doing work on thread $(Threads.threadid())"
    do_constant_work(channel)
    put!(available_workers, iam)
    # @info fetch(result)
end

function do_parallel_run(threshold, nworkers::Int)
    result = Channel{Float64}(1)
    put!(result, zero(threshold))
    while fetch(result) ≤ threshold
        @sync for i ∈ 1:nworkers
            if fetch(result) ≤ threshold
                @tspawnat mod1(i, Threads.nthreads()) do_constant_work(result)
            else
                break
            end
        end
    end
    close(result)
    return collect(result)
end

function do_unbalanced_run(threshold, nworkers::Int)
    available_workers = Channel{Int}(nworkers)
    for i ∈ 1:nworkers put!(available_workers, i) end
    
    result = Channel{Float64}(1)
    put!(result, zero(threshold))

    @sync while fetch(result) ≤ threshold
        worker = take!(available_workers)
        # @info "next worker: $worker"
        @tspawnat mod1(worker, Threads.nthreads()) do_constant_work(result, available_workers, worker)
    end
    close(result)
    return collect(result)
end

function do_sequential_work(threshold)
    result = zero(threshold)
    while result ≤ threshold
        x = let
            # N = 500
            A = rand(N, N) .- 0.5
            b = svd(A' * A).S[1]
            abs(b[1] - round(b[1]))
        end
        result += x
    end
    return result
end

seed = 42
workload = 10
nworkers = 4

# Benchmarks run with seed = 42, workload = 10 on nworkers = 4 physical cores with hyperthreading

@info "Do parallel run:"
Random.seed!(seed)
@time do_parallel_run(workload, nworkers)
# 5.930 ms (843 allocations: 5.74 MiB)

@info "Do unbalanced run:"
Random.seed!(seed)
@btime do_unbalanced_run(workload, nworkers)
# 8.318 ms (754 allocations: 5.91 MiB)

@info "Do sequential run:"
Random.seed!(seed)
@btime do_sequential_work(workload)
# 18.776 ms (513 allocations: 5.72 MiB)