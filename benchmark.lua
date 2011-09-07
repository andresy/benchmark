require "lab"
require "os"
require "nn"

cmd = torch.CmdLine()

cmd:text()
cmd:text('Benchmark Torch7')
cmd:text()
cmd:text()
cmd:text('Misc options:')
cmd:option('-nomlp', false, 'do not perform MLP tests')
cmd:option('-nocnn', false, 'do not perform CNN tests')
cmd:option('-nexmlp', 10000, '# of examples for the MLPs')
cmd:option('-nexcnn', 1000, '# of examples for the CNNs')
cmd:option('-hardtanh', false, 'use hardtanh instead of tanh')
cmd:option('-convfast', false, 'use "fast" convolution code instead of standard')
cmd:option('-openmp', false, 'use openmp')
cmd:option('-double', false, 'use doubles instead of floats')
cmd:option('-nogi', false, 'do not compute gradInput')
cmd:option('-v', false, 'be verbose')

cmd:text()

local params = cmd:parse(arg)

random.manualSeed(5555)

if params.v then
   printlog = print
else
   printlog = print
   print = function()
           end
end

if params.openmp then
   require 'openmp'
end

if params.convfast then
   dofile('SpatialConvolutionFast.lua')
   nn.SpatialConvolution = nn.SpatialConvolutionFast
end

if params.hardtanh then
   nn.Tanh = nn.HardTanh
end

if params.double then
   torch.setdefaulttensortype('torch.DoubleTensor')
else
   torch.setdefaulttensortype('torch.FloatTensor')
end

local noutput = 10

if not params.nomlp then

   local ninput = 784
   local dataset = {}
   local data = lab.randn(params.nexmlp, ninput)
   function dataset:size()
      return params.nexmlp
   end

   setmetatable(dataset, {__index = function(self, index)
                                       return {data[index], (index % noutput) + 1}
                                    end})

   if true then -- MLP 784/10
      local mlp = nn.Sequential();                 -- make a multi-layer perceptron
      mlp:add(nn.Linear(ninput, noutput))
      mlp:add(nn.LogSoftMax())

      if params.nogi then
         mlp:get(1).gradInput = nil
      end

      local criterion = nn.ClassNLLCriterion()  
      local trainer = nn.StochasticGradient(mlp, criterion)

      trainer.learningRate = 0.01
      trainer.shuffleIndices = false
      trainer.maxIteration = 1
      local t = torch.Timer()
      trainer:train(dataset)
      printlog(string.format("mlp_%i_%i\t%.2f", ninput, noutput, params.nexmlp/t:time().real))
   end

   if true then -- MLP 784/500/10
      local mlp = nn.Sequential();                 -- make a multi-layer perceptron
      mlp:add(nn.Linear(ninput, 500))
      mlp:add(nn.Tanh())
      mlp:add(nn.Linear(500, noutput))
      mlp:add(nn.LogSoftMax())

      if params.nogi then
         mlp:get(1).gradInput = nil
      end

      local criterion = nn.ClassNLLCriterion()  
      local trainer = nn.StochasticGradient(mlp, criterion)

      trainer.learningRate = 0.01
      trainer.shuffleIndices = false
      trainer.maxIteration = 1
      local t = torch.Timer()
      trainer:train(dataset)
      printlog(string.format("mlp_%i_500_%i\t%.2f", ninput, noutput, params.nexmlp/t:time().real))
   end


   if true then --MLP 784/1000/1000/1000/10
      local mlp = nn.Sequential();                 -- make a multi-layer perceptron
      mlp:add(nn.Linear(ninput, 1000))
      mlp:add(nn.Tanh())
      mlp:add(nn.Linear(1000, 1000))
      mlp:add(nn.Tanh())
      mlp:add(nn.Linear(1000, 1000))
      mlp:add(nn.Tanh())
      mlp:add(nn.Linear(1000, noutput))
      mlp:add(nn.LogSoftMax())

      if params.nogi then
         mlp:get(1).gradInput = nil
      end

      local criterion = nn.ClassNLLCriterion()  
      local trainer = nn.StochasticGradient(mlp, criterion)

      trainer.learningRate = 0.01
      trainer.shuffleIndices = false
      trainer.maxIteration = 1
      local t = torch.Timer()
      trainer:train(dataset)
      printlog(string.format("mlp_%i_1000_1000_1000_%i\t%.2f", ninput, noutput, params.nexmlp/t:time().real))
   end
end

