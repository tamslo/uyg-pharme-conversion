#!/bin/bash

set -e

input_vcf="$1"
output_vcf="$2"

bcftools +liftover -Oz "$input_vcf" -- \
    -s references/genomes/GRCh37.num_id.fa \
    -f references/genomes/GRCh38.p13.num_id.fa \
    -c references/hg19ToHg38.over.chain.gz \
    --reject liftover_rejected_variants.bcf \
    | bcftools sort -Ob -o "$output_vcf"