#!/bin/bash

set -e

input_vcf=$1
output_vcf=$2

bcftools sort -Oz $input_vcf -o $output_vcf
