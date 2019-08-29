#include <stddef.h>
#include <stdint.h>
#include "model_gpu_utils.h"

#include "stewart_aslanidi_noble_2009.h"

extern "C" SET_ODE_INITIAL_CONDITIONS_GPU(set_model_initial_conditions_gpu) {

    print_to_stdout_and_file("Using Stewart-Aslanidi-Noble 2009 GPU model\n");

    // execution configuration
    const int GRID  = (num_volumes + BLOCK_SIZE - 1)/BLOCK_SIZE;

    size_t size = num_volumes*sizeof(real);

    check_cuda_error(cudaMallocPitch((void **) &(*sv), &pitch_h, size, (size_t )NEQ));
    check_cuda_error(cudaMemcpyToSymbol(pitch, &pitch_h, sizeof(size_t)));


    kernel_set_model_inital_conditions <<<GRID, BLOCK_SIZE>>>(*sv, num_volumes);

    check_cuda_error( cudaPeekAtLastError() );
    cudaDeviceSynchronize();
    return pitch_h;

}

extern "C" SOLVE_MODEL_ODES_GPU(solve_model_odes_gpu) {

    // execution configuration
    const int GRID  = ((int)num_cells_to_solve + BLOCK_SIZE - 1)/BLOCK_SIZE;


    size_t stim_currents_size = sizeof(real)*num_cells_to_solve;
    size_t cells_to_solve_size = sizeof(uint32_t)*num_cells_to_solve;

    real *stims_currents_device;
    check_cuda_error(cudaMalloc((void **) &stims_currents_device, stim_currents_size));
    check_cuda_error(cudaMemcpy(stims_currents_device, stim_currents, stim_currents_size, cudaMemcpyHostToDevice));


    //the array cells to solve is passed when we are using and adapative mesh
    uint32_t *cells_to_solve_device = NULL;
    if(cells_to_solve != NULL) {
        check_cuda_error(cudaMalloc((void **) &cells_to_solve_device, cells_to_solve_size));
        check_cuda_error(cudaMemcpy(cells_to_solve_device, cells_to_solve, cells_to_solve_size, cudaMemcpyHostToDevice));
    }
    solve_gpu <<<GRID, BLOCK_SIZE>>>(dt, sv, stims_currents_device, cells_to_solve_device, num_cells_to_solve, num_steps);

    check_cuda_error( cudaPeekAtLastError() );

    check_cuda_error(cudaFree(stims_currents_device));
    if(cells_to_solve_device) check_cuda_error(cudaFree(cells_to_solve_device));

}

__global__ void kernel_set_model_inital_conditions(real *sv, int num_volumes) {
    int threadID = blockDim.x * blockIdx.x + threadIdx.x;

    if (threadID < num_volumes) {

         *((real * )((char *) sv + pitch * 0) + threadID) = -69.1370441635924;
         *((real * )((char *) sv + pitch * 1) + threadID) = 136.781894160227;
         *((real * )((char *) sv + pitch * 2) + threadID) = 8.80420286531673;
         *((real * )((char *) sv + pitch * 3) + threadID) = 0.000101878186157052;
         *((real * )((char *) sv + pitch * 4) + threadID) = 0.0457562667986602;
         *((real * )((char *) sv + pitch * 5) + threadID) = 0.00550281999719088;
         *((real * )((char *) sv + pitch * 6) + threadID) = 0.313213286437995;
         *((real * )((char *) sv + pitch * 7) + threadID) = 0.00953708522974789;
         *((real * )((char *) sv + pitch * 8) + threadID) = 0.0417391656294997;
         *((real * )((char *) sv + pitch * 9) + threadID) = 0.190678733735145;
         *((real * )((char *) sv + pitch * 10) + threadID) = 0.238219836154029;
         *((real * )((char *) sv + pitch * 11) + threadID) = 0.000446818714055411;
         *((real * )((char *) sv + pitch * 12) + threadID) = 0.000287906256206415;
         *((real * )((char *) sv + pitch * 13) + threadID) = 0.989328560287987;
         *((real * )((char *) sv + pitch * 14) + threadID) = 0.995474890442185;
         *((real * )((char *) sv + pitch * 15) + threadID) = 0.999955429598213;
         *((real * )((char *) sv + pitch * 16) + threadID) = 0.96386101799501;
         *((real * )((char *) sv + pitch * 17) + threadID) = 0.00103618091196912;
         *((real * )((char *) sv + pitch * 18) + threadID) = 3.10836886659417;
         *((real * )((char *) sv + pitch * 19) + threadID) = 0.991580051907845;

    }
}

