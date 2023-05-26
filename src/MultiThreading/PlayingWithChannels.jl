# This code is originally from M. Kaluba

using LinearAlgebra
BLAS.set_num_threads(1)
using BenchmarkTools

function do_work(jobs, results, stop)
    for job_id in jobs
        result = let  # some work here
            N = 200 * isqrt(job_id)
            A = rand(N, N) .- 0.5
            b = svd(A' * A).S[1]
            abs(b[1] - round(b[1]))
        end
        put!(results, (job_id, result))
        if isready(stop)
            # @info "do work: received stop signal"
            return nothing
        end
    end
    return nothing
end

function make_jobs(jobs, stop)
    i = 1
    while true
        if isready(stop)
            # @info "make_jobs: received stop signal"
            return nothing
        end
        # @info "make_jobs: Placing job $i"
        put!(jobs, i)
        i += 1
    end
end

function parallel_run(result, nworkers = 2)
    stop = Channel{Bool}(1)

    jobs = Channel{Int}(16; spawn = true) do jobs
        return make_jobs(jobs, stop)
    end

    results = Channel{Tuple{Int,Float64}}(nworkers; spawn = true) do results
        return do_work(jobs, results, stop)
    end

    sum = 0.0
    try
        while sum < result
            job_id, value = take!(results)
            # @info "$(job_id) finished with value $(value)s"
            sum += value
        end
    finally
        # @info "sending stop signal"
        put!(stop, true)
        # also doing some cleanup
    end

    return sum
end

function sequential_run(result)
    i = 1
    sum = 0.0
    while sum < result
        value = let  # some work here
            N = 200 * isqrt(i)
            A = rand(N, N) .- 0.5
            b = svd(A' * A).S[1]
            abs(b[1] - round(b[1]))
        end
        sum += value
        i += 1
    end
    return sum
end

#############################################

threshold = 1.0

@info "Do parallel run:"
@benchmark parallel_run($threshold, 2)

@info "Do sequential run:"
@benchmark sequential_run($threshold)