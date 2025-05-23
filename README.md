# UYG to PharMe Data Conversion

🚧 Work in progress, still figuring this out!

Dockerfile and instructions to convert (my) genetic data from the (2020) UYG
course :bulb: to a format that can be used by PharMe. :dna::pill:

## Prerequisites

* Your genetic data in 23andMe format or in PLINK format
* Docker installed
* If your data is in 23andMe format, download the regarding reference file for
  VCF conversion (probably hg19/GRCh37), e.g., from
  [Ensembl](https://ftp.ensembl.org/pub/grch37/current/fasta/homo_sapiens/dna/Homo_sapiens.GRCh37.dna.primary_assembly.fa.gz)
  and potentially decompress
* Potentially rename your data to match commands:
  * Genetic data in `data/data.txt` (23andMe format) or in
    `data/data.bim`, `data/data.bed`, `data/data.fam` (PLINK format)
  * Reference file (if needed) in `ref.fa`

## How to use

1. Build Docker container `docker build -t uyg-to-pharme .`
2. Convert your data to VCF
   * If your data is in 23andMe format, use

     ```bash
     docker run --rm -v ./data:/data -w /data uyg-to-pharme \
       bcftools convert --tsv2vcf data.txt \
       -f Homo_sapiens.GRCh37.dna.primary_assembly.fa -s Sample -Oz -o data.vcf
     ```

     (for more information refer to this
     [BCFtools tutorial](https://samtools.github.io/bcftools/howtos/convert.html))
   * If your data is in PLINK format, use
     `docker run --rm -v ./data:/data -w /data uyg-to-pharme plink --bed data.bed --bim data.bim --fam data.fam --recode vcf --out data`
3. Call star alleles with PharmCAT (or another tool for star allele calling):
   * Preprocess VCF file ([Docs](https://pharmcat.org/using/VCF-Preprocessor/)):
     `docker run --rm -v ./data:/data -w /data pgkb/pharmcat pharmcat_vcf_preprocessor -v -vcf data.vcf`
   * Run PharmCAT
     `docker run --rm -v ./data:/data -w /data pgkb/pharmcat pharmcat_vcf_preprocessor -v -vcf data.preprocessed.vcf`

**:warning: did not manage to create a working version yet, as the liftover**
**as part of the preprocessing does not seem to work**

## Troubleshooting

* If the VCF conversion does not work (all rows are skipped), try a different
  reference genome
* If the preprocessing detects a lot of missing variants, try to liftover to
  GRCh38.p13 (the reference genome used by PharmCAT) using CrossMap:
  
  ```bash
  docker run --rm -v ./data:/data -w /data uyg-to-pharme \
    CrossMap vcf --no-comp-alleles hg19ToHg38.over.chain.gz data.vcf \
    GCA_000001405.28_GRCh38.p13_genomic.fna data.hg38.vcf
  ```

* You can check the content of compressed processed VCFs with:
  `docker run --rm -v ./data:/data -w /data uyg-to-pharme bgzip -k -d data.vcf.bgz`

## TODOs

* Fix preprocessing & normalization
* Call star alleles with PharmCAT
* Describe how to load into PharMe

Potential future steps: filter the VCF (QC)