if not params.nocnn then

   function createcnndataset(nex,w,h)
      local dataset = {}
      local data = lab.randn(nex, 1, w, h)
      function dataset:size()
         return nex
      end

      setmetatable(dataset, {__index = function(self, index)
                                          return {data[index], (index % noutput) + 1}
                                       end})

      return dataset
   end
      
   if true then --LeNet5-like 32x32
      local dataset = createcnndataset(params.nexcnn, 32, 32)

      local mlp = nn.Sequential();                 -- make a multi-layer perceptron
      mlp:add(nn.SpatialConvolution(1, 6, 5, 5)) -- output 28x28
      mlp:add(nn.Tanh())
      mlp:add(nn.SpatialSubSampling(6, 2, 2, 2, 2)) --output 14x14
      mlp:add(nn.Tanh())
      mlp:add(nn.SpatialConvolution(6, 16, 5, 5)) -- output 10x10
      mlp:add(nn.Tanh())
      mlp:add(nn.SpatialSubSampling(16, 2, 2, 2, 2)) -- output 5x5
      mlp:add(nn.Tanh())
      mlp:add(nn.Reshape(16*5*5))
      mlp:add(nn.Linear(16*5*5, 120))
      mlp:add(nn.Linear(120, noutput))
      mlp:add(nn.LogSoftMax())

      if params.nogi then
         mlp:get(1).gradInput = nil
      end
      
      local criterion = nn.ClassNLLCriterion()  
      local trainer = nn.StochasticGradient(mlp, criterion)

      trainer.learningRate = 0.01
      trainer.shuffleIndices = false
      trainer.maxIteration = 1
      local t = torch.Timer()
      trainer:train(dataset)
      printlog(string.format("cnn_32x32\t%.2f", params.nexcnn/t:time().real))
   end
   
   if true then --LeNet5-like 96x96
      local dataset = createcnndataset(params.nexcnn, 96, 96)

      local mlp = nn.Sequential();                 -- make a multi-layer perceptron
      mlp:add(nn.SpatialConvolution(1, 6, 7, 7)) -- output 90x90
      mlp:add(nn.Tanh())
      mlp:add(nn.SpatialSubSampling(6, 3, 3, 3, 3)) --output 30x30
      mlp:add(nn.Tanh())
      mlp:add(nn.SpatialConvolution(6, 16, 7, 7)) -- output 24x24
      mlp:add(nn.Tanh())
      mlp:add(nn.SpatialSubSampling(16, 3, 3, 3, 3)) -- output 8x8
      mlp:add(nn.Tanh())
      mlp:add(nn.Reshape(16*8*8))
      mlp:add(nn.Linear(16*8*8, 120))
      mlp:add(nn.Linear(120, noutput))
      mlp:add(nn.LogSoftMax())

      if params.nogi then
         mlp:get(1).gradInput = nil
      end
      
      local criterion = nn.ClassNLLCriterion()  
      local trainer = nn.StochasticGradient(mlp, criterion)

      trainer.learningRate = 0.01
      trainer.shuffleIndices = false
      trainer.maxIteration = 1
      local t = torch.Timer()
      trainer:train(dataset)
      printlog(string.format("cnn_96x96\t%.2f", params.nexcnn/t:time().real))
   end

   if true then --LeNet5-like 256x256
      local dataset = createcnndataset(params.nexcnn, 256, 256)

      local mlp = nn.Sequential();                 -- make a multi-layer perceptron
      mlp:add(nn.SpatialConvolution(1, 6, 7, 7)) -- output 250x250
      mlp:add(nn.Tanh())
      mlp:add(nn.SpatialSubSampling(6, 5, 5, 5, 5)) --output 50x50
      mlp:add(nn.Tanh())
      mlp:add(nn.SpatialConvolution(6, 16, 7, 7)) -- output 44x44
      mlp:add(nn.Tanh())
      mlp:add(nn.SpatialSubSampling(16, 4, 4, 4, 4)) -- output 11x11
      mlp:add(nn.Tanh())
      mlp:add(nn.Reshape(16*11*11))
      mlp:add(nn.Linear(16*11*11, 120))
      mlp:add(nn.Linear(120, noutput))
      mlp:add(nn.LogSoftMax())

      if params.nogi then
         mlp:get(1).gradInput = nil
      end

      local criterion = nn.ClassNLLCriterion()  
      local trainer = nn.StochasticGradient(mlp, criterion)
      
      trainer.learningRate = 0.01
      trainer.shuffleIndices = false
      trainer.maxIteration = 1
      local t = torch.Timer()
      trainer:train(dataset)
      printlog(string.format("cnn_256x256\t%.2f", params.nexcnn/t:time().real))
   end
end
