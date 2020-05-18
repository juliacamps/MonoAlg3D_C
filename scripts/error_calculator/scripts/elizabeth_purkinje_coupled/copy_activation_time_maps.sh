#!/bin/bash

RESULTS_FOLDER="/home/berg/Github/MonoAlg3D_C/outputs"
OUTPUT_FOLDER="/home/berg/Github/MonoAlg3D_C/scripts/error_calculator/inputs/elizabeth_purkinje_coupled"
#SEEDS=( 1562046115 1562013988 1562042299 1562005513 1562009134 1562009769 1562044567 1562008424 1562036996 1562020974 )
#SEEDS=( 1562046115 1562013988 1562042299 1562005513 1562009134 1562009769 1562044567 1562008424 1562036996 1562020974 1562049673 1562023024 1562025823 1562007596 1562028813 1562005553 1562017900 1562034865 1562047507 1562011558 )
SEEDS=( 1562046115 1562013988 1562042299 1562005513 1562009134 1562009769 1562044567 1562008424 1562036996 1562020974 1562049673 1562023024 1562025823 1562007596 1562028813 1562005553 1562017900 1562034865 1562047507 1562011558 1562051289 1562006177 1562002894 1562002891 1562018879 1562021648 1562035947 1562008172 1562043344 1562021993 )

cp ${RESULTS_FOLDER}/elizabeth_coupled_arpf_gold_LV/activation-map.vtu ${OUTPUT_FOLDER}/gold_standart/activation-map_gold.vtu

for SEED in "${SEEDS[@]}"; do
    cp ${RESULTS_FOLDER}/elizabeth_coupled_arpf_cco_seed-${SEED}_offset-9_LV/activation-map.vtu ${OUTPUT_FOLDER}/cco_classic/activation-map_seed-${SEED}.vtu
    #cp ${RESULTS_FOLDER}/elizabeth_coupled_arpf_co_seed-${SEED}_offset-9_LV/activation-map.vtu ${OUTPUT_FOLDER}/co_fractal_classic/activation-map_seed-${SEED}.vtu
    #echo ${SEED}
    #cat ${RESULTS_FOLDER}/elizabeth_coupled_arpf_cco_seed-${SEED}_offset-9_LV/outputlog.txt | grep nan
done
