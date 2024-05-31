#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

set -o pipefail
set -x
source /GenAIEval/.github/workflows/scripts/change_color
git config --global --add safe.directory /GenAIEval
# get parameters
PATTERN='[-a-zA-Z0-9_]*='
PERF_STABLE_CHECK=true
for i in "$@"; do
    case $i in
        --datasets*)
            datasets=`echo $i | sed "s/${PATTERN}//"`;;
        --device=*)
            device=`echo $i | sed "s/${PATTERN}//"`;;
        --model=*)
            model=`echo $i | sed "s/${PATTERN}//"`;;
        --tasks=*)
            tasks=`echo $i | sed "s/${PATTERN}//"`;;
        *)
            echo "Parameter $i not recognized."; exit 1;;
    esac
done

working_dir=""
main() {
    case ${tasks} in
        "text-generation")
            working_dir="/GenAIEval/evals/evaluation/lm_evaluation_harness/examples";;
        "code-generation")
            working_dir="/GenAIEval/evals/evaluation/bigcode_evaluation_harness/examples";;
        *)
            echo "Not suppotted task"; exit 1;;
    esac
    if [[ ${model} == *"opt"* ]]; then
        pretrained="facebook/${model}"
    else
        pretrained="${model}"
    fi
    if [[ ${device} == "cpu" ]]; then
        model_sourze="hf"
    elif [[ ${device} == "hpu" ]]; then
        model_sourze="gaudi-hf"
    fi
    log_dir="/log/${device}/${model}"
    mkdir -p ${log_dir}
    $BOLD_YELLOW && echo "-------- evaluation start --------" && $RESET
    run_benchmark
    cp ${log_dir}/${device}-${tasks}-${model}-${datasets}.log /GenAIEval/
}

function prepare() {
    ## prepare env
    cd ${working_dir}
    echo "Working in ${working_dir}"
    echo -e "\nInstalling model requirements..."
    if [ -f "requirements.txt" ]; then
        python -m pip install -r requirements.txt
        pip list
    else
        echo "Not found requirements.txt file."
    fi
}

function run_benchmark() {
    cd ${working_dir}
    overall_log="${log_dir}/${device}-${tasks}-${model}-${datasets}.log"
    python main.py \
        --model ${model_sourze} \
        --model_args pretrained=${pretrained} \
        --tasks ${datasets} \
        --device ${device} \
        --batch_size 112  2>&1 | tee ${overall_log}

    echo "print log content:"
    cat ${overall_log}
    status=$?
    if [ ${status} != 0 ]; then
        echo "Evaluation process returned non-zero exit code."
        exit 1
    fi
}

main
