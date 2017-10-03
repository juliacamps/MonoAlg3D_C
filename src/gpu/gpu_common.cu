//
// Created by sachetto on 03/10/17.
//
#if __GNUC_MINOR__ >= 7
#undef _GLIBCXX_ATOMIC_BUILTINS
#undef _GLIBCXX_USE_INT128
#endif


#include <stdio.h>
#include "gpu_common.h"
#include <cuda_runtime.h>


void init_cuda_device(int device) {
    printf("Using GPU Ten Tusscher 3 Model\n");

    int count;

    cudaGetDeviceCount(&count);
    struct cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, device);
    printf("%d devices available, running on Device %d: %s\n", count, device, prop.name);


    cudaSetDevice(device);
    //TODO: @Check: I dont think we need this. dt can be passed as the kernel parameter
    //check_err(cudaMemcpyToSymbol(dt,&dt_,sizeof(Real)));
}