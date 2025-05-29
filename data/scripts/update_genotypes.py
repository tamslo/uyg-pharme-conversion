#!/bin/python

import os
import sys

# TODO: Traverse new VCF
# TODO: If ALT is . ...
# TODO: ... and genotype is '1/1' change to '0/0'
# TODO: ... and genotype is '0/1' or '1/0' switch and get ALT (former REF)
# from old VCF file

hg38_vcf_file_name = sys.argv[1]
hg19_vcf_file_name = sys.argv[2]

for input_file in [ hg38_vcf_file_name, hg19_vcf_file_name ]:
    if not os.path.exists(input_file):
        print(f'Error: file {input_file} is not present. Aborting.')
        exit(1)

with open(hg38_vcf_file_name, 'w') as hg38_vcf_file:
    print(hg38_vcf_file)