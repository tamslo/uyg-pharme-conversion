#!/bin/bash

set -e

input_vcf="$1"
output_vcf="$2"

bcftools norm "$input_vcf" -m+ -c ws -f references/genomes/GRCh38.p13.num_id.fa -Oz -o "$output_vcf"