// Solving the model for each cell in the tissue matrix ni x nj
__global__ void solve_gpu(real dt, real *sv, real* stim_currents,
                          uint32_t *cells_to_solve, uint32_t num_cells_to_solve,
                          int num_steps)
{
    int threadID = blockDim.x * blockIdx.x + threadIdx.x;
    int sv_id;

    // Each thread solves one cell model
    if(threadID < num_cells_to_solve) {
        if(cells_to_solve)
            sv_id = cells_to_solve[threadID];
        else
            sv_id = threadID;

        real rDY[NEQ];

        for (int n = 0; n < num_steps; ++n) {

            RHS_gpu(sv, rDY, stim_currents[threadID], sv_id);

            // Solve the model using Forward Euler
            for(int i = 0; i < NEQ; i++) {
                *((real *) ((char *) sv + pitch * i) + sv_id) = dt * rDY[i] + *((real *) ((char *) sv + pitch * i) + sv_id);
            }            

        }

    }
}

inline __device__ void RHS_gpu(real *sv_, real *rDY_, real stim_current, int threadID_) {

    // States
    real STATES[NEQ];
    for (int i = 0; i < NEQ; i++)
        STATES[i] = *((real*)((char*)sv_ + pitch * i) + threadID_);

    // Constants
    real CONSTANTS[52];
    CONSTANTS[0] = 8314.472;
    CONSTANTS[1] = 310;
    CONSTANTS[2] = 96485.3415;
    CONSTANTS[3] = 0.185;
    CONSTANTS[4] = 0.016404;
    CONSTANTS[5] = 0.03;
    CONSTANTS[6] = 5.4;
    CONSTANTS[7] = 140;
    CONSTANTS[8] = 2;
    CONSTANTS[9] = 0.0145654;
    CONSTANTS[10] = 0.0234346;
    CONSTANTS[11] = 0.065;
    CONSTANTS[12] = 0.0918;
    CONSTANTS[13] = 0.2352;
    CONSTANTS[14] = 130.5744;
    CONSTANTS[15] = 0.00029;
    CONSTANTS[16] = 3.98e-5;
    CONSTANTS[17] = 0.000592;
    CONSTANTS[18] = 0.08184;
    CONSTANTS[19] = 0.0227;
    CONSTANTS[20] = 2.724;
    CONSTANTS[21] = 1;
    CONSTANTS[22] = 40;
    CONSTANTS[23] = 1000;
    CONSTANTS[24] = 0.1;
    CONSTANTS[25] = 2.5;
    CONSTANTS[26] = 0.35;
    CONSTANTS[27] = 1.38;
    CONSTANTS[28] = 87.5;
    CONSTANTS[29] = 0.1238;
    CONSTANTS[30] = 0.0005;
    CONSTANTS[31] = 0.0146;
    CONSTANTS[32] = 0.15;
    CONSTANTS[33] = 0.045;
    CONSTANTS[34] = 0.06;
    CONSTANTS[35] = 0.005;
    CONSTANTS[36] = 1.5;
    CONSTANTS[37] = 2.5;
    CONSTANTS[38] = 1;
    CONSTANTS[39] = 0.102;
    CONSTANTS[40] = 0.0038;
    CONSTANTS[41] = 0.00025;
    CONSTANTS[42] = 0.00036;
    CONSTANTS[43] = 0.006375;
    CONSTANTS[44] = 0.2;
    CONSTANTS[45] = 0.001;
    CONSTANTS[46] = 10;
    CONSTANTS[47] = 0.3;
    CONSTANTS[48] = 0.4;
    CONSTANTS[49] = 0.00025;
    CONSTANTS[50] = 0.001094;
    CONSTANTS[51] = 5.468e-5;

    // Algebraics
    real ALGEBRAIC[76];
    ALGEBRAIC[8] = 1.00000/(1.00000+exp((STATES[0]+20.0000)/7.00000));
    ALGEBRAIC[22] =  1102.50*exp(- powf(STATES[0]+27.0000, 2.00000)/225.000)+200.000/(1.00000+exp((13.0000 - STATES[0])/10.0000))+180.000/(1.00000+exp((STATES[0]+30.0000)/10.0000))+20.0000;
    ALGEBRAIC[9] = 0.670000/(1.00000+exp((STATES[0]+35.0000)/7.00000))+0.330000;
    ALGEBRAIC[23] =  562.000*exp(- powf(STATES[0]+27.0000, 2.00000)/240.000)+31.0000/(1.00000+exp((25.0000 - STATES[0])/10.0000))+80.0000/(1.00000+exp((STATES[0]+30.0000)/10.0000));
    ALGEBRAIC[10] = 0.600000/(1.00000+powf(STATES[11]/0.0500000, 2.00000))+0.400000;
    ALGEBRAIC[24] = 80.0000/(1.00000+powf(STATES[11]/0.0500000, 2.00000))+2.00000;
    ALGEBRAIC[11] = 1.00000/(1.00000+exp((STATES[0]+27.0000)/13.0000));
    ALGEBRAIC[25] =  85.0000*exp(- powf(STATES[0]+25.0000, 2.00000)/320.000)+5.00000/(1.00000+exp((STATES[0] - 40.0000)/5.00000))+42.0000;
    ALGEBRAIC[12] = 1.00000/(1.00000+exp((20.0000 - STATES[0])/13.0000));
    ALGEBRAIC[26] =  10.4500*exp(- powf(STATES[0]+40.0000, 2.00000)/1800.00)+7.30000;
    ALGEBRAIC[0] = 1.00000/(1.00000+exp((STATES[0]+80.6000)/6.80000));
    ALGEBRAIC[14] =  1.00000*exp(- 2.90000 -  0.0400000*STATES[0]);
    ALGEBRAIC[28] =  1.00000*exp(3.60000+ 0.110000*STATES[0]);
    ALGEBRAIC[37] = 4000.00/(ALGEBRAIC[14]+ALGEBRAIC[28]);
    ALGEBRAIC[1] = 1.00000/(1.00000+exp((- 26.0000 - STATES[0])/7.00000));
    ALGEBRAIC[15] = 450.000/(1.00000+exp((- 45.0000 - STATES[0])/10.0000));
    ALGEBRAIC[29] = 6.00000/(1.00000+exp((STATES[0]+30.0000)/11.5000));
    ALGEBRAIC[38] =  1.00000*ALGEBRAIC[15]*ALGEBRAIC[29];
    ALGEBRAIC[2] = 1.00000/(1.00000+exp((STATES[0]+88.0000)/24.0000));
    ALGEBRAIC[16] = 3.00000/(1.00000+exp((- 60.0000 - STATES[0])/20.0000));
    ALGEBRAIC[30] = 1.12000/(1.00000+exp((STATES[0] - 60.0000)/20.0000));
    ALGEBRAIC[39] =  1.00000*ALGEBRAIC[16]*ALGEBRAIC[30];
    ALGEBRAIC[3] = 1.00000/(1.00000+exp((- 5.00000 - STATES[0])/14.0000));
    ALGEBRAIC[17] = 1400.00/ powf((1.00000+exp((5.00000 - STATES[0])/6.00000)), 1.0 / 2);
    ALGEBRAIC[31] = 1.00000/(1.00000+exp((STATES[0] - 35.0000)/15.0000));
    ALGEBRAIC[40] =  1.00000*ALGEBRAIC[17]*ALGEBRAIC[31]+80.0000;
    ALGEBRAIC[4] = 1.00000/powf(1.00000+exp((- 56.8600 - STATES[0])/9.03000), 2.00000);
    ALGEBRAIC[18] = 1.00000/(1.00000+exp((- 60.0000 - STATES[0])/5.00000));
    ALGEBRAIC[32] = 0.100000/(1.00000+exp((STATES[0]+35.0000)/5.00000))+0.100000/(1.00000+exp((STATES[0] - 50.0000)/200.000));
    ALGEBRAIC[41] =  1.00000*ALGEBRAIC[18]*ALGEBRAIC[32];
    ALGEBRAIC[5] = 1.00000/powf(1.00000+exp((STATES[0]+71.5500)/7.43000), 2.00000);
    ALGEBRAIC[19] = (STATES[0]<- 40.0000 ?  0.0570000*exp(- (STATES[0]+80.0000)/6.80000) : 0.00000);
    ALGEBRAIC[33] = (STATES[0]<- 40.0000 ?  2.70000*exp( 0.0790000*STATES[0])+ 310000.*exp( 0.348500*STATES[0]) : 0.770000/( 0.130000*(1.00000+exp((STATES[0]+10.6600)/- 11.1000))));
    ALGEBRAIC[42] = 1.00000/(ALGEBRAIC[19]+ALGEBRAIC[33]);
    ALGEBRAIC[6] = 1.00000/powf(1.00000+exp((STATES[0]+71.5500)/7.43000), 2.00000);
    ALGEBRAIC[20] = (STATES[0]<- 40.0000 ? (( ( - 25428.0*exp( 0.244400*STATES[0]) -  6.94800e-06*exp( - 0.0439100*STATES[0]))*(STATES[0]+37.7800))/1.00000)/(1.00000+exp( 0.311000*(STATES[0]+79.2300))) : 0.00000);
    ALGEBRAIC[34] = (STATES[0]<- 40.0000 ? ( 0.0242400*exp( - 0.0105200*STATES[0]))/(1.00000+exp( - 0.137800*(STATES[0]+40.1400))) : ( 0.600000*exp( 0.0570000*STATES[0]))/(1.00000+exp( - 0.100000*(STATES[0]+32.0000))));
    ALGEBRAIC[43] = 1.00000/(ALGEBRAIC[20]+ALGEBRAIC[34]);
    ALGEBRAIC[7] = 1.00000/(1.00000+exp((- 8.00000 - STATES[0])/7.50000));
    ALGEBRAIC[21] = 1.40000/(1.00000+exp((- 35.0000 - STATES[0])/13.0000))+0.250000;
    ALGEBRAIC[35] = 1.40000/(1.00000+exp((STATES[0]+5.00000)/5.00000));
    ALGEBRAIC[44] = 1.00000/(1.00000+exp((50.0000 - STATES[0])/20.0000));
    ALGEBRAIC[46] =  1.00000*ALGEBRAIC[21]*ALGEBRAIC[35]+ALGEBRAIC[44];
    ALGEBRAIC[61] = (( (( CONSTANTS[20]*CONSTANTS[6])/(CONSTANTS[6]+CONSTANTS[21]))*STATES[2])/(STATES[2]+CONSTANTS[22]))/(1.00000+ 0.124500*exp(( - 0.100000*STATES[0]*CONSTANTS[2])/( CONSTANTS[0]*CONSTANTS[1]))+ 0.0353000*exp(( - STATES[0]*CONSTANTS[2])/( CONSTANTS[0]*CONSTANTS[1])));
    ALGEBRAIC[13] =  (( CONSTANTS[0]*CONSTANTS[1])/CONSTANTS[2])*log(CONSTANTS[7]/STATES[2]);
    ALGEBRAIC[54] =  CONSTANTS[14]*powf(STATES[8], 3.00000)*STATES[9]*STATES[10]*(STATES[0] - ALGEBRAIC[13]);
    ALGEBRAIC[55] =  CONSTANTS[15]*(STATES[0] - ALGEBRAIC[13]);
    ALGEBRAIC[62] = ( CONSTANTS[23]*( exp(( CONSTANTS[26]*STATES[0]*CONSTANTS[2])/( CONSTANTS[0]*CONSTANTS[1]))*powf(STATES[2], 3.00000)*CONSTANTS[8] -  exp(( (CONSTANTS[26] - 1.00000)*STATES[0]*CONSTANTS[2])/( CONSTANTS[0]*CONSTANTS[1]))*powf(CONSTANTS[7], 3.00000)*STATES[3]*CONSTANTS[25]))/( (powf(CONSTANTS[28], 3.00000)+powf(CONSTANTS[7], 3.00000))*(CONSTANTS[27]+CONSTANTS[8])*(1.00000+ CONSTANTS[24]*exp(( (CONSTANTS[26] - 1.00000)*STATES[0]*CONSTANTS[2])/( CONSTANTS[0]*CONSTANTS[1]))));
    ALGEBRAIC[47] =  STATES[4]*CONSTANTS[9]*(STATES[0] - ALGEBRAIC[13]);
    ALGEBRAIC[27] =  (( CONSTANTS[0]*CONSTANTS[1])/CONSTANTS[2])*log(CONSTANTS[6]/STATES[1]);
    ALGEBRAIC[50] = 1.00000/(1.00000+exp( 0.100000*(STATES[0]+75.4400)));
    ALGEBRAIC[51] =  CONSTANTS[11]*ALGEBRAIC[50]*((STATES[0] - 8.00000) - ALGEBRAIC[27]);
    ALGEBRAIC[58] =  CONSTANTS[18]*STATES[17]*STATES[16]*(STATES[0] - ALGEBRAIC[27]);
    ALGEBRAIC[59] = 1.00000/(1.00000+exp((5.00000 - STATES[0])/17.0000));
    ALGEBRAIC[60] =  CONSTANTS[19]*ALGEBRAIC[59]*(STATES[0] - ALGEBRAIC[27]);
    ALGEBRAIC[52] =  CONSTANTS[12]* powf((CONSTANTS[6]/5.40000), 1.0 / 2)*STATES[5]*STATES[6]*(STATES[0] - ALGEBRAIC[27]);
    ALGEBRAIC[36] =  (( CONSTANTS[0]*CONSTANTS[1])/CONSTANTS[2])*log((CONSTANTS[6]+ CONSTANTS[5]*CONSTANTS[7])/(STATES[1]+ CONSTANTS[5]*STATES[2]));
    ALGEBRAIC[53] =  CONSTANTS[13]*powf(STATES[7], 2.00000)*(STATES[0] - ALGEBRAIC[36]);
    ALGEBRAIC[56] = ( (( CONSTANTS[16]*STATES[12]*STATES[13]*STATES[14]*STATES[15]*4.00000*(STATES[0] - 15.0000)*powf(CONSTANTS[2], 2.00000))/( CONSTANTS[0]*CONSTANTS[1]))*( 0.250000*STATES[11]*exp(( 2.00000*(STATES[0] - 15.0000)*CONSTANTS[2])/( CONSTANTS[0]*CONSTANTS[1])) - CONSTANTS[8]))/(exp(( 2.00000*(STATES[0] - 15.0000)*CONSTANTS[2])/( CONSTANTS[0]*CONSTANTS[1])) - 1.00000);
    ALGEBRAIC[45] =  (( 0.500000*CONSTANTS[0]*CONSTANTS[1])/CONSTANTS[2])*log(CONSTANTS[8]/STATES[3]);
    ALGEBRAIC[57] =  CONSTANTS[17]*(STATES[0] - ALGEBRAIC[45]);
    ALGEBRAIC[64] = ( CONSTANTS[31]*(STATES[0] - ALGEBRAIC[27]))/(1.00000+exp((25.0000 - STATES[0])/5.98000));
    ALGEBRAIC[63] = ( CONSTANTS[29]*STATES[3])/(STATES[3]+CONSTANTS[30]);
    ALGEBRAIC[48] =  STATES[4]*CONSTANTS[10]*(STATES[0] - ALGEBRAIC[27]);
    ALGEBRAIC[49] = ALGEBRAIC[47]+ALGEBRAIC[48];
    ALGEBRAIC[65] = CONSTANTS[43]/(1.00000+powf(CONSTANTS[41], 2.00000)/powf(STATES[3], 2.00000));
    ALGEBRAIC[66] =  CONSTANTS[42]*(STATES[18] - STATES[3]);
    ALGEBRAIC[67] =  CONSTANTS[40]*(STATES[11] - STATES[3]);
    ALGEBRAIC[69] = 1.00000/(1.00000+( CONSTANTS[44]*CONSTANTS[45])/powf(STATES[3]+CONSTANTS[45], 2.00000));
    ALGEBRAIC[68] = CONSTANTS[37] - (CONSTANTS[37] - CONSTANTS[38])/(1.00000+powf(CONSTANTS[36]/STATES[18], 2.00000));
    ALGEBRAIC[71] =  CONSTANTS[33]*ALGEBRAIC[68];
    ALGEBRAIC[70] = CONSTANTS[32]/ALGEBRAIC[68];
    ALGEBRAIC[72] = ( ALGEBRAIC[70]*powf(STATES[11], 2.00000)*STATES[19])/(CONSTANTS[34]+ ALGEBRAIC[70]*powf(STATES[11], 2.00000));
    ALGEBRAIC[73] =  CONSTANTS[39]*ALGEBRAIC[72]*(STATES[18] - STATES[11]);
    ALGEBRAIC[74] = 1.00000/(1.00000+( CONSTANTS[46]*CONSTANTS[47])/powf(STATES[18]+CONSTANTS[47], 2.00000));
    ALGEBRAIC[75] = 1.00000/(1.00000+( CONSTANTS[48]*CONSTANTS[49])/powf(STATES[11]+CONSTANTS[49], 2.00000));

    // Rates
    //  ** I manually added the stimulus current
    real RATES[NEQ];
    RATES[0] =  (- 1.00000/1.00000)*(ALGEBRAIC[51]+ALGEBRAIC[58]+ALGEBRAIC[60]+ALGEBRAIC[52]+ALGEBRAIC[53]+ALGEBRAIC[56]+ALGEBRAIC[61]+ALGEBRAIC[54]+ALGEBRAIC[55]+ALGEBRAIC[62]+ALGEBRAIC[57]+ALGEBRAIC[64]+ALGEBRAIC[63]+ALGEBRAIC[49]+stim_current);
    RATES[1] =  (( - 1.00000*((ALGEBRAIC[51]+ALGEBRAIC[58]+ALGEBRAIC[48]+ALGEBRAIC[60]+ALGEBRAIC[52]+ALGEBRAIC[53]+ALGEBRAIC[64]) -  2.00000*ALGEBRAIC[61]))/( 1.00000*CONSTANTS[4]*CONSTANTS[2]))*CONSTANTS[3];
    RATES[2] =  (( - 1.00000*(ALGEBRAIC[54]+ALGEBRAIC[55]+ALGEBRAIC[47]+ 3.00000*ALGEBRAIC[61]+ 3.00000*ALGEBRAIC[62]))/( 1.00000*CONSTANTS[4]*CONSTANTS[2]))*CONSTANTS[3];
    RATES[3] =  ALGEBRAIC[69]*((( (ALGEBRAIC[66] - ALGEBRAIC[65])*CONSTANTS[50])/CONSTANTS[4]+ALGEBRAIC[67]) - ( 1.00000*((ALGEBRAIC[57]+ALGEBRAIC[63]) -  2.00000*ALGEBRAIC[62])*CONSTANTS[3])/( 2.00000*1.00000*CONSTANTS[4]*CONSTANTS[2]));
    RATES[4] = (ALGEBRAIC[0] - STATES[4])/ALGEBRAIC[37];
    RATES[5] = (ALGEBRAIC[1] - STATES[5])/ALGEBRAIC[38];
    RATES[6] = (ALGEBRAIC[2] - STATES[6])/ALGEBRAIC[39];
    RATES[7] = (ALGEBRAIC[3] - STATES[7])/ALGEBRAIC[40];
    RATES[8] = (ALGEBRAIC[4] - STATES[8])/ALGEBRAIC[41];
    RATES[9] = (ALGEBRAIC[5] - STATES[9])/ALGEBRAIC[42];
    RATES[10] = (ALGEBRAIC[6] - STATES[10])/ALGEBRAIC[43];
    RATES[11] =  ALGEBRAIC[75]*((( - 1.00000*ALGEBRAIC[56]*CONSTANTS[3])/( 2.00000*1.00000*CONSTANTS[51]*CONSTANTS[2])+( ALGEBRAIC[73]*CONSTANTS[50])/CONSTANTS[51]) - ( ALGEBRAIC[67]*CONSTANTS[4])/CONSTANTS[51]);
    RATES[12] = (ALGEBRAIC[7] - STATES[12])/ALGEBRAIC[46];
    RATES[13] = (ALGEBRAIC[8] - STATES[13])/ALGEBRAIC[22];
    RATES[14] = (ALGEBRAIC[9] - STATES[14])/ALGEBRAIC[23];
    RATES[15] = (ALGEBRAIC[10] - STATES[15])/ALGEBRAIC[24];
    RATES[16] = (ALGEBRAIC[11] - STATES[16])/ALGEBRAIC[25];
    RATES[17] = (ALGEBRAIC[12] - STATES[17])/ALGEBRAIC[26];
    RATES[18] =  ALGEBRAIC[74]*(ALGEBRAIC[65] - (ALGEBRAIC[73]+ALGEBRAIC[66]));
    RATES[19] =  - ALGEBRAIC[71]*STATES[11]*STATES[19]+ CONSTANTS[35]*(1.00000 - STATES[19]);

    for (int i = 0; i < NEQ; i++)
        rDY_[i] = RATES[i];

}

