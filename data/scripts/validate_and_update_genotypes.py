#!/bin/python

import os
import pandas as pd
import sys
from datetime import datetime

print(f'Starting genotype update script at {datetime.now()}. 🏃 This will take a while ⏳🫠', flush=True)

hg38_vcf_file_name = sys.argv[1]
hg19_vcf_file_name = sys.argv[2]
output_file_name = sys.argv[3]

for input_file_name in [ hg38_vcf_file_name, hg19_vcf_file_name ]:
    if not os.path.exists(input_file_name):
        print(f'❌ Error: file {input_file_name} is not present. Aborting.')
        exit(1)

if os.path.exists(output_file_name):
    print(f'❌ Error: output file {output_file_name} exists. Please delete before running this script.')
    exit(1)

def read_vcf(file_name):
    with open(file_name, 'r') as vcf_file:
        vcf_header = None
        for line in vcf_file:
            if line.startswith('#CHROM'):
                clean_header_line = line.removeprefix('#').strip().lower()
                vcf_header = clean_header_line.split('\t')
                break
        vcf_data = pd.read_csv(
            vcf_file,
            sep='\t',
            comment='#',
            header=0,
            names=vcf_header,
            dtype={ 'chrom': 'str' }
        )
    return vcf_data

hg19_lookup_data = read_vcf(hg19_vcf_file_name)

def read_vcf_line(line):
    if line.startswith('#'): return None, None, None, None
    fields = line.strip().split('\t')
    id=fields[2]
    ref=fields[3]
    alt=fields[4]
    genotype=fields[9]
    return id, ref, alt, genotype

def lookup_id(lookup_data, id):
    lookup = lookup_data[lookup_data['id'] == id]
    if len(lookup) > 1:
        print(f'⚠️  Warning: multiple lookups in data for {id}. Ignoring all but first.', flush=True)
    return lookup.head(1)

# We could just iterate the pandas dataframe but it will be easier to just use
# the line as it is in the file for now to avoid messing up the formatting

with open(output_file_name, 'w') as output_file:
    with open(hg38_vcf_file_name, 'r') as hg38_vcf_file:
        for line in hg38_vcf_file:
            id, ref, alt, genotype = read_vcf_line(line)
            if id == None:
                output_file.write(line)
                continue
            hg19_data = lookup_id(hg19_lookup_data, id)
            if hg19_data.empty:
                print(f'❌ Error: no lookup in data for {id}. Filtering out.', flush=True)
                continue
            # TODO: do checks that nucleotides are as expected and potentially
            # update genotypes or add alt in line
            output_file.write(line)

print(f'🏁 Script finished at {datetime.now()}!', flush=True)