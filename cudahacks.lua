if lab == torch then
   torch.CudaTensor.torch = {}
   
   function torch.CudaTensor.torch.randn(...)
      local t = torch.FloatTensor.torch.randn(...)
      return torch.Tensor(t:size()):copy(t)
   end

   torch.CudaTensor.torch.uniform = torch.Tensor.uniform

else
   torch.CudaTensor.lab = {}
   
   function torch.CudaTensor.lab.randn(...)
      local t = torch.FloatTensor.lab.randn(...)
      return torch.Tensor(t:size()):copy(t)
   end
end