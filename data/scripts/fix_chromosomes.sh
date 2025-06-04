#!/bin/bash

set -e

input_vcf=$1
output_vcf=$2

decompressed_input=$input_vcf
decompressed_output=$output_vcf

if [[ $input_vcf == *.gz ]]; then
    decompressed_input=${input_vcf//'.gz'/}
    bgzip -d $input_vcf -o $decompressed_input
fi
if [[ $output_vcf == *.gz ]]; then
    decompressed_output=${output_vcf//'.gz'/}
fi

perl -pe '/^((?!^chr).)*$/ && s/^([^#])/chr$1/gsi' \
    "$decompressed_input" > "$decompressed_output"

if [[ $input_vcf == *.gz ]]; then
    rm $decompressed_input
fi
if [[ $output_vcf == *.gz ]]; then
    bgzip $decompressed_output
fi