"""
This is based on the blog post "PSA: Thread-local state is no longer recommended" on
the official Julia blog: https://julialang.org/blog/2023/07/PSA-dont-use-threadid
"""

using Base.Threads: nthreads, @threads, threadid, @spawn
using Base.Iterators: partition

"""
The erroneous pattern
"""
let states = [0 for _ in 1:nthreads()]
    @threads for x in rand(Int, 100)
        my_threadid = threadid()
        old_value = states[my_threadid]         # Between the read here...
        new_value = (x -> x + 5)(old_value)     # ... and the write here...
        # ... the task could yield it's execution and a new task on the same thread
        # could be started. This new task could concurrently write to states, and
        # this result will then be overwritten here:
        states[my_threadid] = new_value
    end
    sum(states)
end

"""
The above race condition can even occur if it is executed on a single thread:
"""
let f(i) = (sleep(0.001); i), state = [0], N = 100
    @sync for i in 1:N
        @spawn begin
            my_threadid = threadid()
            old_value = state[my_threadid]
            new_value = old_value + f(i)
            state[my_threadid] = new_value
        end
    end
    sum(state), sum(1:N)
end

"""
Here is the presented solution:

If you want a recipe that can replace the above buggy one with something that can be written
using only the Base.Threads module, we recommend moving away from @threads, and instead
working directly with @spawn to create and manage tasks. The reason is that @threads does
not have any builtin mechanisms for managing and merging the results of work from different
threads, whereas tasks can manage and return their own state in a safe way.

Tasks creating and returning their own state is inherently safer than the spawner of parallel
tasks setting up state for spawned tasks to read from and write to.

Code which replaces the incorrect code pattern shown above can look like this:
"""

let tasks_per_thread = 2,
    N = BigInt(1000000000),
    data = 1:N,
    chunk_size = max(1, length(data) ÷ (tasks_per_thread * nthreads())),
    data_chunks = partition(data, chunk_size)

    tasks = map(data_chunks) do chunk
        @spawn begin
            state = zero(eltype(data))
            for x in chunk
                state += x  # Do something with the data and combine the result into the state
            end
            return state
        end
    end

    states = fetch.(tasks)
    sum(states)
end

@time sum(1:1000000000)
