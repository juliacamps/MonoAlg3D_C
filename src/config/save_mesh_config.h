//
// Created by sachetto on 13/10/17.
//

#ifndef MONOALG3D_SAVE_CONFIG_H
#define MONOALG3D_SAVE_CONFIG_H

#include "config_common.h"
#include "../monodomain/constants.h"
#include "../alg/grid/grid.h"

//Forward declaration
struct save_mesh_config;

#define SAVE_MESH(name) EXPORT_FN bool name(char* output_dir, double vm_threshold, struct save_mesh_config *config, struct grid *the_grid)
typedef SAVE_MESH(save_mesh_fn);

struct save_mesh_config {
    struct config_common config_data;
    int print_rate;
    bool print_rate_was_set;
    char * out_dir_name;
    bool out_dir_name_was_set;

    save_mesh_fn *save_mesh;
};

void init_save_mesh_functions(struct save_mesh_config *config);
struct save_mesh_config* new_save_mesh_config();
void free_save_mesh_config(struct save_mesh_config* s);
void print_save_mesh_config_values(struct save_mesh_config* s);


#endif //MONOALG3D_SAVE_CONFIG_H