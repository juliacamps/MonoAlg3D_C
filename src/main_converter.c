#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#include "3dparty/sds/sds.h"
#include "3dparty/stb_ds.h"
#include "config/config_parser.h"
#include "utils/file_utils.h"
#include "vtk_utils/vtk_unstructured_grid.h"

static void convert_file(const char *input, const char *output, const char *file_name, uint32_t value_index) {

    sds full_input_path;

    static struct vtk_unstructured_grid *vtk_grid = NULL;
    sds full_output_path;

    full_input_path = sdsnew(input);

    struct path_information file_info;

    if(file_name != NULL) {
        if(!ENDS_WITH_SLASH(full_input_path)) {
            full_input_path = sdscat(full_input_path, "/");
        }

        full_input_path = sdscat(full_input_path, file_name);
    }

    get_path_information(full_input_path, &file_info);

    static int count = 0;

    if(FILE_HAS_EXTENSION(file_info.file_extension, "txt") || FILE_HAS_EXTENSION(file_info.file_extension, "alg") || FILE_HAS_EXTENSION(file_info.file_extension, "geo") || FILE_HAS_EXTENSION_PREFIX(file_info.file_extension, "Esca")) {

        if(vtk_grid == NULL) {
            vtk_grid = new_vtk_unstructured_grid_from_file(full_input_path, false, false);
            if(FILE_HAS_EXTENSION(file_info.file_extension, "geo")) {
                return;
            }
        }

        if(!vtk_grid) {
            fprintf(stderr, "%s is not a valid simulation file. Skipping!!\n", full_input_path);
        } else {

            full_output_path = sdsnew(output);

            if(!ENDS_WITH_SLASH(full_output_path)) {
                full_output_path = sdscat(full_output_path, "/");
            }


            if(FILE_HAS_EXTENSION_PREFIX(file_info.file_extension, "Esca")) {
                set_vtk_grid_values_from_ensight_file(vtk_grid, full_input_path);
            }

            if(FILE_HAS_EXTENSION_PREFIX(file_info.file_extension, "Esca")) {
                full_output_path = sdscatfmt(full_output_path, "V_it_%i.vtu", count);
                count++;
            }
            else {
                full_output_path = sdscat(full_output_path, file_info.filename_without_extension);
                full_output_path = sdscat(full_output_path, ".vtu");
            }

            printf("Converting %s to %s\n", full_input_path, full_output_path);

            save_vtk_unstructured_grid_as_vtu_compressed(vtk_grid, full_output_path, 6);

            if(FILE_HAS_EXTENSION(file_info.file_extension, "txt") || FILE_HAS_EXTENSION(file_info.file_extension, "alg")) {
                free_vtk_unstructured_grid(vtk_grid);
                vtk_grid = NULL;
            }

            sdsfree(full_output_path);

            free_path_information(&file_info);
            sdsfree(full_input_path);
        }

    } else if(FILE_HAS_EXTENSION(file_info.file_extension, "vtu")) {

        vtk_grid = new_vtk_unstructured_grid_from_file(full_input_path, false, false);

        if(!vtk_grid) {
            fprintf(stderr, "%s is not a valid simulation file. Skipping!!\n", full_input_path);
        } else {
            full_output_path = sdsnew(output);

            if(!ENDS_WITH_SLASH(full_output_path)) {
                full_output_path = sdscat(full_output_path, "/");
            }

            full_output_path = sdscat(full_output_path, file_info.filename_without_extension);
            full_output_path = sdscat(full_output_path, ".txt");

            printf("Converting %s to %s\n", full_input_path, full_output_path);

            save_vtk_unstructured_grid_as_alg_file(vtk_grid, full_output_path, false);
            free_vtk_unstructured_grid(vtk_grid);
            sdsfree(full_output_path);

            free_path_information(&file_info);
            sdsfree(full_input_path);
        }
    }
}

int main(int argc, char **argv) {

    struct conversion_options *options = new_conversion_options();

    parse_conversion_options(argc, argv, options);

    if(options->value_index < 0) {
        fprintf(stderr, "Invalid index for the value to be saved (%d)! The value parameter should be >= 0\n", options->value_index);
        return EXIT_FAILURE;
    }

    uint32_t value_index = options->value_index;

    char *input = options->input;
    char *output = options->output;

    struct path_information input_info;

    get_path_information(input, &input_info);

    if(!input_info.exists) {
        fprintf(stderr,
                "Invalid directory or file (%s)! The input parameter should be and valid simulation file, alg file or a directory containing simulations!\n",
                input);
        return EXIT_FAILURE;
    }

    if(!output) {

        output = sdsempty();

        if(input_info.is_dir) {

            if(ENDS_WITH_SLASH(input)) {
                output = sdscatfmt(output, "%sconverted_files", input);
            } else {
                output = sdscatfmt(output, "%s/converted_files", input);
            }

            create_dir(output);
            string_array geo_file = list_files_from_dir(input, NULL, "geo", NULL, true);
            string_array files_list = NULL;
            if(arrlen(geo_file) > 0) {

                convert_file(input, output, geo_file[0], value_index);
                files_list = list_files_from_dir(input, "Vm.", NULL, NULL, true);
                int num_files = arrlen(files_list);

                if(num_files == 0) {
                    fprintf(stderr, "Directory %s is empty\n", input);
                    exit(EXIT_FAILURE);
                } else {
                    for(int i = 0; i < num_files; i++) {
                        convert_file(input, output, files_list[i], value_index);
                    }
                }

            }
            else {

                files_list = list_files_from_dir(input, NULL, NULL, NULL, true);
                int num_files = arrlen(files_list);

                if(num_files == 0) {
                    fprintf(stderr, "Directory %s is empty\n", input);
                    exit(EXIT_FAILURE);
                } else {
                    for(int i = 0; i < num_files; i++) {
                        convert_file(input, output, files_list[i], value_index);
                    }
                }
            }
        } else {
            if(ENDS_WITH_SLASH(input_info.dir_name)) {
                output = sdscatfmt(output, "%sconverted_files", input_info.dir_name);
            } else {
                output = sdscatfmt(output, "%s/converted_files", input_info.dir_name);
            }

            create_dir(output);
            convert_file(input, output, NULL, value_index);

        }
    }

    return EXIT_SUCCESS;
}
