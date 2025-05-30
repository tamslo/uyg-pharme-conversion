#!/bin/python

import os
import pandas as pd
import sys

VCF_COMMENT = '#'
VCF_SEPARATOR = '\t'

print(f'Starting genotype update... 🏃', flush=True)

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
                clean_header_line = line.removeprefix(VCF_COMMENT).strip().lower()
                vcf_header = clean_header_line.split(VCF_SEPARATOR)
                break
        vcf_data = pd.read_csv(
            vcf_file,
            sep=VCF_SEPARATOR,
            comment=VCF_COMMENT,
            names=vcf_header,
            # index_col='id',
            dtype={ 'chrom': 'str' }
        )
        vcf_data = vcf_data.set_index('id', drop=False)
    return vcf_data

hg19_lookup_data = read_vcf(hg19_vcf_file_name)
hg38_lookup_data = read_vcf(hg38_vcf_file_name)

def is_allele_present(allele):
    return not pd.isnull(allele) and allele != '.'

def is_variant_inversion(hg19, hg38):
    inversion_map = {
        'A': 'T',
        'C': 'G',
        'G': 'C',
        'T': 'A',
        'N': 'N',
    }
    for key in ['ref', 'alt']:
        if hg19[key] != inversion_map[hg38[key]]:
            return False
    return True

for id, hg38_data in hg38_lookup_data.iterrows():
    try:
        hg19_data = hg19_lookup_data.loc[id]
    except IndexError:
        print(f'❌ Error: no lookup in data for {id}. Filtering out.', flush=True)
        continue

    ref_changed = hg19_data['ref'] != hg38_data['ref']
    # If ALT and REF present, check that they did not change
    if is_allele_present(hg38_data['alt']):
        alt_changed = hg19_data['alt'] != hg38_data['alt']
        if is_variant_inversion(hg19_data, hg38_data):
            continue
        if ref_changed or alt_changed:
            print(f'❌ Changed nucleotides for {id}. Filtering out for now.', flush=True)
            continue
    else:
        if not ref_changed:
            continue
        alt_is_now_ref = hg19_data['alt'] == hg38_data['ref']
        if '0' in hg38_data['sample'] and not alt_is_now_ref:
            print(f'❌ Changed reference for {id}. Filtering out for now.', flush=True)
            continue
        # print(hg38_data['alt'])
        # break
        # if alt_changed:
        #     print(f'❌ Need to adapt alternative genotype for {id}. Filtering out for now.', flush=True)
        #     continue
    # # TODO: make work
    # # Positions switched
    # if pd.isnull(hg38_data['alt']) and '1' in hg38_data['sample']:
    #     if not hg19_data['alt'] == hg38_data['ref']:
    #         print(f'❌ Unexpected case for {id}. Filtering out.', flush=True)
    #         continue
    #     if not '0' in hg38_data['sample']:
    #         hg38_data['sample'] = hg38_data['sample'].replace('1', '0')
    #         continue
    #     hg38_data['alt'] = hg19_data['ref']
    #     if hg38_data['sample'].startswith('0'):
    #         hg38_data['sample'] = '1/0'
    #         continue
    #     hg38_data['sample'] = '0/1'
    # if '1' in hg38_data['sample'] and not hg19_data['ref'] == hg38_data['ref']:
    #     print(f'❌ Unexpected case for {id}. Filtering out.', flush=True)
    #     continue
    # TODO: other cases?

# with open(output_file_name, 'w') as output_file, open(hg38_vcf_file_name) as input_file:
#     for line in input_file:
#         if line.startswith(VCF_COMMENT):
#             output_file.write(line)
#         else:
#             break

# hg38_lookup_data.to_csv(
#     output_file_name,
#     mode='a',
#     index=False,
#     header=False,
#     sep=VCF_SEPARATOR,
#     chunksize=200000,
#     encoding='utf-8',
# )

print(f'🏁 Script finished!', flush=True)