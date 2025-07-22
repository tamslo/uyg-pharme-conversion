#!/bin/python

import sys

from vcf_utils import test_input_file, read_vcf, write_vcf

input_file_name = sys.argv[1]
output_file_name = sys.argv[2]

test_input_file(input_file_name)

input_data = read_vcf(input_file_name)

for row_index, current in input_data.iterrows():
    if current["chrom"] != "Y":
        continue
    current_genotype = current["sample"]
    if "/" not in current_genotype:
        input_data.loc[row_index, "sample"] = f"{current_genotype}/{current_genotype}"
write_vcf(input_file_name, output_file_name, input_data)
