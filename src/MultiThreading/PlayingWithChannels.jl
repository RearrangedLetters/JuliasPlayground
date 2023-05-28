# This code is originally from M. Kaluba but has been adapted.

using LinearAlgebra
BLAS.set_num_threads(1)
using BenchmarkTools

function do_work_unintentionally_sequential(jobs, results, stop)
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

function do_work(jobs, results, stop)
    @sync for _ in 1:Threads.nthreads()
        Threads.@spawn for job_id in jobs
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

function parallel_run(target, queue_length = Threads.nthreads())
    stop = Channel{Bool}(1)

    jobs =
        Channel{Int}(jobs -> make_jobs(jobs, stop), queue_length; spawn = true)

    results = Channel{Tuple{Int,Float64}}(
        results -> do_work(jobs, results, stop),
        queue_length;
        spawn = true,
    )

    sum = 0.0
    try
        while sum < target
            job_id, res = take!(results)
            thr_id, val = fldmod(res, 1.0)
            # @info "Job $(job_id) finished in $(round(val, digits=3))s on thread $(Int(thr_id))"
            sum += val
        end
    finally
        # @info "sending stop signal"
        # to immediately stop processing here one could just
        # close(jobs)
        # but I'm not sure if this will allow for resuming work later...
        put!(stop, true)
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

threshold = 3.0

@info "Do parallel run:"
@benchmark parallel_run($threshold, 8)

@info "Do sequential run:"
@benchmark sequential_run($threshold)