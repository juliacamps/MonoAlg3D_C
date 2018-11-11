#include "fhn_mod.h"

GET_CELL_MODEL_DATA(init_cell_model_data) {

    if(get_initial_v)
        cell_model->initial_v = INITIAL_V;
    if(get_neq)
        cell_model->number_of_ode_equations = NEQ;
}

SET_ODE_INITIAL_CONDITIONS_CPU(set_model_initial_conditions_cpu) {

    static bool first_call = true;

    if(first_call) {
        print_to_stdout_and_file("Using modified FHN 1961 CPU model\n");
        first_call = false;
    }

    sv[0] = 0.000000f; //Vm millivolt
    sv[1] = 0.000000f; //v dimensionless
}

SOLVE_MODEL_ODES_CPU(solve_model_odes_cpu) {

    uint32_t sv_id;

	uint32_t i;

    #pragma omp parallel for private(sv_id)
    for (i = 0; i < num_cells_to_solve; i++) {

        if(cells_to_solve)
            sv_id = cells_to_solve[i];
        else
            sv_id = i;

        for (int j = 0; j < num_steps; ++j) {
            solve_model_ode_cpu(dt, sv + (sv_id * NEQ), stim_currents[i]);

        }
    }
}

void solve_model_ode_cpu(real dt, real *sv, real stim_current)  {

    real rY[NEQ], rDY[NEQ];

    for(int i = 0; i < NEQ; i++)
        rY[i] = sv[i];

    RHS_cpu(rY, rDY, stim_current);

    for(int i = 0; i < NEQ; i++)
        sv[i] = dt*rDY[i] + rY[i];
}

void RHS_cpu(const real *sv, real *rDY_, real stim_current) {

    //State variables
    const real u = sv[0];
    const real v = sv[1];

    const real a = 0.2;
    const real b = 0.5;
    const real k = 36.0;
    const real epsilon  = 0.000045;

    real calc_I_stim = stim_current;

    real calc_u = k*(u*(1 - u)*(u - a) - u*v);
    real calc_v = k*(epsilon*(b*u - v));


    rDY_[0] = calc_u + calc_I_stim;
    rDY_[1] = calc_v;


}

