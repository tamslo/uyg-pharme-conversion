#!/bin/bash

set -e

input_vcf=$1
output_vcf=$2

perl -pe '/^((?!^chr).)*$/ && s/^([^#])/chr$1/gsi' \
    $input_vcf $output_vcf
