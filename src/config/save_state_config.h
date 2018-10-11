//
// Created by sachetto on 13/10/17.
//

#ifndef MONOALG3D_SAVE_STATE_CONFIG_H
#define MONOALG3D_SAVE_STATE_CONFIG_H

#include "config_common.h"
#include "../monodomain/constants.h"
#include "../monodomain/ode_solver.h"
#include "../alg/grid/grid.h"

//Forward declaration
struct save_state_config;
struct ode_solver;

#define SAVE_STATE(name) EXPORT_FN void name(struct save_state_config *config, \
                                             struct grid *the_grid, \
                                             struct ode_solver *the_ode_solver)

typedef SAVE_STATE(save_state_fn);


struct save_state_config {
    struct config_common config_data;    
    char *out_dir_name;
    bool out_dir_name_was_set;
    int save_rate;
    bool save_rate_was_set;

    save_state_fn *save_state;     
};

struct save_state_config* new_save_state_config();
void init_save_state_functions(struct save_state_config *config);
void free_save_state_config(struct save_state_config* s);
void print_save_state_config_values(struct save_state_config* s);


#endif //MONOALG3D_SAVE_CONFIG_H
