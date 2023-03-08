using ComputationalGroupTheory

xor = [[0, 0],
       [0, 1],
       [1, 0],
       [1, 1]]

Y = [[0], [1], [1], [0]]

network = [DenseLayer(2, 3),
           Tanh(3, 3),
           DenseLayer(3, 1),
           Tanh(1, 1)]

epochs = 10_000
learning_rate = .1

for epoch in 1:epochs
    error = 0
    for (x, y) in zip(xor, Y)
        output = x
        for layer in network
            output = forward(layer, output)
        end

        error += mean_square_loss(y, output)

        grad = mean_square_loss_prime(y, output)
        for layer in network
            grad = backward(layer, grad, learning_rate)
        end
    end
    error /= length(xor)
    println(e + 1, "/", epochs, "error = ", error)
end