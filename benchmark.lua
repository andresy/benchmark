require 'lab'
require 'random'
require "nn"

cmd = torch.CmdLine()

cmd:text()
cmd:text('Benchmark Torch7')
cmd:text()
cmd:text()
cmd:text('Misc options:')
cmd:option('-nomlp', false, 'do not perform MLP tests')
cmd:option('-nocnn', false, 'do not perform CNN tests')
cmd:option('-nexmlp', 60000, '# of examples for the MLPs')
cmd:option('-nexcnn', 6000, '# of examples for the CNNs')
cmd:option('-hardtanh', false, 'use hardtanh instead of tanh')
cmd:option('-convfast', false, 'use "fast" convolution code instead of standard')
cmd:option('-openmp', false, 'use openmp *package*')
cmd:option('-double', false, 'use doubles instead of floats')
cmd:option('-cuda', false, 'use CUDA instead of floats')
cmd:option('-gi', false, 'compute gradInput')
cmd:option('-v', false, 'be verbose')
cmd:option('-batch', 1, 'batch size')
cmd:option('-iter', 1, 'number of iterations to perform')
cmd:option('-hooks', false, 'add hooks useful for debug')

cmd:text()

function hooks(params)
   local n = 0
   local err = 0
   local function hookExample(self)
      err = err + self.criterion.output
      n = n + 1
   end

   local function hookIteration(self)
      printlog(string.format('mean err = %.3f', err/n))
      err = 0
      n = 0
   end

   if params.hooks then
      return hookExample, hookIteration
   end
end

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

if params.double and params.cuda then
   error('make your choice between double and cuda!!')
end

if params.double then
   torch.setdefaulttensortype('torch.DoubleTensor')
elseif params.cuda then
   require 'cunn'
   dofile('cudahacks.lua')
   torch.setdefaulttensortype('torch.CudaTensor')
   print(  cutorch.getDeviceProperties(cutorch.getDevice()) )
else
   torch.setdefaulttensortype('torch.FloatTensor')
end

local noutput = 10

if not params.nomlp then

   local ninput = 784
   local dataset = {}
   local data = lab.randn(params.nexmlp, ninput)
   local label = torch.LongTensor(params.nexmlp)
   for i=1,params.nexmlp do
      label[i] = (i % noutput) + 1
   end
   
   if params.batch == 1 then
      function dataset:size()
         return params.nexmlp
      end

      setmetatable(dataset, {__index = function(self, index)
                                          return {data[index], label[index]}
                                       end})
   else
      assert(params.nexmlp % params.batch == 0, '# of examples must be divisible with batch size')
      function dataset:size()
         return params.nexmlp/params.batch
      end
      setmetatable(dataset, {__index = function(self, index)
                                          return {data:narrow(1,(index-1)*params.batch+1, params.batch),
                                                  label:narrow(1,(index-1)*params.batch+1, params.batch)}
                                       end})
   end

   if true then -- MLP 784/10
      collectgarbage()
      local mlp = nn.Sequential();                 -- make a multi-layer perceptron
      mlp:add(nn.Linear(ninput, noutput))

      if params.cuda then
         mlp:add(nn.Copy('torch.CudaTensor', 'torch.FloatTensor'))
         torch.setdefaulttensortype('torch.FloatTensor')
      end

      mlp:add(nn.LogSoftMax())

      if not params.gi then
         if params.v then
            print('# do not compute gradInput')
         end
         mlp:get(1).gradInput = nil
      end

      local criterion = nn.ClassNLLCriterion()

      if params.cuda then
         torch.setdefaulttensortype('torch.CudaTensor')
      end

      local trainer = nn.StochasticGradient(mlp, criterion)

      trainer.hookExample, trainer.hookIteration = hooks(params)
      trainer.learningRate = 0.01
      trainer.shuffleIndices = false
      trainer.maxIteration = params.iter
      local t = torch.Timer()
      trainer:train(dataset)
      printlog(string.format("mlp_%i_%i\t%.2f", ninput, noutput, params.iter*params.nexmlp/t:time().real))
   end

   if true then -- MLP 784/500/10
      collectgarbage()
      local mlp = nn.Sequential();                 -- make a multi-layer perceptron
      mlp:add(nn.Linear(ninput, 500))
      mlp:add(nn.Tanh())
      mlp:add(nn.Linear(500, noutput))

      if params.cuda then
         mlp:add(nn.Copy('torch.CudaTensor', 'torch.FloatTensor'))
         torch.setdefaulttensortype('torch.FloatTensor')
      end

      mlp:add(nn.LogSoftMax())
      
      if not params.gi then
         if params.v then
            print('# do not compute gradInput')
         end
         mlp:get(1).gradInput = nil
      end

      local criterion = nn.ClassNLLCriterion()  

      if params.cuda then
         torch.setdefaulttensortype('torch.CudaTensor')
      end

      local trainer = nn.StochasticGradient(mlp, criterion)

      trainer.hookExample, trainer.hookIteration = hooks(params)
      trainer.learningRate = 0.01
      trainer.shuffleIndices = false
      trainer.maxIteration = params.iter
      local t = torch.Timer()
      trainer:train(dataset)
      printlog(string.format("mlp_%i_500_%i\t%.2f", ninput, noutput, params.iter*params.nexmlp/t:time().real))
   end


   if true then --MLP 784/1000/1000/1000/10
      collectgarbage()
      local mlp = nn.Sequential();                 -- make a multi-layer perceptron
      mlp:add(nn.Linear(ninput, 1000))
      mlp:add(nn.Tanh())
      mlp:add(nn.Linear(1000, 1000))
      mlp:add(nn.Tanh())
      mlp:add(nn.Linear(1000, 1000))
      mlp:add(nn.Tanh())
      mlp:add(nn.Linear(1000, noutput))

      if params.cuda then
         mlp:add(nn.Copy('torch.CudaTensor', 'torch.FloatTensor'))
         torch.setdefaulttensortype('torch.FloatTensor')
      end

      mlp:add(nn.LogSoftMax())

      if not params.gi then
         if params.v then
            print('# do not compute gradInput')
         end
         mlp:get(1).gradInput = nil
      end

      local criterion = nn.ClassNLLCriterion()  

      if params.cuda then
         torch.setdefaulttensortype('torch.CudaTensor')
      end

      local trainer = nn.StochasticGradient(mlp, criterion)

      trainer.hookExample, trainer.hookIteration = hooks(params)
      trainer.learningRate = 0.01
      trainer.shuffleIndices = false
      trainer.maxIteration = params.iter
      local t = torch.Timer()
      trainer:train(dataset)
      printlog(string.format("mlp_%i_1000_1000_1000_%i\t%.2f", ninput, noutput, params.iter*params.nexmlp/t:time().real))
   end
