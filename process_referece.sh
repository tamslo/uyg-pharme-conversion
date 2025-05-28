#!/bin/bash

# Run in Docker container

reference_directory=$1
reference_file=$2
reference_gcf=$3

wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/405/GCF_000001405.${reference_gcf}_${reference_file}/GCF_000001405.${reference_gcf}_${reference_file}_genomic.fna.gz
gunzip GCF_000001405.${reference_gcf}_${reference_file}_genomic.fna.gz
mv GCF_000001405.${reference_gcf}_${reference_file}_genomic.fna ${reference_file}.fa
rm GCF_000001405.${reference_gcf}_${reference_file}_genomic.fna.gz

sed -E "s/>(NC_[0-9]+\.[0-9]+) Homo sapiens chromosome ([0-9XY]+)([a-zA-Z ]*), ${reference_file} ([a-zA-Z ]*)/>\2 \1 Homo sapiens chromosome \2\3, ${reference_file} \4/" ${reference_directory}/${reference_file}.fa > ${reference_directory}/${reference_file}.23andMe.fa

samtools faidx {reference_directory}/${reference_file}.23andMe.fa