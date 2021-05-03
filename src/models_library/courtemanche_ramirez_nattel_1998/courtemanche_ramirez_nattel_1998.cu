#include "courtemanche_ramirez_nattel_1998.h"
#include <stddef.h>
#include <stdint.h>

__constant__  size_t pitch;
__constant__  real abstol;
__constant__  real reltol;
__constant__  real max_dt;
__constant__  real min_dt;
__constant__  uint8_t use_adpt;
size_t pitch_h;

extern "C" SET_ODE_INITIAL_CONDITIONS_GPU(set_model_initial_conditions_gpu) {

    uint8_t use_adpt_h = (uint8_t)solver->adaptive;

    check_cuda_error(cudaMemcpyToSymbol(use_adpt, &use_adpt_h, sizeof(uint8_t)));
    log_info("Using courtemanche_ramirez_nattel_1998 GPU model\n");

    uint32_t num_volumes = solver->original_num_cells;

    if(use_adpt_h) {
        real reltol_h = solver->rel_tol;
        real abstol_h = solver->abs_tol;
        real max_dt_h = solver->max_dt;
        real min_dt_h = solver->min_dt;

		check_cuda_error(cudaMemcpyToSymbol(reltol, &reltol_h, sizeof(real)));
        check_cuda_error(cudaMemcpyToSymbol(abstol, &abstol_h, sizeof(real)));        
		check_cuda_error(cudaMemcpyToSymbol(max_dt, &max_dt_h, sizeof(real)));
        check_cuda_error(cudaMemcpyToSymbol(min_dt, &min_dt_h, sizeof(real)));
        log_info("Using Adaptive Euler model to solve the ODEs\n");
    } else {
        log_info("Using Euler model to solve the ODEs\n");
    }

    // execution configuration
	const int GRID = (num_volumes + BLOCK_SIZE - 1) / BLOCK_SIZE;

    size_t size = num_volumes * sizeof(real);

    if(use_adpt_h)
        check_cuda_error(cudaMallocPitch((void **)&(solver->sv), &pitch_h, size, (size_t)NEQ + 3));
    else
        check_cuda_error(cudaMallocPitch((void **)&(solver->sv), &pitch_h, size, (size_t)NEQ));

    check_cuda_error(cudaMemcpyToSymbol(pitch, &pitch_h, sizeof(size_t)));

    kernel_set_model_initial_conditions<<<GRID, BLOCK_SIZE>>>(solver->sv, num_volumes);

    check_cuda_error(cudaPeekAtLastError());
    cudaDeviceSynchronize();
    return pitch_h;
}

extern "C" SOLVE_MODEL_ODES(solve_model_odes_gpu) {

    size_t num_cells_to_solve = ode_solver->num_cells_to_solve;
    uint32_t * cells_to_solve = ode_solver->cells_to_solve;
    real *sv = ode_solver->sv;
    real dt = ode_solver->min_dt;
    uint32_t num_steps = ode_solver->num_steps;

    // execution configuration
    const int GRID = ((int)num_cells_to_solve + BLOCK_SIZE - 1) / BLOCK_SIZE;

    size_t stim_currents_size = sizeof(real) * num_cells_to_solve;
    size_t cells_to_solve_size = sizeof(uint32_t) * num_cells_to_solve;

    real *stims_currents_device;
    check_cuda_error(cudaMalloc((void **)&stims_currents_device, stim_currents_size));
    check_cuda_error(cudaMemcpy(stims_currents_device, stim_currents, stim_currents_size, cudaMemcpyHostToDevice));

    // the array cells to solve is passed when we are using and adapative mesh
    uint32_t *cells_to_solve_device = NULL;
    if(cells_to_solve != NULL) {
        check_cuda_error(cudaMalloc((void **)&cells_to_solve_device, cells_to_solve_size));
        check_cuda_error(
            cudaMemcpy(cells_to_solve_device, cells_to_solve, cells_to_solve_size, cudaMemcpyHostToDevice));
    }

    solve_gpu<<<GRID, BLOCK_SIZE>>>(current_t, dt, sv, stims_currents_device, cells_to_solve_device, num_cells_to_solve,
                                    num_steps);

    check_cuda_error(cudaPeekAtLastError());

    check_cuda_error(cudaFree(stims_currents_device));

    if(cells_to_solve_device)
        check_cuda_error(cudaFree(cells_to_solve_device));
}

