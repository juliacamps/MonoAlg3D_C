//
// Created by sachetto on 19/10/17.
//

#ifndef MONOALG3D_DOMAIN_HELPERS_H
#define MONOALG3D_DOMAIN_HELPERS_H

#include "../alg/grid/grid.h"

int get_num_refinement_steps_to_discretization (double side_len, double h);

void set_benchmark_domain (struct grid *the_grid);
void set_plain_domain (struct grid *the_grid, double sizeX, double sizeY, double sizeZ);

void set_custom_mesh(struct grid *the_grid, const char *file_name, int size, bool read_fibrosis);

void set_custom_mesh_with_bounds (struct grid *the_grid, const char *file_name, int size,
                                  double minx, double maxx, double miny, double maxy, double minz,
                                  double maxz,  bool read_fibrosis);

void set_cell_not_changeable (struct cell_node *c, double initialDiscretization);

void set_plain_fibrosis (struct grid *the_grid, double phi, unsigned fib_seed);

void set_plain_sphere_fibrosis (struct grid *the_grid, double phi, double plain_center, double sphere_radius,
                                double bz_size, double bz_radius, unsigned fib_seed);

void set_human_mesh_fibrosis(struct grid * grid, double phi, const char *scar_file, unsigned seed, double scar_center_x, double scar_center_y, double scar_center_z);

#endif // MONOALG3D_DOMAIN_HELPERS_H
