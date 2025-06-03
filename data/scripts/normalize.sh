#!/bin/bash

set -e

input_vcf=$1
output_vcf=$2

bcftools norm -m+ -c ws -Oz -o $output_vcf \
  -f references/genomes/GRCh38.p13.23andMe.fa $input_vcf
