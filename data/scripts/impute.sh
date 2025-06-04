#!/bin/bash

set -e

input_vcf=$1
output_vcf=$2

imputation_temp_dir=imputation-temp
mkdir -p $imputation_temp_dir

chromosomes="1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 X"

imputation_input_vcf=$imputation_temp_dir/data.diploid.y.vcf

final_postfix="preprocessed"

maybe_install_python_packages() {
  requirements_file=scripts/requirements.txt
  all_python_packages_installed=1
  installed_packages=$(pip freeze)
  while IFS= read -r requirement; do
    requirement=$(echo "$requirement" | xargs)
    if [[ -z "$requirement" || "$requirement" == \#* ]]; then
        continue
    fi
    if [[ ! $installed_packages == *"$requirement"* ]]; then
        all_python_packages_installed=0
        break
    fi
  done < "$requirements_file"
  if [ "$all_python_packages_installed" -eq "0" ]; then
    echo -e "\n📦 Installing Python packages for next steps..."
    pip3 install -q -r $requirements_file \
      --break-system-packages --root-user-action=ignore
  fi

}

if [ ! -f "$imputation_input_vcf" ]
then
  maybe_install_python_packages
  echo -e "👯 Adapting Y ploidy..."
  python3 scripts/adapt_y_ploidy.py $input_vcf $imputation_input_vcf
fi

temp_output_prefix=$imputation_temp_dir/imputed.chr
for chromosome in $chromosomes
do
  chromosome_output_prefix=$temp_output_prefix$chromosome
  imputed_prefix=$chromosome_output_prefix
  imputed_file=$imputed_prefix.vcf.gz
  if [ ! -f "$imputed_file" ]
  then
    echo -e "\n📈 Imputing chromosome $chromosome...\n"
    java -Xmx12G -jar /opt/beagle.jar gt=$imputation_input_vcf \
      chrom=$chromosome \
      out=$imputed_prefix \
      impute=true \
      gp=true \
      window=300 \
      map=references/imputation/maps/plink.chr$chromosome.GRCh38.map \
      ref=references/imputation/reference/chr$chromosome.1kg.phase3.v5a.b37.bref3
  fi
  indexed_imputed_file=$imputed_file.tbi
  if [ ! -f "$indexed_imputed_file" ]
  then
    tabix -p vcf $imputed_file
  fi
  filtered_prefix=$chromosome_output_prefix.filtered
  filtered_file=$filtered_prefix.vcf.gz
  gp_threshold=0.75
  if [ ! -f "$filtered_file" ]
  then
    echo -e "\n📉 Filtering out GP < $gp_threshold for chromosome $chromosome...\n"
    bcftools plugin setGT $imputed_file -Oz -o $filtered_file -- -t q -n . -i"FORMAT/GP>=$gp_threshold"
  fi
  descriptions_removed_file=$chromosome_output_prefix.clean.vcf.gz
  if [ ! -f "$descriptions_removed_file" ]
  then
    echo -e "\n⛑️  Removing description fields for normalization for chromosome $chromosome..."
    bcftools annotate "$filtered_file" -x INFO/DR2,INFO/AF,INFO/IMP,FORMAT/DS,FORMAT/GP -Oz -o "$descriptions_removed_file"
  fi
  normalized_file=$chromosome_output_prefix.normalized.vcf.gz
  if [ ! -f "$normalized_file" ]
  then
    echo -e "\n🔁  Normalizing chromosome $chromosome...\n"
    bash scripts/normalize.sh "$descriptions_removed_file" "$normalized_file"
  fi
  final_file=$chromosome_output_prefix.$final_postfix.vcf.gz
  if [ ! -f "$final_file" ]
  then
    echo -e "\n🛠️  Prefixing chromosome $chromosome..."
    bash scripts/fix_chromosomes.sh "$normalized_file" "$final_file"
  fi
  indexed_final_file=$final_file.tbi
  if [ ! -f "$indexed_final_file" ]
  then
    tabix -p vcf $final_file
  fi
done

merged_file=$imputation_temp_dir/merged.imputed.vcf.gz
if [ ! -f "$merged_file" ]
then
  echo -e "\n👉👈  Merging chromosomes...\n"
  bcftools concat $temp_output_prefix*$final_postfix.vcf.gz -Oz -o $merged_file
fi

rm $temp_output_prefix*.tbi

if [ ! -f "$output_vcf" ]
then
  echo -e "\n↗️  Sorting output...\n"
  bash scripts/sort.sh "$normalized_file" "$output_vcf"
fi

echo -e "\n🏁 Imputation done\n"
