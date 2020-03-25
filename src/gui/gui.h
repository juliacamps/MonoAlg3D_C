//
// Created by sachetto on 11/11/17.
//

#ifndef MONOALG3D_DRAW_H
#define MONOALG3D_DRAW_H

#include "../alg/grid/grid.h"
#include "../alg/cell/cell.h"
#include "../vtk_utils/vtk_unstructured_grid.h"
#include "../3dparty/raylib/src/raymath.h"

#include <omp.h>

#define DRAW_SIMULATION 0
#define DRAW_FILE 1

#define MIN_VERTICAL_TICKS 4
#define MAX_VERTICAL_TICKS 20

#define MIN_HORIZONTAL_TICKS 4
#define MAX_HORIZONTAL_TICKS 20

#define SIZEOF(A) (sizeof(A)/sizeof(A[0]))
#define WIDER_TEXT "------------------------------------------------------"
#define DOUBLE_CLICK_DELAY 0.8 //seconds

struct action_potential {
    real_cpu v;
    real_cpu t;
};

enum simulation_status {
    RESTART_SIMULATION,
    END_SIMULATION,
    SIMULATION_FINISHED,
};

struct ap_graph_config {

    Rectangle graph;
    float max_x;
    float min_y;
    float max_y;
    float min_x;

    Vector2 selected_ap_point;
    Vector2 selected_point_for_apd1;
    Vector2 selected_point_for_apd2;
    struct point_voidp_hash_entry *selected_aps;
    Rectangle drag_graph_button_position;
    Rectangle move_graph_button_position;
    bool drag_ap_graph;
    bool move_ap_graph;
    bool draw_selected_ap_text;

};

typedef struct action_potential * action_potential_array;

struct gui_config {

    real_cpu max_v;
    real_cpu min_v;
    bool simulating;
    bool paused;
    bool exit;
    bool adaptive;
    bool restart;
    real_cpu time;
    real_cpu final_time;
    real_cpu dt;
    int step;

    char *config_name;
    char *input;

    long solver_time;
    long ode_total_time;
    long cg_total_time;
    long total_mat_time;
    long total_ref_time;
    long total_deref_time;
    long total_write_time;
    long total_config_time;
    long total_cg_it;

    int advance_or_return;
    int draw_type;
    //If we are compiling this file, openmp is available.
    omp_lock_t draw_lock;
    omp_lock_t sleep_lock;

    struct grid_info {
        union {
            struct vtk_unstructured_grid *vtk_grid;
            struct grid *alg_grid;
        };
        char *file_name;
        bool loaded;
    } grid_info;

    char *error_message;
    bool int_scale;
};

struct gui_state {

    bool handle_keyboard_input;
    bool one_selected;
    bool show_ap;
    bool c_pressed;
    bool draw_grid_lines;
    bool draw_grid_only ;

    Rectangle help_box;
    bool show_help_box;
    bool move_help_box;

    Rectangle mesh_info_box;
    bool show_mesh_info_box;
    bool move_info_box;

    bool show_selection_box;

    Rectangle scale_bounds;
    bool show_scale;
    bool move_scale;

    Rectangle end_info_box;
    bool show_end_info_box;
    bool move_end_info_box;

    Ray ray;

    int current_scale;
    int scale_alpha;
    int voxel_alpha;

    Vector3 current_selected_volume;

    //Font font;
    float font_size_small;
    float font_size_big;

    double mouse_timer;
    double selected_time;

    Vector2 mouse_pos;
    Vector2 sub_window_pos;
    bool drag_sub_window;

    float box_width;
    float box_height;

    struct ap_graph_config *ap_graph_config;
};

struct mesh_info {
    bool center_calculated;
    Vector3 max_size;
    Vector3 min_size;
};

struct gui_config gui_config;

void init_and_open_gui_window();

#endif //MONOALG3D_DRAW_H