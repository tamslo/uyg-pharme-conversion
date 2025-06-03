#!/bin/python

import sys

from vcf_utils import test_input_file, read_vcf, write_vcf, VCF_MISSING_VALUE, \
    VCF_MISSING_GENOTYPE

input_file_name = sys.argv[1]
output_file_name = sys.argv[2]

test_input_file(input_file_name)

input_data = read_vcf(input_file_name)

previous={}
for row_index, current in input_data.iterrows():
    if 'idx' in previous:
        if current['pos'] == previous['pos']:
            missing_genotypes = \
                current['sample'].startswith(VCF_MISSING_GENOTYPE) and \
                previous['sample'].startswith(VCF_MISSING_GENOTYPE)
            if missing_genotypes:
                input_data.loc[previous['idx'], 'info'] = VCF_MISSING_VALUE
                input_data.loc[previous['idx'], 'format'] = VCF_MISSING_VALUE
    previous['idx'] = row_index
    previous['pos'] = current['pos']
    previous['sample'] = current['sample']

write_vcf(input_file_name, output_file_name, input_data)
