#include "../../gpu_utils/gpu_utils.h"
#include <stddef.h>
#include <stdint.h>

#include "bondarenko_2004.h"

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
    log_info("Using Bondarenko GPU model\n");

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

        *((real * )((char *) sv + pitch * 0) + threadID)  = -82.4202f;     // V millivolt
        *((real * )((char *) sv + pitch * 1) + threadID)  = 0.115001;     // Cai micromolar
        *((real * )((char *) sv + pitch * 2) + threadID)  = 0.115001;     // Cass micromolar
        *((real * )((char *) sv + pitch * 3) + threadID)  = 1299.5;     // CaJSR micromolar
        *((real * )((char *) sv + pitch * 4) + threadID)  = 1299.5;     // CaNSR micromolar
        *((real * )((char *) sv + pitch * 5) + threadID)  = 0.0;     // P_RyR dimensionless
        *((real * )((char *) sv + pitch * 6) + threadID)  = 11.2684;     // LTRPN_Ca micromolar
        *((real * )((char *) sv + pitch * 7) + threadID)  = 125.29;     // HTRPN_Ca micromolar
        *((real * )((char *) sv + pitch * 8) + threadID)  = 0.149102e-4;     // P_O1 dimensionless
        *((real * )((char *) sv + pitch * 9) + threadID)  = 0.951726e-10;     // P_O2 dimensionless
        *((real * )((char *) sv + pitch * 10) + threadID) = 0.16774e-3;     // P_C2 dimensionless
        *((real * )((char *) sv + pitch * 11) + threadID) = 0.930308e-18;     // O dimensionless
        *((real * )((char *) sv + pitch * 12) + threadID) = 0.124216e-3;     // C2 dimensionless
        *((real * )((char *) sv + pitch * 13) + threadID) = 0.578679e-8;     // C3 dimensionless
        *((real * )((char *) sv + pitch * 14) + threadID) = 0.119816e-12;     // C4 dimensionless
        *((real * )((char *) sv + pitch * 15) + threadID) = 0.497923e-18;     // I1 dimensionless
        *((real * )((char *) sv + pitch * 16) + threadID) = 0.345847e-13;     // I2 dimensionless
        *((real * )((char *) sv + pitch * 17) + threadID) = 0.185106e-13;     // I3 dimensionless
        *((real * )((char *) sv + pitch * 18) + threadID) = 14237.1;     // Nai micromolar
        *((real * )((char *) sv + pitch * 19) + threadID) = 0.020752;     // C_Na2 dimensionless
        *((real * )((char *) sv + pitch * 20) + threadID) = 0.279132e-3;     // C_Na1 dimensionless
        *((real * )((char *) sv + pitch * 21) + threadID) = 0.713483e-6;     // O_Na dimensionless
        *((real * )((char *) sv + pitch * 22) + threadID) = 0.153176e-3;     // IF_Na dimensionless
        *((real * )((char *) sv + pitch * 23) + threadID) = 0.673345e-6;     // I1_Na dimensionless
        *((real * )((char *) sv + pitch * 24) + threadID) = 0.155787e-8;     // I2_Na dimensionless
        *((real * )((char *) sv + pitch * 25) + threadID) = 0.0113879;     // IC_Na2 dimensionless
        *((real * )((char *) sv + pitch * 26) + threadID) = 0.34278;     // IC_Na3 dimensionless
        *((real * )((char *) sv + pitch * 27) + threadID) = 143720.0;     // Ki micromolar
        *((real * )((char *) sv + pitch * 28) + threadID) = 0.265563e-2;     // ato_f dimensionless
        *((real * )((char *) sv + pitch * 29) + threadID) = 0.999977;     // ito_f dimensionless
        *((real * )((char *) sv + pitch * 30) + threadID) = 0.417069e-3;     // ato_s dimensionless
        *((real * )((char *) sv + pitch * 31) + threadID) = 0.998543;     // ito_s dimensionless
        *((real * )((char *) sv + pitch * 32) + threadID) = 0.262753e-3;     // nKs dimensionless
        *((real * )((char *) sv + pitch * 33) + threadID) = 0.417069e-3;     // aur dimensionless
        *((real * )((char *) sv + pitch * 34) + threadID) = 0.998543;     // iur dimensionless
        *((real * )((char *) sv + pitch * 35) + threadID) = 0.417069e-3;     // aKss dimensionless
        *((real * )((char *) sv + pitch * 36) + threadID) = 1.0;     // iKss dimensionless
        *((real * )((char *) sv + pitch * 37) + threadID) = 0.641229e-3;     // C_K2 dimensionless
        *((real * )((char *) sv + pitch * 38) + threadID) = 0.992513e-3;     // C_K1 dimensionless
        *((real * )((char *) sv + pitch * 39) + threadID) = 0.175298e-3;     // O_K dimensionless
        *((real * )((char *) sv + pitch * 40) + threadID) = 0.319129e-4;     // I_K dimensionless

        if(use_adpt) {
            *((real *)((char *)sv + pitch * 41) + threadID) = min_dt; // dt
            *((real *)((char *)sv + pitch * 42) + threadID) = 0.0;    // time_new
            *((real *)((char *)sv + pitch * 43) + threadID) = 0.0;    // previous dt
        }

    }
}

#include "../default_solvers.cu"

