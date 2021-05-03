#include "Maleckar2008.h"
#include <stdlib.h>
real max_step;
real min_step;
real abstol;
real reltol;
bool adpt;
real *ode_dt, *ode_previous_dt, *ode_time_new;

GET_CELL_MODEL_DATA(init_cell_model_data) {

    if(get_initial_v)
        cell_model->initial_v = INITIAL_V;
    if(get_neq)
        cell_model->number_of_ode_equations = NEQ;
}

SET_ODE_INITIAL_CONDITIONS_CPU(set_model_initial_conditions_cpu) {

    log_info("Using Maleckar2008 CPU model\n");

    uint32_t num_cells = solver->original_num_cells;
    solver->sv = (real*)malloc(NEQ*num_cells*sizeof(real));

    max_step = solver->max_dt;
    min_step = solver->min_dt;
    abstol   = solver->abs_tol;
    reltol   = solver->rel_tol;
    adpt     = solver->adaptive;

    if(adpt) {
        ode_dt = (real*)malloc(num_cells*sizeof(real));

        OMP(parallel for)
        for(int i = 0; i < num_cells; i++) {
            ode_dt[i] = solver->min_dt;
        }

        ode_previous_dt = (real*)calloc(num_cells, sizeof(real));
        ode_time_new    = (real*)calloc(num_cells, sizeof(real));
        log_info("Using Adaptive Euler model to solve the ODEs\n");
    } else {
        log_info("Using Euler model to solve the ODEs\n");
    }
    OMP(parallel for)
    for(uint32_t i = 0; i < num_cells; i++) {

        real *sv = &solver->sv[i * NEQ];

        sv[0]  = -87.169816169406;
        sv[1]  = 0.001075453357;
        sv[2]  = 0.990691306716;
        sv[3]  = 0.993888937283;
        sv[4]  = 0.000018211252;
        sv[5]  = 0.979322592773;
        sv[6]  = 0.001208153482;
        sv[7]  = 0.000033616596;
        sv[8]  = 0.004173008466;
        sv[9]  = 0.015242594688;
        sv[10] = 0.007074239331;
        sv[11] = 0.048267587131;
        sv[12] = 0.105468807033;
        sv[13] = 0.00364776906;
        sv[14] = 0.174403618112;
        sv[15] = 0.003643592594;
        sv[16] = 0.993331326442;
        sv[17] = 97.505463697266;
        sv[18] = 0.006679257264;
        sv[19] = 11.441712311614;
        sv[20] = 1.716573130685;
        sv[21] = 0.226941113355;
        sv[22] = 0.256752008084;
        sv[23] = 104.450004990523;
        sv[24] = 22.171689894953;
        sv[25] = 19.864701949854;
    }
}

SOLVE_MODEL_ODES(solve_model_odes_cpu) {

    uint32_t sv_id;

    size_t num_cells_to_solve = ode_solver->num_cells_to_solve;
    uint32_t * cells_to_solve = ode_solver->cells_to_solve;
    real *sv = ode_solver->sv;
    real dt = ode_solver->min_dt;
    uint32_t num_steps = ode_solver->num_steps;

    #pragma omp parallel for private(sv_id)
    for (u_int32_t i = 0; i < num_cells_to_solve; i++) {

        if(cells_to_solve)
            sv_id = cells_to_solve[i];
        else
            sv_id = i;

        if(adpt) {

            solve_forward_euler_cpu_adpt(sv + (sv_id * NEQ), stim_currents[i], current_t + dt, sv_id);
        }
        else {
            for (int j = 0; j < num_steps; ++j) {
                solve_model_ode_cpu(dt, sv + (sv_id * NEQ), stim_currents[i]);
            }

        }

    }
}

#include "../default_solvers.c"

void RHS_cpu(const real *sv, real *rDY, real stim_current, real dt) {

    real var_cell__V = sv[0];
    real var_INa__xm = sv[1];
    real var_INa__xh = sv[2];
    real var_INa__xj = sv[3];
    real var_ICaL__c1 = sv[4];
    real var_ICaL__c2 = sv[5];
    real var_ICaL__xi1ca = sv[6];
    real var_ICaL__xi1ba = sv[7];
    real var_ICaL__xi2ca = sv[8];
    real var_ICaL__xi2ba = sv[9];
    real var_IKr__xr = sv[10];
    real var_IKs__xs1 = sv[11];
    real var_IKs__xs2 = sv[12];
    real var_Ito__xtos = sv[13];
    real var_Ito__ytos = sv[14];
    real var_Ito__xtof = sv[15];
    real var_Ito__ytof = sv[16];
    real var_Irel__Ca_JSR = sv[17];
    real var_Irel__xir = sv[18];
    real var_Na__Na_i = sv[19];
    real var_Ca__Ca_dyad = sv[20];
    real var_Ca__Ca_submem = sv[21];
    real var_Ca__Ca_i = sv[22];
    real var_Ca__Ca_NSR = sv[23];
    real var_Ca__tropi = sv[24];
    real var_Ca__trops = sv[25];

    #include "Maleckar2008_common.inc.c"

}

