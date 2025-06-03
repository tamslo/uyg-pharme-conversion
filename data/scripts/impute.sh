#!/bin/bash

set -e

input_vcf=$1
output_vcf=$2

imputation_temp_dir=imputation-temp
mkdir -p $imputation_temp_dir

chromosomes="1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 X"

imputation_input_vcf=$imputation_temp_dir/data.diploid.y.vcf

if [ ! -f "$imputation_input_vcf" ]
then
  echo -e "📦 Installing Python packages..."
  pip3 install -q -r scripts/requirements.txt \
    --break-system-packages --root-user-action=ignore
  echo -e "👯 Adapting Y ploidy..."
  python3 scripts/adapt_y_ploidy.py $input_vcf $imputation_input_vcf
fi

general_output_prefix=$imputation_temp_dir/imputed.chr
for chromosome in $chromosomes
do
  output_prefix=$general_output_prefix$chromosome
  output_file=$output_prefix.vcf.gz
  if [ ! -f "$output_file" ]
  then
    echo -e "\n⚙️ Processing chromosome $chromosome...\n\n"
    java -Xmx12G -jar /opt/beagle.jar gt=$imputation_input_vcf \
      chrom=$chromosome \
      out=$output_prefix \
      impute=true \
      gp=true \
      window=300 \
      map=references/imputation/maps/plink.chr$chromosome.GRCh38.map \
      ref=references/imputation/reference/chr$chromosome.1kg.phase3.v5a.b37.bref3
  fi
  if [ ! -f "$output_file.tbi" ]
  then
    bcftools index -t $output_file
  fi
done

merged_vcf=$imputation_temp_dir/imputed.merged.vcf
if [ ! -f "$merged_vcf" ]
then
  bcftools concat $general_output_prefix*.vcf.gz -Oz -o $merged_vcf
fi

gp_threshold=0.75
if [ ! -f "$output_vcf" ]
then
  echo -e "\n🔎 Filtering out imputed values with PG < $gp_threshold...\n\n"
  bcftools +setGT $merged_vcf -- -t q -n . -i"FORMAT/GP>=$gp_threshold" > $output_vcf
fi
