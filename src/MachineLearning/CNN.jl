"""
    Layer(input, ouput)

An interface with two functions:
    • forward
    • backward
"""
abstract type Layer end

input(layer::Layer)                 = layer.input
output(layer::Layer)                = layer.output
set_input!(layer::Layer, input)     = layer.input = input
set_output!(layer::Layer, output)   = layer.output = output

mutable struct DenseLayer <: Layer
    W::Matrix
    b::Vector
    input
    output

    function DenseLayer(input_size, output_size)
        return new(rand(output_size, input_size), rand(output_size))
    end
end

function forward(denseLayer::DenseLayer, input)
    set_input!(denseLayer, input)
    return denseLayer.W * denseLayer.input + denseLayer.b
end

function backward(denseLayer::DenseLayer, output_gradient, learning_rate)
    weights_gradient = dot(output_gradient, input(denseLayer)')
    input_gradient = dot(denseLayer.W', output_gradient)
    denseLayer.W -= learning_rate * weights_gradient
    denseLayer.b -= learning_rate * output_gradient
    return input_gradient
end

abstract type ActivationLayer <: Layer end

function forward(layer::ActivationLayer, input)
    layer.input = input
    return layer.f(input)
end

function backward(layer::ActivationLayer, output_gradient, learning_rate)
    output_gradient .* layer.f′(layer.input)
end

mutable struct Tanh <: ActivationLayer
    input
    output
    f
    f′

    function Tanh(input, output)
        return new(input, output, x -> tanh.(x), x -> ones(length(input)) - tanh.(x)^2)
    end
end
   
mean_square_loss(y_true, y_predicted) = sum((y_predicted - y_true).^2) / length(y_true)
mean_square_loss_prime(y_true, y_predicted) = 2 * (y_predicted - y_true) / length(y_true)