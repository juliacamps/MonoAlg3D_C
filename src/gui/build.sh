SOURCE_FILES="gui.c gui_colors.c gui_window_helpers.c gui_mesh_helpers.c raylib_ext.c"
HEADER_FILES="gui.h gui_colors.h gui_window_helpers.h gui_mesh_helpers.h color_maps.h raylib_ext.h"
COMPILE_STATIC_LIB "gui" "$SOURCE_FILES" "$HEADER_FILES"
