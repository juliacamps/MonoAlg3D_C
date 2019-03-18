//
// Created by sachetto on 29/09/17.
//

#include "cell.h"
#include <math.h>

#include "../../single_file_libraries/stb_ds.h"


void init_basic_cell_data_with_type(struct basic_cell_data *data, char type) {
    data->type = type;
    data->level = 1;
}

struct cell_node *new_cell_node() {
    struct cell_node *result = (struct cell_node *)malloc(sizeof(struct cell_node));
    init_cell_node(result);
    return result;
}

void init_cell_node(struct cell_node *cell_node) {

    init_basic_cell_data_with_type(&(cell_node->cell_data), CELL_NODE_TYPE);

    cell_node->center_x = 0.0;
    cell_node->center_y = 0.0;
    cell_node->center_z = 0.0;

    cell_node->active = true;

    cell_node->bunch_number = 0;

    cell_node->north = NULL;
    cell_node->south = NULL;
    cell_node->east = NULL;
    cell_node->west = NULL;
    cell_node->front = NULL;
    cell_node->back = NULL;

    cell_node->previous = NULL;
    cell_node->next = NULL;

    cell_node->grid_position = 0;
    cell_node->sv_position = 0;
    cell_node->hilbert_shape_number = 0;
    cell_node->dx = 1.0;
    cell_node->dy = 1.0;
    cell_node->dz = 1.0;

    cell_node->v = 0;

    cell_node->north_flux = 0.0;
    cell_node->south_flux = 0.0;
    cell_node->east_flux = 0.0;
    cell_node->west_flux = 0.0;
    cell_node->front_flux = 0.0;
    cell_node->back_flux = 0.0;

    cell_node->b = 0.0;

    cell_node->can_change = true;
    cell_node->visited = false;

    cell_node->elements = NULL;

    cell_node->linear_system_solver_extra_info = NULL;
    cell_node->mesh_extra_info = NULL;

#if defined(_OPENMP)
    omp_init_lock(&(cell_node->updating));
#endif
}

void free_cell_node(struct cell_node *cell_node) {

    arrfree(cell_node->elements);
    free(cell_node->linear_system_solver_extra_info);
    free(cell_node->mesh_extra_info);

#if defined(_OPENMP)
    omp_destroy_lock(&(cell_node->updating));
#endif
    free(cell_node);
}



void lock_cell_node(struct cell_node *cell_node) {
#if defined(_OPENMP)
    omp_set_lock(&(cell_node->updating));
#endif
}

void unlock_cell_node(struct cell_node *cell_node) {
#if defined(_OPENMP)
    omp_unset_lock(&(cell_node->updating));
#endif
}

struct transition_node *new_transition_node() {
    struct transition_node *result = (struct transition_node *)malloc(sizeof(struct transition_node));
    init_transition_node(result);
    return result;
}

void init_transition_node(struct transition_node *transition_node) {

    init_basic_cell_data_with_type(&(transition_node->cell_data), TRANSITION_NODE_TYPE);

    transition_node->single_connector = NULL;
    transition_node->quadruple_connector1 = NULL;
    transition_node->quadruple_connector2 = NULL;
    transition_node->quadruple_connector3 = NULL;
    transition_node->quadruple_connector4 = NULL;
    transition_node->direction = 0;
}

void set_transition_node_data(struct transition_node *the_transition_node, uint16_t level, char direction,
                              void *single_connector, void *quadruple_connector1, void *quadruple_connector2,
                              void *quadruple_connector3, void *quadruple_connector4) {

    the_transition_node->cell_data.level = level;

    the_transition_node->direction = direction;

    the_transition_node->single_connector = single_connector;

    the_transition_node->quadruple_connector1 = quadruple_connector1;

    the_transition_node->quadruple_connector2 = quadruple_connector2;

    the_transition_node->quadruple_connector3 = quadruple_connector3;

    the_transition_node->quadruple_connector4 = quadruple_connector4;
}

void set_cell_node_data(struct cell_node *the_cell, float dx, float dy, float dz, uint64_t bunch_number,
                        void *east, void *north, void *west, void *south, void *front, void *back, void *previous,
                        void *next, uint32_t grid_position, uint8_t hilbert_shape_number, float center_x,
                        float center_y, float center_z) {
    the_cell->dx = dx;
    the_cell->dy = dy;
    the_cell->dz = dz;
    the_cell->bunch_number = bunch_number;
    the_cell->east = east;
    the_cell->north = north;
    the_cell->west = west;
    the_cell->south = south;
    the_cell->front = front;
    the_cell->back = back;
    the_cell->previous = previous;
    the_cell->next = next;
    the_cell->grid_position = grid_position;
    the_cell->hilbert_shape_number = hilbert_shape_number;
    the_cell->center_x = center_x;
    the_cell->center_y = center_y;
    the_cell->center_z = center_z;
}

