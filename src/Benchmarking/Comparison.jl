using BenchmarkTools
using Plots

function benchmark_algorithms(functions::Vector{Function}, input_generator::Function, range::AbstractRange, samples::Int=100)
    results = Dict()

    for f in functions
        func_results = Vector{Float64}()

        # Benchmark for each input size in the range
        for k in range
            input = input_generator(k)
            b = @benchmarkable $f($input)
            tune!(b, samples=samples)
            t = median(run(b)).time
            push!(func_results, t)
        end

        results[string(f)] = func_results
    end

    # Plot results
    p = plot(legend=:outertopright)
    for (func_name, func_results) in results
        plot!(p, range, func_results, label=func_name)
    end
    title!(p, "Benchmark Results")
    xlabel!(p, "Input Size")
    ylabel!(p, "Time (ns)")
    display(p)
end


# Define your algorithms
sort_standard(x) = sort(x)
sort_reverse(x) = sort(x, rev=true)

# Define your input generator
input_generator(k) = rand(Int, k)

# Define your range
range = 10_000:10_000:100_000
samples = 1

# Run the benchmarks
benchmark_algorithms([sort_standard, sort_reverse], input_generator, range, samples)

function sum_array(a)
    total = 0
    for i in eachindex(a)
        total += a[i]
    end
    return total
end

function unrolled_sum_array(a)
    total = 0
    len = length(a)
    i = 1

    # Sum pairs of elements
    while i <= len - 1
        total += a[i] + a[i+1]
        i += 2
    end

    # If the array length is odd, sum the last element
    if len % 2 != 0
        total += a[len]
    end

    return total
end

benchmark_algorithms([sum_array, unrolled_sum_array, sum], k -> rand(k), 1000:100:2000, 1)