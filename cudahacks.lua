if not torch.CudaTensor.torch then
   torch.CudaTensor.torch = {}
   
   function torch.CudaTensor.torch.randn(...)
      return torch.FloatTensor.torch.randn(...):cuda()
   end

   function torch.CudaTensor.torch.rand(...)
      return torch.FloatTensor.torch.rand(...):cuda()
   end

   torch.CudaTensor.torch.uniform = torch.Tensor.uniform
end
