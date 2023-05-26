using BenchmarkTools

function isprime(n)
    n < 2 && return false
    n == 2 && return true
    n % 2 == 0 && return false
    for x in 3:2:sqrt(n)
        n % x == 0 && return false
    end
    return true
end

function sum_primes(n)
    return sum((isprime(x) ? x : 0 for x in 1:n))
end

function sum_primes_parallel(n)
    ch = Channel{Int}(100)

    @async begin
        for x in 1:n
            isprime(x) && put!(ch, x)
        end
        close(ch)
    end

    return sum(fetch, ch)
end

function sum_primes_parallel_threaded(n)
    # Determine the number of threads
    num_threads = Threads.nthreads()
    
    # Partition the work into chunks
    chunk_size = n ÷ num_threads
    chunks = [((i-1)*chunk_size+1):(i*chunk_size) for i in 1:num_threads]
    # Ensure the last chunk includes any leftover elements
    chunks[end] = ((num_threads-1)*chunk_size+1):n

    # Spawn a task for each chunk
    tasks = [Threads.@spawn sum((isprime(x) ? x : 0 for x in chunk)) for chunk in chunks]

    # Fetch the results of the tasks
    return sum(fetch.(tasks))
end


n = 10^6

println("Sequential execution:")
@btime sum_primes($n)

println("\nParallel execution:")
@btime sum_primes_parallel($n)

println("\nParallel execution (threaded):")
@btime sum_primes_parallel_threaded($n)
