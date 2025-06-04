#!/bin/bash

set -e

input_vcf=$1
output_vcf=$2

decompressed_input=${input_vcf//'.gz'/}
decompressed_output=${output_vcf//'.gz'/}
bgzip -d $input_vcf -o $decompressed_input

perl -pe '/^((?!^chr).)*$/ && s/^([^#])/chr$1/gsi' \
    "$decompressed_input" > "$decompressed_output"

rm $decompressed_input
bgzip $decompressed_output