inline __device__ void RHS_gpu(real *sv, real *rDY, real stim_current, int thread_id, real dt) {

    // State variables
    real V_old_;
    real Cai_old_;      
    real Cass_old_;     
    real CaJSR_old_;    
    real CaNSR_old_;    
    real P_RyR_old_;    
    real LTRPN_Ca_old_; 
    real HTRPN_Ca_old_; 
    real P_O1_old_;     
    real P_O2_old_;     
    real P_C2_old_;     
    real O_old_;
    real C2_old_;       
    real C3_old_;       
    real C4_old_;       
    real I1_old_;       
    real I2_old_;       
    real I3_old_;       
    real Nai_old_;      
    real C_Na2_old_;    
    real C_Na1_old_;    
    real O_Na_old_;     
    real IF_Na_old_;    
    real I1_Na_old_;    
    real I2_Na_old_;    
    real IC_Na2_old_;   
    real IC_Na3_old_;   
    real Ki_old_;       
    real ato_f_old_;    
    real ito_f_old_;    
    real ato_s_old_;    
    real ito_s_old_;    
    real nKs_old_;      
    real aur_old_;      
    real iur_old_;      
    real aKss_old_;     
    real iKss_old_;     
    real C_K2_old_;     
    real C_K1_old_;     
    real O_K_old_;      
    real I_K_old_;      
    
     if(use_adpt) {
         V_old_ = sv[0];        // initial value = -82.4202 millivolt
         Cai_old_ = sv[1];      // initial value = 0.115001 micromolar
         Cass_old_ = sv[2];     // initial value = 0.115001 micromolar
         CaJSR_old_ = sv[3];    // initial value = 1299.5 micromolar
         CaNSR_old_ = sv[4];    // initial value = 1299.5 micromolar
         P_RyR_old_ = sv[5];    // initial value = 0 dimensionless
         LTRPN_Ca_old_ = sv[6]; // initial value = 11.2684 micromolar
         HTRPN_Ca_old_ = sv[7]; // initial value = 125.29 micromolar
         P_O1_old_ = sv[8];     // initial value = 0.149102e-4 dimensionless
         P_O2_old_ = sv[9];     // initial value = 0.951726e-10 dimensionless
         P_C2_old_ = sv[10];    // initial value = 0.16774e-3 dimensionless
         O_old_ = sv[11];       // initial value = 0.930308e-18 dimensionless
         C2_old_ = sv[12];      // initial value = 0.124216e-3 dimensionless
         C3_old_ = sv[13];      // initial value = 0.578679e-8 dimensionless
         C4_old_ = sv[14];      // initial value = 0.119816e-12 dimensionless
         I1_old_ = sv[15];      // initial value = 0.497923e-18 dimensionless
         I2_old_ = sv[16];      // initial value = 0.345847e-13 dimensionless
         I3_old_ = sv[17];      // initial value = 0.185106e-13 dimensionless
         Nai_old_ = sv[18];     // initial value = 14237.1 micromolar
         C_Na2_old_ = sv[19];   // initial value = 0.020752 dimensionless
         C_Na1_old_ = sv[20];   // initial value = 0.279132e-3 dimensionless
         O_Na_old_ = sv[21];    // initial value = 0.713483e-6 dimensionless
         IF_Na_old_ = sv[22];   // initial value = 0.153176e-3 dimensionless
         I1_Na_old_ = sv[23];   // initial value = 0.673345e-6 dimensionless
         I2_Na_old_ = sv[24];   // initial value = 0.155787e-8 dimensionless
         IC_Na2_old_ = sv[25];  // initial value = 0.0113879 dimensionless
         IC_Na3_old_ = sv[26];  // initial value = 0.34278 dimensionless
         Ki_old_ = sv[27];      // initial value = 143720 micromolar
         ato_f_old_ = sv[28];   // initial value = 0.265563e-2 dimensionless
         ito_f_old_ = sv[29];   // initial value = 0.999977 dimensionless
         ato_s_old_ = sv[30];   // initial value = 0.417069e-3 dimensionless
         ito_s_old_ = sv[31];   // initial value = 0.998543 dimensionless
         nKs_old_ = sv[32];     // initial value = 0.262753e-3 dimensionless
         aur_old_ = sv[33];     // initial value = 0.417069e-3 dimensionless
         iur_old_ = sv[34];     // initial value = 0.998543 dimensionless
         aKss_old_ = sv[35];    // initial value = 0.417069e-3 dimensionless
         iKss_old_ = sv[36];    // initial value = 1 dimensionless
         C_K2_old_ = sv[37];    // initial value = 0.641229e-3 dimensionless
         C_K1_old_ = sv[38];    // initial value = 0.992513e-3 dimensionless
         O_K_old_ = sv[39];     // initial value = 0.175298e-3 dimensionless
         I_K_old_ = sv[40];     // initial value = 0.319129e-4 dimensionless
     }
     else {
         V_old_ = *((real *)((char *)sv + pitch * 0) + thread_id);        // initial value = -82.4202 millivolt
         Cai_old_ = *((real *)((char *)sv + pitch * 1) + thread_id);      // initial value = 0.115001 micromolar
         Cass_old_ = *((real *)((char *)sv + pitch * 2) + thread_id);     // initial value = 0.115001 micromolar
         CaJSR_old_ = *((real *)((char *)sv + pitch * 3) + thread_id);    // initial value = 1299.5 micromolar
         CaNSR_old_ = *((real *)((char *)sv + pitch * 4) + thread_id);    // initial value = 1299.5 micromolar
         P_RyR_old_ = *((real *)((char *)sv + pitch * 5) + thread_id);    // initial value = 0 dimensionless
         LTRPN_Ca_old_ = *((real *)((char *)sv + pitch * 6) + thread_id); // initial value = 11.2684 micromolar
         HTRPN_Ca_old_ = *((real *)((char *)sv + pitch * 7) + thread_id); // initial value = 125.29 micromolar
         P_O1_old_ = *((real *)((char *)sv + pitch * 8) + thread_id);     // initial value = 0.149102e-4 dimensionless
         P_O2_old_ = *((real *)((char *)sv + pitch * 9) + thread_id);     // initial value = 0.951726e-10 dimensionless
         P_C2_old_ = *((real *)((char *)sv + pitch * 10) + thread_id);    // initial value = 0.16774e-3 dimensionless
         O_old_ = *((real *)((char *)sv + pitch * 11) + thread_id);       // initial value = 0.930308e-18 dimensionless
         C2_old_ = *((real *)((char *)sv + pitch * 12) + thread_id);      // initial value = 0.124216e-3 dimensionless
         C3_old_ = *((real *)((char *)sv + pitch * 13) + thread_id);      // initial value = 0.578679e-8 dimensionless
         C4_old_ = *((real *)((char *)sv + pitch * 14) + thread_id);      // initial value = 0.119816e-12 dimensionless
         I1_old_ = *((real *)((char *)sv + pitch * 15) + thread_id);      // initial value = 0.497923e-18 dimensionless
         I2_old_ = *((real *)((char *)sv + pitch * 16) + thread_id);      // initial value = 0.345847e-13 dimensionless
         I3_old_ = *((real *)((char *)sv + pitch * 17) + thread_id);      // initial value = 0.185106e-13 dimensionless
         Nai_old_ = *((real *)((char *)sv + pitch * 18) + thread_id);     // initial value = 14237.1 micromolar
         C_Na2_old_ = *((real *)((char *)sv + pitch * 19) + thread_id);   // initial value = 0.020752 dimensionless
         C_Na1_old_ = *((real *)((char *)sv + pitch * 20) + thread_id);   // initial value = 0.279132e-3 dimensionless
         O_Na_old_ = *((real *)((char *)sv + pitch * 21) + thread_id);    // initial value = 0.713483e-6 dimensionless
         IF_Na_old_ = *((real *)((char *)sv + pitch * 22) + thread_id);   // initial value = 0.153176e-3 dimensionless
         I1_Na_old_ = *((real *)((char *)sv + pitch * 23) + thread_id);   // initial value = 0.673345e-6 dimensionless
         I2_Na_old_ = *((real *)((char *)sv + pitch * 24) + thread_id);   // initial value = 0.155787e-8 dimensionless
         IC_Na2_old_ = *((real *)((char *)sv + pitch * 25) + thread_id);  // initial value = 0.0113879 dimensionless
         IC_Na3_old_ = *((real *)((char *)sv + pitch * 26) + thread_id);  // initial value = 0.34278 dimensionless
         Ki_old_ = *((real *)((char *)sv + pitch * 27) + thread_id);      // initial value = 143720 micromolar
         ato_f_old_ = *((real *)((char *)sv + pitch * 28) + thread_id);   // initial value = 0.265563e-2 dimensionless
         ito_f_old_ = *((real *)((char *)sv + pitch * 29) + thread_id);   // initial value = 0.999977 dimensionless
         ato_s_old_ = *((real *)((char *)sv + pitch * 30) + thread_id);   // initial value = 0.417069e-3 dimensionless
         ito_s_old_ = *((real *)((char *)sv + pitch * 31) + thread_id);   // initial value = 0.998543 dimensionless
         nKs_old_ = *((real *)((char *)sv + pitch * 32) + thread_id);     // initial value = 0.262753e-3 dimensionless
         aur_old_ = *((real *)((char *)sv + pitch * 33) + thread_id);     // initial value = 0.417069e-3 dimensionless
         iur_old_ = *((real *)((char *)sv + pitch * 34) + thread_id);     // initial value = 0.998543 dimensionless
         aKss_old_ = *((real *)((char *)sv + pitch * 35) + thread_id);    // initial value = 0.417069e-3 dimensionless
         iKss_old_ = *((real *)((char *)sv + pitch * 36) + thread_id);    // initial value = 1 dimensionless
         C_K2_old_ = *((real *)((char *)sv + pitch * 37) + thread_id);    // initial value = 0.641229e-3 dimensionless
         C_K1_old_ = *((real *)((char *)sv + pitch * 38) + thread_id);    // initial value = 0.992513e-3 dimensionless
         O_K_old_ = *((real *)((char *)sv + pitch * 39) + thread_id);     // initial value = 0.175298e-3 dimensionless
         I_K_old_ = *((real *)((char *)sv + pitch * 40) + thread_id);     // initial value = 0.319129e-4 dimensionless
     }

    // Parameters
    const real Acap = 1.534e-4f;	 // cm2
    const real Cm = 1.0f;	 // microF_per_cm2
    const real Vmyo = 25.84e-6f;	 // microlitre
    const real F = 96.5f;	 // coulomb_per_millimole
    const real VJSR = 0.12e-6f;	 // microlitre
    const real Vss = 1.485e-9f;	 // microlitre
    const real VNSR = 2.098e-6f;	 // microlitre
    const real CMDN_tot = 50.0f;	 // micromolar
    const real Km_CMDN = 0.238f;	 // micromolar
    const real CSQN_tot = 15000.0f;	 // micromolar
    const real Km_CSQN = 800.0f;	 // micromolar
    const real v1 = 4.5f;	 // per_millisecond
    const real tau_tr = 20.0f;	 // millisecond
    const real tau_xfer = 8.0f;	 // millisecond
    const real v2 = 1.74e-5f;	 // per_millisecond
    const real v3 = 0.45f;	 // micromolar_per_millisecond
    const real Km_up = 0.5f;	 // micromolar
    const real k_plus_htrpn = 0.00237f;	 // per_micromolar_millisecond
    const real HTRPN_tot = 140.0f;	 // micromolar
    const real k_plus_ltrpn = 0.0327f;	 // per_micromolar_millisecond
    const real LTRPN_tot = 70.0f;	 // micromolar
    const real k_minus_htrpn = 3.2e-5f;	 // per_millisecond
    const real k_minus_ltrpn = 0.0196f;	 // per_millisecond
    const real i_CaL_max = 7.0f;	 // picoA_per_picoF
    const real k_plus_a = 0.006075f;	 // micromolar4_per_millisecond
    const real n = 4.0f;	 // dimensionless
    const real k_minus_b = 0.965f;	 // per_millisecond
    const real k_minus_c = 0.0008f;	 // per_millisecond
    const real k_minus_a = 0.07125f;	 // per_millisecond
    const real k_plus_b = 0.00405f;	 // micromolar3_per_millisecond
    const real m = 3.0f;	 // dimensionless
    const real k_plus_c = 0.009f;	 // per_millisecond
    const real g_CaL = 0.1729f;	 // milliS_per_microF
    const real E_CaL = 63.0f;	 // millivolt
    const real Kpcb = 0.0005f;	 // per_millisecond
    const real Kpc_max = 0.23324f;	 // per_millisecond
    const real Kpc_half = 20.0f;	 // micromolar
    const real i_pCa_max = 1.0f;	 // picoA_per_picoF
    const real Km_pCa = 0.5f;	 // micromolar
    const real k_NaCa = 292.8f;	 // picoA_per_picoF
    const real K_mNa = 87500.0f;	 // micromolar
    const real Nao = 140000.0f;	 // micromolar
    const real K_mCa = 1380.0f;	 // micromolar
    const real Cao = 1800.0f;	 // micromolar
    const real k_sat = 0.1f;	 // dimensionless
    const real eta = 0.35f;	 // dimensionless
    const real R = 8.314f;	 // joule_per_mole_kelvin
    const real T = 298.0f;	 // kelvin
    const real g_Cab = 0.000367f;	 // milliS_per_microF
    const real g_Na = 13.0f;	 // milliS_per_microF
    const real Ko = 5400.0f;	 // micromolar
    const real g_Nab = 0.0026f;	 // milliS_per_microF
    const real g_Kto_f = 0.4067f;	 // milliS_per_microF
    const real g_Kto_s = 0.0f;	 // milliS_per_microF
    const real g_Ks = 0.00575f;	 // milliS_per_microF
    const real g_Kur = 0.16f;	 // milliS_per_microF
    const real g_Kss = 0.05f;	 // milliS_per_microF
    const real g_Kr = 0.078f;	 // milliS_per_microF
    const real kf = 0.023761f;	 // per_millisecond
    const real kb = 0.036778f;	 // per_millisecond
    const real i_NaK_max = 0.88f;	 // picoA_per_picoF
    const real Km_Nai = 21000.0f;	 // micromolar
    const real Km_Ko = 1500.0f;	 // micromolar
    const real g_ClCa = 10.0f;	 // milliS_per_microF
    const real Km_Cl = 10.0f;	 // micromolar
    const real E_Cl = -40.0f;	 // millivolt

    // Algebraic Equations
    real calc_i_stim = stim_current;	//0

    real calc_Bi = pow((1.0f+((CMDN_tot*Km_CMDN)/pow((Km_CMDN+Cai_old_),2.0f))),(-1.0f));	//6
    real calc_Bss = pow((1.0f+((CMDN_tot*Km_CMDN)/pow((Km_CMDN+Cass_old_),2.0f))),(-1.0f));	//7
    real calc_BJSR = pow((1.0f+((CSQN_tot*Km_CSQN)/pow((Km_CSQN+CaJSR_old_),2.0f))),(-1.0f));	//8
    real calc_J_rel = (v1*(P_O1_old_+P_O2_old_)*(CaJSR_old_-Cass_old_)*P_RyR_old_);	//9
    real calc_J_tr = ((CaNSR_old_-CaJSR_old_)/tau_tr);	//10
    real calc_J_xfer = ((Cass_old_-Cai_old_)/tau_xfer);	//11
    real calc_J_leak = (v2*(CaNSR_old_-Cai_old_));	//12
    real calc_J_up = ((v3*pow(Cai_old_,2.0f))/(pow(Km_up,2.0f)+pow(Cai_old_,2.0f)));	//13
    real calc_J_trpn = (((k_plus_htrpn*Cai_old_*(HTRPN_tot-HTRPN_Ca_old_))+(k_plus_ltrpn*Cai_old_*(LTRPN_tot-LTRPN_Ca_old_)))-((k_minus_htrpn*HTRPN_Ca_old_)+(k_minus_ltrpn*LTRPN_Ca_old_)));	//14
    real calc_P_C1 = (1.0f-(P_C2_old_+P_O1_old_+P_O2_old_));	//19
    real calc_i_CaL = (g_CaL*O_old_*(V_old_-E_CaL));	//22
    real calc_C1 = (1.0f-(O_old_+C2_old_+C3_old_+C4_old_+I1_old_+I2_old_+I3_old_));	//24
    real calc_alpha = ((0.4f*exp(((V_old_+12.0f)/10.0f))*((1.0f+(0.7f*exp(((-pow((V_old_+40.0f),2.0f))/10.0f))))-(0.75f*exp(((-pow((V_old_+20.0f),2.0f))/400.0f)))))/(1.0f+(0.12f*exp(((V_old_+12.0f)/10.0f)))));	//31
    real calc_beta = (0.05f*exp(((-(V_old_+12.0f))/13.0f)));	//32
    real calc_gamma = ((Kpc_max*Cass_old_)/(Kpc_half+Cass_old_));	//33
    real calc_Kpcf = (13.0f*(1.0f-exp(((-pow((V_old_+14.5f),2.0f))/100.0f))));	//34
    real calc_i_pCa = ((i_pCa_max*pow(Cai_old_,2.0f))/(pow(Km_pCa,2.0f)+pow(Cai_old_,2.0f)));	//35
    real calc_i_NaCa = (((((((k_NaCa*1.0f)/(pow(K_mNa,3.0)+pow(Nao,3.0)))*1.0f)/(K_mCa+Cao))*1.0f)/(1.0f+(k_sat*exp((((eta-1.0f)*V_old_*F)/(R*T))))))*((exp(((eta*V_old_*F)/(R*T)))*pow(Nai_old_,3.0)*Cao)-(exp((((eta-1.0f)*V_old_*F)/(R*T)))*pow(Nao,3.0)*Cai_old_)));	//36
    real calc_E_CaN = (((R*T)/(2.0f*F))*log((Cao/Cai_old_)));	//38
    real calc_E_Na = (((R*T)/F)*log((((0.9f*Nao)+(0.1f*Ko))/((0.9f*Nai_old_)+(0.1f*Ki_old_)))));	//41
    real calc_C_Na3 = (1.0f-(O_Na_old_+C_Na1_old_+C_Na2_old_+IF_Na_old_+I1_Na_old_+I2_Na_old_+IC_Na2_old_+IC_Na3_old_));	//42
    real calc_alpha_Na11 = (3.802f/((0.1027f*exp(((-(V_old_+2.5f))/17.0f)))+(0.2f*exp(((-(V_old_+2.5f))/150.0f)))));	//51
    real calc_alpha_Na12 = (3.802f/((0.1027f*exp(((-(V_old_+2.5f))/15.0f)))+(0.23f*exp(((-(V_old_+2.5f))/150.0f)))));	//52
    real calc_alpha_Na13 = (3.802f/((0.1027f*exp(((-(V_old_+2.5f))/12.0f)))+(0.25f*exp(((-(V_old_+2.5f))/150.0f)))));	//53
    real calc_beta_Na11 = (0.1917f*exp(((-(V_old_+2.5f))/20.3f)));	//54
    real calc_beta_Na12 = (0.2f*exp(((-(V_old_-2.5f))/20.3f)));	//55
    real calc_beta_Na13 = (0.22f*exp(((-(V_old_-7.5f))/20.3f)));	//56
    real calc_alpha_Na3 = (7e-7f*exp(((-(V_old_+7.0f))/7.7f)));	//57
    real calc_beta_Na3 = (0.00854f+(0.00002f*V_old_));	//58
    real calc_alpha_Na2 = (1.0f/((0.188495f*exp(((-(V_old_+7.0f))/16.6f)))+0.393956f));	//59
    real calc_E_K = (((R*T)/F)*log((Ko/Ki_old_)));	//68
    real calc_alpha_a = (0.18064f*exp((0.03577f*(V_old_+ 30.0f))));	//71
    real calc_beta_a = (0.3956f*exp(((-0.06237f)*(V_old_+ 30.0f))));	//72
    real calc_alpha_i = ((0.000152f*exp(((-(V_old_+13.5f))/7.0f)))/((0.067083f*exp(((-(V_old_+33.5f))/7.0f)))+1.0f));	//73
    real calc_beta_i = ((0.00095f*exp(((V_old_+33.5f)/7.0f)))/((0.051335f*exp(((V_old_+33.5f)/7.0f)))+1.0f));	//74
    real calc_ass = (1.0f/(1.0f+exp(((-(V_old_+22.5f))/7.7f))));	//78
    real calc_iss = (1.0f/(1.0f+exp(((V_old_+45.2f)/5.7f))));	//79
    real calc_tau_ta_s = ((0.493f*exp(((-0.0629f)*V_old_)))+2.058f);	//80
    real calc_tau_ti_s = (270.0f+(1050.0f/(1.0f+exp(((V_old_+45.2f)/5.7f)))));	//81
    real calc_alpha_n = (V_old_ != -26.5f)?((0.00000481333f*(V_old_+26.5f))/(1.0f-exp(((-0.128f)*(V_old_+26.5f))))): 0.000037604f;   //85
    real calc_beta_n = (0.0000953333f*exp(((-0.038f)*(V_old_+26.5f))));	//86
    real calc_tau_aur = ((0.493f*exp(((-0.0629f)*V_old_)))+2.058f);	//90
    real calc_tau_iur = (1200.0f-(170.0f/(1.0f+exp(((V_old_+45.2f)/5.7f)))));	//91
    real calc_tau_Kss = ((39.3f*exp(((-0.0862f)*V_old_)))+13.17f);	//95
    real calc_i_Kr = (g_Kr*O_K_old_*(V_old_-(((R*T)/F)*log((((0.98f*Ko)+(0.02f*Nao))/((0.98f*Ki_old_)+(0.02f*Nai_old_)))))));	//96
    real calc_C_K0 = (1.0f-(C_K1_old_+C_K2_old_+O_K_old_+I_K_old_));	//97
    real calc_alpha_a0 = (0.022348f*exp((0.01176f*V_old_)));	//102
    real calc_beta_a0 = (0.047002f*exp(((-0.0631f)*V_old_)));	//103
    real calc_alpha_a1 = (0.013733f*exp((0.038198f*V_old_)));	//104
    real calc_beta_a1 = (0.0000689f*exp(((-0.04178f)*V_old_)));	//105
    real calc_alpha_i_duplicated_rapid_delayed_rectifier_potassium_current = (0.090821f*exp((0.023391f*(V_old_+5.0f))));	//106
    real calc_beta_i_duplicated_rapid_delayed_rectifier_potassium_current = (0.006497f*exp(((-0.03268f)*(V_old_+5.0f))));	//107
    real calc_sigma = ((1.0f/7.0f)*(exp((Nao/67300.0f))-1.0f));	//110
    real calc_O_ClCa = (0.2f/(1.0f+exp(((-(V_old_-46.7f))/7.8f))));	//112
    real calc_beta_Na2 = ((calc_alpha_Na13*calc_alpha_Na2*calc_alpha_Na3)/(calc_beta_Na13*calc_beta_Na3));	//60
    real calc_alpha_Na4 = (calc_alpha_Na2/1000.0f);	//61
    real calc_beta_Na4 = calc_alpha_Na3;	//62
    real calc_alpha_Na5 = (calc_alpha_Na2/95000.0f);	//63
    real calc_beta_Na5 = (calc_alpha_Na3/50.0f);	//64
    real calc_i_Nab = (g_Nab*(V_old_-calc_E_Na));	//65
    real calc_i_Kto_s = (g_Kto_s*ato_s_old_*ito_s_old_*(V_old_-calc_E_K));	//75
    real calc_i_K1 = ((((0.2938f*Ko)/(Ko+210.0f))*(V_old_-calc_E_K))/(1.0f+exp((0.0896f*(V_old_-calc_E_K)))));	//82
    real calc_i_Ks = (g_Ks*pow(nKs_old_,2.0f)*(V_old_-calc_E_K));	//83
    real calc_i_Kur = (g_Kur*aur_old_*iur_old_*(V_old_-calc_E_K));	//87
    real calc_i_Kss = (g_Kss*aKss_old_*iKss_old_*(V_old_-calc_E_K));	//92
    real calc_i_Cab = (g_Cab*(V_old_-calc_E_CaN));	//37
    real calc_i_Na = (g_Na*O_Na_old_*(V_old_-calc_E_Na));	//40
    real calc_i_Kto_f = (g_Kto_f*pow(ato_f_old_,3.0)*ito_f_old_*(V_old_-calc_E_K));	//67
    real calc_f_NaK = (1.0f/(1.0f+(0.1245f*exp((((-0.1f)*V_old_*F)/(R*T))))+(0.0365f*calc_sigma*exp((((-V_old_)*F)/(R*T))))));	//109
    real calc_i_ClCa = (((g_ClCa*calc_O_ClCa*Cai_old_)/(Cai_old_+Km_Cl))*(V_old_-E_Cl));	//111
    real calc_i_NaK = ((((i_NaK_max*calc_f_NaK*1.0f)/(1.0f+pow((Km_Nai/Nai_old_),1.5)))*Ko)/(Ko+Km_Ko));	//108

    // Differential Equations
    real d_dt_V = (-(calc_i_CaL+calc_i_pCa+calc_i_NaCa+calc_i_Cab+calc_i_Na+calc_i_Nab+calc_i_NaK+calc_i_Kto_f+calc_i_Kto_s+calc_i_K1+calc_i_Ks+calc_i_Kur+calc_i_Kss+calc_i_Kr+calc_i_ClCa+calc_i_stim));	// 1
    real d_dt_Cai = (calc_Bi*((calc_J_leak+calc_J_xfer)-(calc_J_up+calc_J_trpn+((((calc_i_Cab+calc_i_pCa)-(2.0f*calc_i_NaCa))*Acap*Cm)/(2.0f*Vmyo*F)))));	// 2
    real d_dt_Cass = (calc_Bss*(((calc_J_rel*VJSR)/Vss)-(((calc_J_xfer*Vmyo)/Vss)+((calc_i_CaL*Acap*Cm)/(2.0f*Vss*F)))));	// 3
    real d_dt_CaJSR = (calc_BJSR*(calc_J_tr-calc_J_rel));	// 4
    real d_dt_CaNSR = ((((calc_J_up-calc_J_leak)*Vmyo)/VNSR)-((calc_J_tr*VJSR)/VNSR));	// 5
    real d_dt_P_RyR = (((-0.04f)*P_RyR_old_)-(((0.1f*calc_i_CaL)/i_CaL_max)*exp(((-pow((V_old_-5.0f),2.0f))/648.0f))));	// 15
    real d_dt_LTRPN_Ca = ((k_plus_ltrpn*Cai_old_*(LTRPN_tot-LTRPN_Ca_old_))-(k_minus_ltrpn*LTRPN_Ca_old_));	// 16
    real d_dt_HTRPN_Ca = ((k_plus_htrpn*Cai_old_*(HTRPN_tot-HTRPN_Ca_old_))-(k_minus_htrpn*HTRPN_Ca_old_));	// 17
    real d_dt_P_O1 = (((k_plus_a*pow(Cass_old_,n)*calc_P_C1)+(k_minus_b*P_O2_old_)+(k_minus_c*P_C2_old_))-((k_minus_a*P_O1_old_)+(k_plus_b*pow(Cass_old_,m)*P_O1_old_)+(k_plus_c*P_O1_old_)));	// 18
    real d_dt_P_O2 = ((k_plus_b*pow(Cass_old_,m)*P_O1_old_)-(k_minus_b*P_O2_old_));	// 20
    real d_dt_P_C2 = ((k_plus_c*P_O1_old_)-(k_minus_c*P_C2_old_));	// 21
    real d_dt_O = (((calc_alpha*C4_old_)+(Kpcb*I1_old_)+(0.001f*((calc_alpha*I2_old_)-(calc_Kpcf*O_old_))))-((4.0f*calc_beta*O_old_)+(calc_gamma*O_old_)));	// 23
    real d_dt_C2 = (((4.0f*calc_alpha*calc_C1)+(2.0f*calc_beta*C3_old_))-((calc_beta*C2_old_)+(3.0f*calc_alpha*C2_old_)));	// 25
    real d_dt_C3 = (((3.0f*calc_alpha*C2_old_)+(3.0f*calc_beta*C4_old_))-((2.0f*calc_beta*C3_old_)+(2.0f*calc_alpha*C3_old_)));	// 26
    real d_dt_C4 = (((2.0f*calc_alpha*C3_old_)+(4.0f*calc_beta*O_old_)+(0.01f*((4.0f*Kpcb*calc_beta*I1_old_)-(calc_alpha*calc_gamma*C4_old_)))+(0.002f*((4.0f*calc_beta*I2_old_)-(calc_Kpcf*C4_old_)))+(4.0f*calc_beta*Kpcb*I3_old_))-((3.0f*calc_beta*C4_old_)+(calc_alpha*C4_old_)+(1.0f*calc_gamma*calc_Kpcf*C4_old_)));	// 27
    real d_dt_I1 = (((calc_gamma*O_old_)+(0.001f*((calc_alpha*I3_old_)-(calc_Kpcf*I1_old_)))+(0.01f*((calc_alpha*calc_gamma*C4_old_)-(4.0f*calc_beta*Kpcb*I1_old_))))-(Kpcb*I1_old_));	// 28
    real d_dt_I2 = (((0.001f*((calc_Kpcf*O_old_)-(calc_alpha*I2_old_)))+(Kpcb*I3_old_)+(0.002f*((calc_Kpcf*C4_old_)-(4.0f*calc_beta*I2_old_))))-(calc_gamma*I2_old_));	// 29
    real d_dt_I3 = (((0.001f*((calc_Kpcf*I1_old_)-(calc_alpha*I3_old_)))+(calc_gamma*I2_old_)+(1.0f*calc_gamma*calc_Kpcf*C4_old_))-((4.0f*calc_beta*Kpcb*I3_old_)+(Kpcb*I3_old_)));	// 30
    real d_dt_Nai = (((-(calc_i_Na+calc_i_Nab+(3.0f*calc_i_NaK)+(3.0f*calc_i_NaCa)))*Acap*Cm)/(Vmyo*F));	// 39
    real d_dt_C_Na2 = (((calc_alpha_Na11*calc_C_Na3)+(calc_beta_Na12*C_Na1_old_)+(calc_alpha_Na3*IC_Na2_old_))-((calc_beta_Na11*C_Na2_old_)+(calc_alpha_Na12*C_Na2_old_)+(calc_beta_Na3*C_Na2_old_)));	// 43
    real d_dt_C_Na1 = (((calc_alpha_Na12*C_Na2_old_)+(calc_beta_Na13*O_Na_old_)+(calc_alpha_Na3*IF_Na_old_))-((calc_beta_Na12*C_Na1_old_)+(calc_alpha_Na13*C_Na1_old_)+(calc_beta_Na3*C_Na1_old_)));	// 44
    real d_dt_O_Na = (((calc_alpha_Na13*C_Na1_old_)+(calc_beta_Na2*IF_Na_old_))-((calc_beta_Na13*O_Na_old_)+(calc_alpha_Na2*O_Na_old_)));	// 45
    real d_dt_IF_Na = (((calc_alpha_Na2*O_Na_old_)+(calc_beta_Na3*C_Na1_old_)+(calc_beta_Na4*I1_Na_old_)+(calc_alpha_Na12*IC_Na2_old_))-((calc_beta_Na2*IF_Na_old_)+(calc_alpha_Na3*IF_Na_old_)+(calc_alpha_Na4*IF_Na_old_)+(calc_beta_Na12*IF_Na_old_)));	// 46
    real d_dt_I1_Na = (((calc_alpha_Na4*IF_Na_old_)+(calc_beta_Na5*I2_Na_old_))-((calc_beta_Na4*I1_Na_old_)+(calc_alpha_Na5*I1_Na_old_)));	// 47
    real d_dt_I2_Na = ((calc_alpha_Na5*I1_Na_old_)-(calc_beta_Na5*I2_Na_old_));	// 48
    real d_dt_IC_Na2 = (((calc_alpha_Na11*IC_Na3_old_)+(calc_beta_Na12*IF_Na_old_)+(calc_beta_Na3*C_Na2_old_))-((calc_beta_Na11*IC_Na2_old_)+(calc_alpha_Na12*IC_Na2_old_)+(calc_alpha_Na3*IC_Na2_old_)));	// 49
    real d_dt_IC_Na3 = (((calc_beta_Na11*IC_Na2_old_)+(calc_beta_Na3*calc_C_Na3))-((calc_alpha_Na11*IC_Na3_old_)+(calc_alpha_Na3*IC_Na3_old_)));	// 50
    real d_dt_Ki = (((-((calc_i_Kto_f+calc_i_Kto_s+calc_i_K1+calc_i_Ks+calc_i_Kss+calc_i_Kur+calc_i_Kr)-(2.0f*calc_i_NaK)))*Acap*Cm)/(Vmyo*F));	// 66
    real d_dt_ato_f = ((calc_alpha_a*(1.0f-ato_f_old_))-(calc_beta_a*ato_f_old_));	// 69
    real d_dt_ito_f = ((calc_alpha_i*(1.0f-ito_f_old_))-(calc_beta_i*ito_f_old_));	// 70
    real d_dt_ato_s = ((calc_ass-ato_s_old_)/calc_tau_ta_s);	// 76
    real d_dt_ito_s = ((calc_iss-ito_s_old_)/calc_tau_ti_s);	// 77
    real d_dt_nKs = ((calc_alpha_n*(1.0f-nKs_old_))-(calc_beta_n*nKs_old_));	// 84
    real d_dt_aur = ((calc_ass-aur_old_)/calc_tau_aur);	// 88
    real d_dt_iur = ((calc_iss-iur_old_)/calc_tau_iur);	// 89
    real d_dt_aKss = ((calc_ass-aKss_old_)/calc_tau_Kss);	// 93
    real d_dt_iKss = 0.0f;	// 94
    real d_dt_C_K2 = (((kf*C_K1_old_)+(calc_beta_a1*O_K_old_))-((kb*C_K2_old_)+(calc_alpha_a1*C_K2_old_)));	// 98
    real d_dt_C_K1 = (((calc_alpha_a0*calc_C_K0)+(kb*C_K2_old_))-((calc_beta_a0*C_K1_old_)+(kf*C_K1_old_)));	// 99
    real d_dt_O_K = (((calc_alpha_a1*C_K2_old_)+(calc_beta_i_duplicated_rapid_delayed_rectifier_potassium_current*I_K_old_))-((calc_beta_a1*O_K_old_)+(calc_alpha_i_duplicated_rapid_delayed_rectifier_potassium_current*O_K_old_)));	// 100
    real d_dt_I_K = ((calc_alpha_i_duplicated_rapid_delayed_rectifier_potassium_current*O_K_old_)-(calc_beta_i_duplicated_rapid_delayed_rectifier_potassium_current*I_K_old_));	// 101

    rDY[0]  = d_dt_V;
    rDY[1]  = d_dt_Cai;
    rDY[2]  = d_dt_Cass;
    rDY[3]  = d_dt_CaJSR;
    rDY[4]  = d_dt_CaNSR;
    rDY[5]  = d_dt_P_RyR;
    rDY[6]  = d_dt_LTRPN_Ca;
    rDY[7]  = d_dt_HTRPN_Ca;
    rDY[8]  = d_dt_P_O1;
    rDY[9]  = d_dt_P_O2;
    rDY[10] = d_dt_P_C2;
    rDY[11] = d_dt_O;
    rDY[12] = d_dt_C2;
    rDY[13] = d_dt_C3;
    rDY[14] = d_dt_C4;
    rDY[15] = d_dt_I1;
    rDY[16] = d_dt_I2;
    rDY[17] = d_dt_I3;
    rDY[18] = d_dt_Nai;
    rDY[19] = d_dt_C_Na2;
    rDY[20] = d_dt_C_Na1;
    rDY[21] = d_dt_O_Na;
    rDY[22] = d_dt_IF_Na;
    rDY[23] = d_dt_I1_Na;
    rDY[24] = d_dt_I2_Na;
    rDY[25] = d_dt_IC_Na2;
    rDY[26] = d_dt_IC_Na3;
    rDY[27] = d_dt_Ki;
    rDY[28] = d_dt_ato_f;
    rDY[29] = d_dt_ito_f;
    rDY[30] = d_dt_ato_s;
    rDY[31] = d_dt_ito_s;
    rDY[32] = d_dt_nKs;
    rDY[33] = d_dt_aur;
    rDY[34] = d_dt_iur;
    rDY[35] = d_dt_aKss;
    rDY[36] = d_dt_iKss;
    rDY[37] = d_dt_C_K2;
    rDY[38] = d_dt_C_K1;
    rDY[39] = d_dt_O_K;
    rDY[40] = d_dt_I_K;
}
