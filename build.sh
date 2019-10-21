#!/bin/bash
OPTIONS_FILE=./bsbash/build_functions.sh
FUNCTIONS_FILE=./bsbash/find_functions.sh

if [ -f "$OPTIONS_FILE" ]; then
    source $OPTIONS_FILE
else
    echo "$OPTIONS_FILE not found, aborting compilation"
    exit 1
fi

if [ -f "$FUNCTIONS_FILE" ]; then
	source $FUNCTIONS_FILE
fi

GET_BUILD_OPTIONS "$@"

COMPILE_GUI='y'

if [ "$BUILD_TYPE" == "cluster" ]; then 
	C_FLAGS="$C_FLAGS -O3"
    COMPILE_GUI=''
fi

###########User code#####################
DEFAULT_C_FLAGS="-fopenmp -std=gnu99 -fno-strict-aliasing -Wall -Wno-unused-function -Wno-char-subscripts"
RUNTIME_OUTPUT_DIRECTORY="$ROOT_DIR/bin"
LIBRARY_OUTPUT_DIRECTORY="$ROOT_DIR/shared_libs"

C_FLAGS="$C_FLAGS $DEFAULT_C_FLAGS"

FIND_CUDA

echo -e "${INFO}C compiler:${NC} $C_COMPILER"
echo -e "${INFO}C++ compiler:${NC} $CXX_COMPILER"

if [ -n "$CUDA_FOUND" ]; then
    echo -e "${INFO}CUDA compiler:${NC} $NVCC"
    echo -e "${INFO}CUDA libraries path:${NC} $CUDA_LIBRARY_PATH"
    echo -e "${INFO}CUDA include path:${NC} $CUDA_INCLUDE_PATH"
    
    FILE=/etc/manjaro-release
    
    if test -f "$FILE"; then
        C_COMPILER=/opt/cuda/bin/gcc
        CXX_COMPILER=/opt/cuda/bin/g++
    fi
    
    C_FLAGS="${C_FLAGS} -DCOMPILE_CUDA -I${CUDA_INCLUDE_PATH}"
    
fi

if [ -n "$COMPILE_GUI" ]; then
    C_FLAGS="${C_FLAGS} -DCOMPILE_OPENGL"
fi

echo -e "${INFO}C FLAGS:${NC} $C_FLAGS"

ADD_SUBDIRECTORY "src/config_helpers"
ADD_SUBDIRECTORY "src/utils"
ADD_SUBDIRECTORY "src/alg"
ADD_SUBDIRECTORY "src/monodomain"
ADD_SUBDIRECTORY "src/ini_parser"
ADD_SUBDIRECTORY "src/string"
ADD_SUBDIRECTORY "src/config"
ADD_SUBDIRECTORY "src/graph"
ADD_SUBDIRECTORY "src/xml_parser"
ADD_SUBDIRECTORY "src/vtk_utils"

if [ -n "$COMPILE_GUI" ]; then
    ADD_SUBDIRECTORY "src/raylib/src"
    ADD_SUBDIRECTORY "src/draw"
    OPT_DEPS="draw raylib"
fi

if [ -n "$CUDA_FOUND" ]; then
    ADD_SUBDIRECTORY "src/gpu_utils"
    OPT_DEPS="${OPT_DEPS} gpu_utils"
fi

SRC_FILES="src/main_simulator.c"
HDR_FILES=""

STATIC_DEPS="solvers ini_parser string config ${OPT_DEPS} config_helpers vtk_utils yxml alg graph"
DYNAMIC_DEPS="dl m $CUDA_LIBRARIES z"

if [ -n "$COMPILE_GUI" ]; then
    DYNAMIC_DEPS="$DYNAMIC_DEPS OpenGL GLX GLU pthread X11 rt"
fi

DYNAMIC_DEPS="$DYNAMIC_DEPS utils"

COMPILE_EXECUTABLE "MonoAlg3D" "$SRC_FILES" "$HDR_FILES" "$STATIC_DEPS" "$DYNAMIC_DEPS" "$CUDA_LIBRARY_PATH $LIBRARY_OUTPUT_DIRECTORY"

FIND_MPI

if [ -n "$MPI_FOUND" ]; then
    SRC_FILES="src/main_batch.c"
    HDR_FILES=""
    DYNAMIC_DEPS="$DYNAMIC_DEPS $MPI_LIBRARIES"
    EXTRA_LIB_PATH="$CUDA_LIBRARY_PATH $MPI_LIBRARY_PATH $LIBRARY_OUTPUT_DIRECTORY"

    if [ -n "$MPI_INCLUDE_PATH" ]; then
      INCLUDE_P="-I$MPI_INCLUDE_PATH"
    fi
    COMPILE_EXECUTABLE "MonoAlg3D_batch" "$SRC_FILES" "$HDR_FILES" "$STATIC_DEPS" "$DYNAMIC_DEPS" "$EXTRA_LIB_PATH" "$INCLUDE_P"
fi

ADD_SUBDIRECTORY "src/models_library"
ADD_SUBDIRECTORY "src/stimuli_library"
ADD_SUBDIRECTORY "src/domains_library"
ADD_SUBDIRECTORY "src/purkinje_library"
ADD_SUBDIRECTORY "src/extra_data_library"
ADD_SUBDIRECTORY "src/matrix_assembly_library"
ADD_SUBDIRECTORY "src/linear_system_solver_library"
ADD_SUBDIRECTORY "src/save_mesh_library"
ADD_SUBDIRECTORY "src/save_state_library"
ADD_SUBDIRECTORY "src/restore_state_library"
ADD_SUBDIRECTORY "src/update_monodomain_library"
ADD_SUBDIRECTORY "src/modify_domain"

if [ -n "$COMPILE_GUI" ]; then
    COMPILE_EXECUTABLE "MonoAlg3D_visualizer" "src/main_visualizer.c" "" "$STATIC_DEPS" "$DYNAMIC_DEPS" "$EXTRA_LIB_PATH"
fi

FIND_CRITERION

if [ -n "$CRITERION_FOUND" ]; then
    RUNTIME_OUTPUT_DIRECTORY=$ROOT_DIR/tests_bin
    ADD_SUBDIRECTORY "src/tests"
fi