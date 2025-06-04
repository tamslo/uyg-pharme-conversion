#!/bin/bash

set -e

input_vcf=$1
output_vcf=$2

bcftools sort "$input_vcf" -Oz -o "$output_vcf"
