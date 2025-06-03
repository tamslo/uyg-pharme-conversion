import os
import pandas as pd

VCF_COMMENT = '#'
VCF_SEPARATOR = '\t'
VCF_MISSING_VALUE = '.'
VCF_MISSING_VALUES = [ None, '', VCF_MISSING_VALUE ]

def test_input_file(file_name):
    if not os.path.exists(file_name):
        print(f'❌ Error: file {file_name} is not present. Aborting.')
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

def write_vcf(input_file_name, output_file_name, output_data):
    with open(output_file_name, 'w') as output_file, open(input_file_name) as input_file:
        for line in input_file:
            if line.startswith(VCF_COMMENT):
                output_file.write(line)
            else:
                break
    output_data.to_csv(
        output_file_name,
        mode='a',
        index=False,
        header=False,
        sep=VCF_SEPARATOR,
        encoding='utf-8',
    )