__global__ void kernel_set_model_initial_conditions(real *sv, int num_volumes) {
    int threadID = blockDim.x * blockIdx.x + threadIdx.x;

    if (threadID < num_volumes) {

         *((real * )((char *) sv + pitch * 0) + threadID) = -8.118000e+01f; //V millivolt 
         *((real * )((char *) sv + pitch * 1) + threadID) = 2.908000e-03f; //m dimensionless 
         *((real * )((char *) sv + pitch * 2) + threadID) = 9.649000e-01f; //h dimensionless 
         *((real * )((char *) sv + pitch * 3) + threadID) = 9.775000e-01f; //j dimensionless 
         *((real * )((char *) sv + pitch * 4) + threadID) = 3.043000e-02f; //oa dimensionless 
         *((real * )((char *) sv + pitch * 5) + threadID) = 9.992000e-01f; //oi dimensionless 
         *((real * )((char *) sv + pitch * 6) + threadID) = 4.966000e-03f; //ua dimensionless 
         *((real * )((char *) sv + pitch * 7) + threadID) = 9.986000e-01f; //ui dimensionless 
         *((real * )((char *) sv + pitch * 8) + threadID) = 3.296000e-05f; //xr dimensionless 
         *((real * )((char *) sv + pitch * 9) + threadID) = 1.869000e-02f; //xs dimensionless 
         *((real * )((char *) sv + pitch * 10) + threadID) = 1.367000e-04f; //d dimensionless 
         *((real * )((char *) sv + pitch * 11) + threadID) = 9.996000e-01f; //f dimensionless 
         *((real * )((char *) sv + pitch * 12) + threadID) = 7.755000e-01f; //f_Ca dimensionless 
         *((real * )((char *) sv + pitch * 13) + threadID) = 0.0f; //u dimensionless
         *((real * )((char *) sv + pitch * 14) + threadID) = 1.000000e+00f; //v dimensionless 
         *((real * )((char *) sv + pitch * 15) + threadID) = 9.992000e-01f; //w dimensionless 
         *((real * )((char *) sv + pitch * 16) + threadID) = 1.117000e+01f; //Na_i millimolar 
         *((real * )((char *) sv + pitch * 17) + threadID) = 1.390000e+02f; //K_i millimolar 
         *((real * )((char *) sv + pitch * 18) + threadID) = 1.013000e-04f; //Ca_i millimolar 
         *((real * )((char *) sv + pitch * 19) + threadID) = 1.488000e+00f; //Ca_up millimolar 
         *((real * )((char *) sv + pitch * 20) + threadID) = 1.488000e+00f; //Ca_rel millimolar 

		 if(use_adpt) {
            *((real *)((char *)sv + pitch * 21) + threadID) = min_dt; // dt
            *((real *)((char *)sv + pitch * 22) + threadID) = 0.0;    // time_new
            *((real *)((char *)sv + pitch * 23) + threadID) = 0.0;    // previous dt
        }    
	}
}

//Include the default solver used by all models.
#include "../default_solvers.cu"

inline __device__ void RHS_gpu(real *sv, real *rDY, real stim_current, int thread_id, real dt) {

    //State variables
    real V_old_; //millivolt
    real m_old_; //dimensionless
    real h_old_; //dimensionless
    real j_old_; //dimensionless
    real oa_old_; //dimensionless
    real oi_old_; //dimensionless
    real ua_old_; //dimensionless
    real ui_old_; //dimensionless
    real xr_old_; //dimensionless
    real xs_old_; //dimensionless
    real d_old_; //dimensionless
    real f_old_; //dimensionless
    real f_Ca_old_; //dimensionless
    real u_old_; //dimensionless
    real v_old_; //dimensionless
    real w_old_; //dimensionless
    real Na_i_old_; //millimolar
    real K_i_old_; //millimolar
    real Ca_i_old_; //millimolar
    real Ca_up_old_; //millimolar
    real Ca_rel_old_; //millimolar


    if(use_adpt) {
        V_old_ =  sv[0];
        m_old_ =  sv[1];
        h_old_ =  sv[2];
        j_old_ =  sv[3];
        oa_old_ =  sv[4];
        oi_old_ =  sv[5];
        ua_old_ =  sv[6];
        ui_old_ =  sv[7];
        xr_old_ =  sv[8];
        xs_old_ =  sv[9];
        d_old_ =  sv[10];
        f_old_ =  sv[11];
        f_Ca_old_ =  sv[12];
        u_old_ =  sv[13];
        v_old_ =  sv[14];
        w_old_ =  sv[15];
        Na_i_old_ =  sv[16];
        K_i_old_ =  sv[17];
        Ca_i_old_ =  sv[18];
        Ca_up_old_ =  sv[19];
        Ca_rel_old_ =  sv[20];
    } else {
        V_old_ =  *((real*)((char*)sv + pitch * 0) + thread_id);
        m_old_ =  *((real*)((char*)sv + pitch * 1) + thread_id);
        h_old_ =  *((real*)((char*)sv + pitch * 2) + thread_id);
        j_old_ =  *((real*)((char*)sv + pitch * 3) + thread_id);
        oa_old_ =  *((real*)((char*)sv + pitch * 4) + thread_id);
        oi_old_ =  *((real*)((char*)sv + pitch * 5) + thread_id);
        ua_old_ =  *((real*)((char*)sv + pitch * 6) + thread_id);
        ui_old_ =  *((real*)((char*)sv + pitch * 7) + thread_id);
        xr_old_ =  *((real*)((char*)sv + pitch * 8) + thread_id);
        xs_old_ =  *((real*)((char*)sv + pitch * 9) + thread_id);
        d_old_ =  *((real*)((char*)sv + pitch * 10) + thread_id);
        f_old_ =  *((real*)((char*)sv + pitch * 11) + thread_id);
        f_Ca_old_ =  *((real*)((char*)sv + pitch * 12) + thread_id);
        u_old_ =  *((real*)((char*)sv + pitch * 13) + thread_id);
        v_old_ =  *((real*)((char*)sv + pitch * 14) + thread_id);
        w_old_ =  *((real*)((char*)sv + pitch * 15) + thread_id);
        Na_i_old_ =  *((real*)((char*)sv + pitch * 16) + thread_id);
        K_i_old_ =  *((real*)((char*)sv + pitch * 17) + thread_id);
        Ca_i_old_ =  *((real*)((char*)sv + pitch * 18) + thread_id);
        Ca_up_old_ =  *((real*)((char*)sv + pitch * 19) + thread_id);
        Ca_rel_old_ =  *((real*)((char*)sv + pitch * 20) + thread_id);
    }

    #include "courtemanche_ramirez_nattel_1998_common.inc.c"

}