end

if not params.nocnn then

   function createcnndataset(nex,w,h)
      local dataset = {}
      local data = lab.randn(nex, 1, w, h)
      local label = torch.LongTensor(params.nexmlp)
      for i=1,params.nexmlp do
         label[i] = (i % noutput) + 1
      end

      if params.batch == 1 then
         function dataset:size()
            return nex
         end

         setmetatable(dataset, {__index = function(self, index)
                                             return {data[index], label[index]}
                                          end})
      else
         assert(nex % params.batch == 0, '# of examples must be divisible with batch size')
         function dataset:size()
            return nex/params.batch
         end
         setmetatable(dataset, {__index = function(self, index)
                                             return {data:narrow(1,(index-1)*params.batch+1, params.batch),
                                                     label:narrow(1,(index-1)*params.batch+1, params.batch)}
                                          end})
      end

      return dataset
   end
      
   if true then --LeNet5-like 32x32
      collectgarbage()
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

      if params.cuda then
         mlp:add(nn.Copy('torch.CudaTensor', 'torch.FloatTensor'))
         torch.setdefaulttensortype('torch.FloatTensor')
      end

      mlp:add(nn.LogSoftMax())

      if not params.gi then
         if params.v then
            print('# do not compute gradInput')
         end
         mlp:get(1).gradInput = nil
      end
      
      local criterion = nn.ClassNLLCriterion()  

      if params.cuda then
         torch.setdefaulttensortype('torch.CudaTensor')
      end

      local trainer = nn.StochasticGradient(mlp, criterion)

      trainer.hookExample, trainer.hookIteration = hooks(params)
      trainer.learningRate = 0.01
      trainer.shuffleIndices = false
      trainer.maxIteration = params.iter
      local t = torch.Timer()
      trainer:train(dataset)
      printlog(string.format("cnn_32x32\t%.2f", params.iter*params.nexcnn/t:time().real))
   end
   
   if true then --LeNet5-like 96x96
      collectgarbage()
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

      if params.cuda then
         mlp:add(nn.Copy('torch.CudaTensor', 'torch.FloatTensor'))
         torch.setdefaulttensortype('torch.FloatTensor')
      end

      mlp:add(nn.LogSoftMax())

      if not params.gi then
         if params.v then
            print('# do not compute gradInput')
         end
         mlp:get(1).gradInput = nil
      end
      
      local criterion = nn.ClassNLLCriterion()  

      if params.cuda then
         torch.setdefaulttensortype('torch.CudaTensor')
      end

      local trainer = nn.StochasticGradient(mlp, criterion)

      trainer.hookExample, trainer.hookIteration = hooks(params)
      trainer.learningRate = 0.01
      trainer.shuffleIndices = false
      trainer.maxIteration = params.iter
      local t = torch.Timer()
      trainer:train(dataset)
      printlog(string.format("cnn_96x96\t%.2f", params.iter*params.nexcnn/t:time().real))
   end

   if true then --LeNet5-like 256x256
      collectgarbage()
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

      if params.cuda then
         mlp:add(nn.Copy('torch.CudaTensor', 'torch.FloatTensor'))
         torch.setdefaulttensortype('torch.FloatTensor')
      end

      mlp:add(nn.LogSoftMax())

      if not params.gi then
         if params.v then
            print('# do not compute gradInput')
         end
         mlp:get(1).gradInput = nil
      end

      local criterion = nn.ClassNLLCriterion()  

      if params.cuda then
         torch.setdefaulttensortype('torch.CudaTensor')
      end

      local trainer = nn.StochasticGradient(mlp, criterion)
      
      trainer.hookExample, trainer.hookIteration = hooks(params)
      trainer.learningRate = 0.01
      trainer.shuffleIndices = false
      trainer.maxIteration = params.iter
      local t = torch.Timer()
      trainer:train(dataset)
      printlog(string.format("cnn_256x256\t%.2f", params.iter*params.nexcnn/t:time().real))
   end
end
