#!/bin/python

import sys

from vcf_utils import test_input_file, read_vcf, write_vcf, VCF_MISSING_VALUES

input_file_name = sys.argv[1]
output_file_name = sys.argv[2]

test_input_file(input_file_name)

input_data = read_vcf(input_file_name)
y_input_data = input_data[input_data['chrom'] == 'Y']

for id, current in y_input_data.iterrows():
    current_genotype = current['sample']
    if not '/' in current_genotype:
        current_info = current['info']
        adapted_info = 'originally_haploid'
        if not current_info in VCF_MISSING_VALUES:
            adapted_info = f'{current_info};{adapted_info}'
        input_data.loc[id, 'info'] = adapted_info
        input_data.loc[id, 'sample'] = f'{current_genotype}/{current_genotype}'
write_vcf(input_file_name, output_file_name, input_data)