void set_cell_flux(struct cell_node *the_cell, char direction) {

    void *neighbour_grid_cell;
    struct transition_node *white_neighbor_cell;
    struct cell_node *black_neighbor_cell;

    switch(direction) {
    case 'n':
        neighbour_grid_cell = the_cell->north;
        break;

    case 's':
        neighbour_grid_cell = the_cell->south;
        break;

    case 'e':
        neighbour_grid_cell = the_cell->east;
        break;

    case 'w':
        neighbour_grid_cell = the_cell->west;
        break;

    case 'f':
        neighbour_grid_cell = the_cell->front;
        break;

    case 'b':
        neighbour_grid_cell = the_cell->back;
        break;
    default:
        fprintf(stderr, "Invalid cell direction %c! Exiting...", direction);
        exit(10);
    }

    real_cpu leastDistance_x = the_cell->dx/2.0;
    real_cpu leastDistance_y = the_cell->dy/2.0;
    real_cpu leastDistance_z = the_cell->dz/2.0;

    real_cpu localFlux_x;
    real_cpu localFlux_y;
    real_cpu localFlux_z;

    bool has_found;

    /* When neighbour_grid_cell is a transition node, looks for the next neighbor
     * cell which is a cell node. */
    uint16_t neighbour_grid_cell_level = ((struct basic_cell_data *)(neighbour_grid_cell))->level;
    char neighbour_grid_cell_type = ((struct basic_cell_data *)(neighbour_grid_cell))->type;

    if(neighbour_grid_cell_level > the_cell->cell_data.level) {
        if(neighbour_grid_cell_type == TRANSITION_NODE_TYPE) {
            has_found = false;
            while(!has_found) {
                if(neighbour_grid_cell_type == TRANSITION_NODE_TYPE) {
                    white_neighbor_cell = (struct transition_node *)neighbour_grid_cell;
                    if(white_neighbor_cell->single_connector == NULL) {
                        has_found = true;
                    } else {
                        neighbour_grid_cell = white_neighbor_cell->quadruple_connector1;
                        neighbour_grid_cell_type = ((struct basic_cell_data *)(neighbour_grid_cell))->type;
                    }
                } else {
                    break;
                }
            }
        }
    } else {
        if(neighbour_grid_cell_level <= the_cell->cell_data.level && (neighbour_grid_cell_type == 'w')) {
            has_found = false;
            while(!has_found) {
                if(neighbour_grid_cell_type == TRANSITION_NODE_TYPE) {
                    white_neighbor_cell = (struct transition_node *)(neighbour_grid_cell);
                    if(white_neighbor_cell->single_connector == 0) {
                        has_found = true;
                    } else {
                        neighbour_grid_cell = white_neighbor_cell->single_connector;
                        neighbour_grid_cell_type = ((struct basic_cell_data *)(neighbour_grid_cell))->type;
                    }
                } else {
                    break;
                }
            }
        }
    }

    if(neighbour_grid_cell_type == CELL_NODE_TYPE) {

        black_neighbor_cell = (struct cell_node *)(neighbour_grid_cell);

        if(black_neighbor_cell->dx/2.0 < leastDistance_x)
            leastDistance_x = black_neighbor_cell->dx / 2.0;

        if(black_neighbor_cell->dy/2.0 < leastDistance_y)
            leastDistance_y = black_neighbor_cell->dy / 2.0;

        if(black_neighbor_cell->dz/2.0 < leastDistance_z)
            leastDistance_z = black_neighbor_cell->dz / 2.0;

        localFlux_x = (the_cell->v - black_neighbor_cell->v) * (2.0 * leastDistance_x);
        localFlux_y = (the_cell->v - black_neighbor_cell->v) * (2.0 * leastDistance_y);
        localFlux_z = (the_cell->v - black_neighbor_cell->v) * (2.0 * leastDistance_z);

        lock_cell_node(the_cell);

        switch(direction) {
            case 's':
                if(localFlux_y > the_cell->south_flux)
                    the_cell->south_flux += localFlux_y;
                break;

            case 'n':
                if(localFlux_y > the_cell->north_flux)
                    the_cell->north_flux += localFlux_y;
                break;

            case 'e':
                if(localFlux_x > the_cell->east_flux)
                    the_cell->east_flux += localFlux_x;
                break;

            case 'w':
                if(localFlux_x > the_cell->west_flux)
                    the_cell->west_flux += localFlux_x;
                break;

            case 'f':
                if(localFlux_z > the_cell->front_flux)
                    the_cell->front_flux += localFlux_z;
                break;

            case 'b':
                if(localFlux_z > the_cell->back_flux)
                    the_cell->back_flux += localFlux_z;
                break;

            default:break;
        }

        unlock_cell_node(the_cell);

        lock_cell_node(black_neighbor_cell);

        switch(direction) {
            case 's':
                if(localFlux_y > black_neighbor_cell->north_flux)
                    black_neighbor_cell->north_flux += localFlux_y;
                break;

            case 'n':
                if(localFlux_y > black_neighbor_cell->south_flux)
                    black_neighbor_cell->south_flux += localFlux_y;
                break;

            case 'e':
                if(localFlux_x > black_neighbor_cell->west_flux)
                    black_neighbor_cell->west_flux += localFlux_x;
                break;

            case 'w':
                if(localFlux_x > black_neighbor_cell->east_flux)
                    black_neighbor_cell->east_flux += localFlux_x;
                break;

            case 'f':
                if(localFlux_z > black_neighbor_cell->back_flux)
                    black_neighbor_cell->back_flux += localFlux_z;
                break;

            case 'b':
                if(localFlux_z > black_neighbor_cell->front_flux)
                    black_neighbor_cell->front_flux += localFlux_z;
                break;

             default:break;
        }

        unlock_cell_node(black_neighbor_cell);
    }
}

real_cpu get_cell_maximum_flux(struct cell_node *the_cell) {

    real_cpu maximumFlux = fabs(the_cell->east_flux);
    if(fabs(the_cell->north_flux) > maximumFlux)
        maximumFlux = fabs(the_cell->north_flux);

    if(fabs(the_cell->south_flux) > maximumFlux)
        maximumFlux = fabs(the_cell->south_flux);

    if(fabs(the_cell->west_flux) > maximumFlux)
        maximumFlux = fabs(the_cell->west_flux);

    if(fabs(the_cell->front_flux) > maximumFlux)
        maximumFlux = fabs(the_cell->front_flux);

    if(fabs(the_cell->back_flux) > maximumFlux)
        maximumFlux = fabs(the_cell->back_flux);

    return maximumFlux;
}
