#!/bin/bash

# Run in Docker container with
# `docker run --rm -v ./data:/data -w /data uyg-to-pharme bash download_reference_data.sh`

PRELOADED_DATA_DIRECTORY=/data/references
mkdir -p $PRELOADED_DATA_DIRECTORY
cd $PRELOADED_DATA_DIRECTORY

prefix_chromosome_id() {
    local reference_file=$1
    local output_postfix=$2
    local prefix=$3
    sed -E \
        "s/>(NC_[0-9]+\.[0-9]+) Homo sapiens chromosome ([0-9XY]+)([a-zA-Z ]*), ${reference_file} ([a-zA-Z ]*)/>$prefix\2 \1 Homo sapiens chromosome \2\3, ${reference_file} \4/" \
        genomes/${reference_file}.fa > \
        genomes/${reference_file}.$output_postfix.fa
    if [ ! -f "genomes/${reference_file}.$output_postfix.fa.fai" ]; then
        echo "Indexing reference genome..."
        samtools faidx genomes/${reference_file}.$output_postfix.fa
    fi
}

get_reference_genome() {
    local reference_file=$1
    local reference_gcf=$2
    mkdir -p genomes
    if [ ! -f "genomes/${reference_file}.fa" ]; then
        echo "Getting ${reference_file} reference genome..."
        wget -q https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/405/GCF_000001405.${reference_gcf}_${reference_file}/GCF_000001405.${reference_gcf}_${reference_file}_genomic.fna.gz
        gunzip GCF_000001405.${reference_gcf}_${reference_file}_genomic.fna.gz
        mv GCF_000001405.${reference_gcf}_${reference_file}_genomic.fna \
            genomes/${reference_file}.fa
    fi
    if [ ! -f "genomes/${reference_file}.num_id.fa" ]; then
        echo "Adding numeric chromosome IDs..."
        prefix_chromosome_id $reference_file num_id
    fi
}

get_chain_file() {
    if [ ! -f "hg19ToHg38.over.chain.gz" ]; then
        echo 'Getting chain file for liftover...'
        wget -q https://hgdownload.soe.ucsc.edu/goldenPath/hg19/liftOver/hg19ToHg38.over.chain.gz
    fi
}

# Download reference panel and genetic maps for imputation

get_imputation_data() {
    mkdir -p imputation
    if [ ! -d "imputation/maps" ]; then
        echo 'Getting imputation maps...'
        wget -q https://bochet.gcc.biostat.washington.edu/beagle/genetic_maps/plink.GRCh37.map.zip
        unzip plink.GRCh37.map.zip -d imputation/maps
        rm plink.GRCh37.map.zip
    fi
    if [ ! -d "imputation/reference" ]; then
        mkdir "imputation/reference"
        echo 'Getting imputation reference panel...'
        wget -q -r -np -R index.html* https://bochet.gcc.biostat.washington.edu/beagle/1000_Genomes_phase3_v5a/b37.bref3/
        mv \
            bochet.gcc.biostat.washington.edu/beagle/1000_Genomes_phase3_v5a/b37.bref3/* \
            imputation/reference
        rm -r bochet.gcc.biostat.washington.edu
    fi
}

# Get reference genome for 23andMe to VCF conversion
get_reference_genome 'GRCh37' '13'
# Get reference genome also used by PharmCAT for preprocessing
get_reference_genome 'GRCh38.p13' '39'
# Get chain file for liftover (part of preprocessing, also uses reference
# genomes)
get_chain_file
# Get reference data for imputation
get_imputation_data
