using Base.Threads
using BenchmarkTools

function single_thread_add(a::Vector{T}, b::Vector{T}) where T<:Number
    @assert length(a) == length(b)
    n = length(a)
    c = similar(a)
    for i ∈ 1:n
        c[i] = a[i] + b[i]
    end
end

function single_thread_add_inbounds(a::Vector{T}, b::Vector{T}) where T<:Number
    @assert length(a) == length(b)
    n = length(a)
    c = similar(a)
    for i ∈ 1:n
        @inbounds c[i] = a[i] + b[i]
    end
end

function multi_thread_add(a::Vector{T}, b::Vector{T}) where T<:Number
    @assert length(a) == length(b)
    n = length(a)
    c = similar(a)
    @threads for i ∈ 1:n
        c[i] = a[i] + b[i]
    end
end

function multi_thread_add_inbounds(a::Vector{T}, b::Vector{T}) where T<:Number
    @assert length(a) == length(b)
    n = length(a)
    c = similar(a)
    @threads for i ∈ 1:n
        @inbounds c[i] = a[i] + b[i]
    end
end

function simd_add_inbounds(a::Vector{T}, b::Vector{T}) where T<:Number
    @assert length(a) == length(b)
    n = length(a)
    c = similar(a)
    @simd for i ∈ 1:n
        @inbounds c[i] = a[i] + b[i]
    end
end

let T = Float64, n = 10^6
    let a = rand(T, n), b = rand(T, n)
        b₁ = @benchmark single_thread_add($a, $b)
        b₂ = @benchmark single_thread_add_inbounds($a, $b)
        judge(median(b₁), median(b₂))
    end
end

let T = Float64, n = 10^6
    let a = rand(T, n), b = rand(T, n)
        b₁ = @benchmark single_thread_add($a, $b)
        b₂ = @benchmark multi_thread_add($a, $b)
        judge(median(b₁), median(b₂))
    end
end

let T = Float64, n = 10^6
    let a = rand(T, n), b = rand(T, n)
        b₁ = @benchmark multi_thread_add($a, $b)
        b₂ = @benchmark multi_thread_add_inbounds($a, $b)
        judge(median(b₁), median(b₂))
    end
end

let T = Float64, n = 10^6
    let a = rand(T, n), b = rand(T, n)
        b₁ = @benchmark multi_thread_add($a, $b)
        b₂ = @benchmark simd_add_inbounds($a, $b)
        judge(median(b₁), median(b₂))
    end
end