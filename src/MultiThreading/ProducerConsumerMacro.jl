"""
    @producer_consumer buff_type buff_size function_name(args...) body end

Defines a function using the producer-consumer pattern. The function creates a shared buffer,
a producer task that puts items into the buffer, and a consumer task that takes items from the buffer.

# Arguments
- `buff_type::Type`: The type of the items in the buffer. Defaults to `Any`.
- `buff_size::Int`: The size of the buffer. Defaults to `typemax(Int)`.
- `function_name::Symbol`: The name of the function to define.
- `args...`: The arguments of the function.
- `body`: The body of the function. This should contain calls to the `@producer` and `@consumer` macros
    to define the producer and consumer tasks.

# Usage
The `@producer` and `@consumer` macros should be used inside the body of the function to define the producer
and consumer tasks. `@producer` takes a function call that produces an item and puts it into the buffer.
`@consumer` takes a function call that consumes an item taken from the buffer.

# Example
```julia
@producer_consumer Int 10 function f(x, y)
    @producer produce_item(x)
    @consumer consume_item
end
This defines a function f(x, y) that creates a buffer of size 10 and type Int, a producer task
that calls produce_item(x) and puts the result into the buffer, and a consumer task that takes items
from the buffer and passes them to consume_item.
"""
macro producer_consumer(buff_type, buff_size, body)
    # Process the body to find @producer and @consumer macros
    producers = []
    consumers = []
    result_arg = nothing
    for ex in body.args
        if isa(ex, Expr) && ex.head == :macrocall
            if ex.args[1] == Symbol("@producer")
                push!(producers, ex.args[2:end])
            elseif ex.args[1] == Symbol("@consumer")
                consumer_expr = ex.args[2:end]
                push!(consumers, consumer_expr)
                result_arg = consumer_expr[1]  # assumes first arg is the result
            end
        end
    end

    # Generate the function definition
    quote
        function $(esc(body.args[1].args[1]))($(body.args[1].args[2:end]...))
            buffer = Channel{$(esc(buff_type))}($(esc(buff_size)))
            result = $(esc(result_arg))

            producer_tasks = [@task $producer for producer in $(producers)]
            consumer_tasks = [@task $consumer for consumer in $(consumers)]
            tasks = vcat(producer_tasks, consumer_tasks)

            for t in tasks
                schedule(t)
            end

            for t in tasks
                wait(t)
            end

            return $(esc(result_arg))
        end
    end
end

"""
@producer function_call

Defines a producer task that calls a function and puts the result into the buffer.
Arguments

    function_call: The function call that produces an item.

Example
@producer produce_item(x)
This defines a producer task that calls produce_item(x) and puts the result into the buffer.
"""
macro producer(body...)
    :(put!(buffer, $(esc(body...))))
end

"""
    @consumer result function_call

Defines a consumer task that calls a function with an item taken from the buffer.

# Arguments
- `result`: A data structure that the consumer function will modify.
- `function_call`: The function call that consumes an item.

# Usage
The function call should take two arguments: the item from the buffer and the result data structure. The function should modify the result data structure based on the item from the buffer.

# Example
```julia
    @consumer result consume_item
```
This defines a consumer task that takes items from the buffer and passes them to consume_item(result). consume_item is a function that modifies the result data structure based on the item it receives.
Note

The result argument must be a mutable data structure if you want the modifications made by consume_item to be visible outside the function.
"""
macro consumer(body...)
    :($(esc(body[2]))(take!(buffer), $(esc(body[1]))))  # assumes body[2] is the function and body[1] is the result
end



########################## Tests ##########################



# Define producer and consumer functions
function p(x)
    sleep(.0001)
    return x
end

function c(result, x)
    result[1] += x  # use an array for result to allow mutation
end

println(@macroexpand @producer_consumer Int 10 function f(n::Int)
    result = [0]
    for _ in 1:n
        @producer p(1)
    end
    for _ in 1:n
        @consumer result c
    end
    return result[1]
end)

@producer_consumer Int 10 function f(n::Int)
    result = [0]
    for _ in 1:n
        @producer p(1)
    end
    for _ in 1:n
        @consumer result c
    end
    return result[1]
end


# Run the test
n = 1000
println(f(n))

