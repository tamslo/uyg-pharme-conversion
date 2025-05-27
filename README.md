# UYG to PharMe Data Conversion

🚧 Work in progress, still figuring this out!

Dockerfile and instructions to convert (my) genetic data from the (2020) UYG
course :bulb: to a format that can be used by PharMe. :dna::pill:

## Prerequisites

* Your genetic data in 23andMe format or in PLINK format
* Docker installed
* If your data is in 23andMe format, download the regarding reference file for
  VCF conversion (see the [Reference Genome Notes](#reference-genome-notes)
  section)
* Potentially rename your data to match commands:
  * Genetic data in `data/data.txt` (23andMe format) or in
    `data/data.bim`, `data/data.bed`, `data/data.fam` (PLINK format)
  * Reference file (if needed) in `references/GRCh37.23andMe.fa`

## How to use

1. Build Docker container `docker build -t uyg-to-pharme .`
2. Convert your data to VCF
   * If your data is in 23andMe format, use

     ```bash
     docker run --rm -v ./data:/data -w /data uyg-to-pharme \
       bcftools convert  -c ID,CHROM,POS,AA --tsv2vcf data.txt \
         -f references/GRCh37.23andMe.fa -s Sample -Oz -o data.vcf
     ```

     (for more information refer to this
     [BCFtools tutorial](https://samtools.github.io/bcftools/howtos/convert.html))
   * If your data is in PLINK format, use

     ```bash
     docker run --rm -v ./data:/data -w /data uyg-to-pharme \
       plink --bed data.bed --bim data.bim --fam data.fam \
         --recode vcf --out data
     ```

3. Call star alleles with PharmCAT (you can also use another tool for star
   allele calling, but this example uses PharmCAT):
   * Preprocess VCF file ([Docs](https://pharmcat.org/using/VCF-Preprocessor/)):

     ```bash
     docker run --rm -v ./data:/data -w /data pgkb/pharmcat \
       pharmcat_vcf_preprocessor -v -vcf data.vcf
     ```

   * If you run into any problems, such as a lot of missing variants, please
     refer to the [Manual Preprocessing](#manual-preprocessing) section
   * Run PharmCAT

     ```bash
     docker run --rm -v ./data:/data -w /data pgkb/pharmcat \
       pharmcat_pipeline data.preprocessed.vcf

     ```

## Reference Genome Notes

📝 _Note: Most tools require the uncompressed files, so you might need to_
_decompress them._

* The Ensembl hg19 reference genome:
  [Ensembl GRCh37](https://ftp.ensembl.org/pub/grch37/current/fasta/homo_sapiens/dna/Homo_sapiens.GRCh37.dna.primary_assembly.fa.gz)
* The NCBI hg19 reference genome:
  [NCBI GRCh37](https://www.ncbi.nlm.nih.gov/datasets/genome/GCF_000001405.13/)
* The NCBI hg38 reference genome (what PharMe works with):
  [GRCh38.p13](https://www.ncbi.nlm.nih.gov/datasets/genome/GCF_000001405.39/)

When using the NCBI reference genome with your 23andMe data, add the chromosome
number to the beginning of each header with the following command:

`sed -E 's/>(NC_[0-9]+\.[0-9]+) Homo sapiens chromosome ([0-9XY]+)([a-zA-Z ]*), GRCh37 ([a-zA-Z ]*)/>\2 \1 Homo sapiens chromosome \2\3, GRCh37 \4/' data/references/GRCh37.fa > data/references/GRCh37.23andMe.fa`

Test that chromosomes were adapted with
`grep -E '^>[0-9XY]+ N' data/references/GRCh37.23andMe.fa`.

## Manual Preprocessing

Manual preprocessing steps to fix and/or clarify problems.

### Liftover

Manual liftover to GRCh38.p13 (the reference genome used by PharmCAT) using
CrossMap (assumes `GRCh38.p13.fa` and the `hg19ToHg38.over.chain.gz` file
[from UCSC](https://hgdownload.soe.ucsc.edu/goldenPath/hg19/liftOver/)
to be present):
  
```bash
sed -E 's/>(NC_[0-9]+\.[0-9]+) Homo sapiens chromosome ([0-9XY]+)([a-zA-Z ]*), GRCh38.p13 ([a-zA-Z ]*)/>\2 \1 Homo sapiens chromosome \2\3, GRCh38.p13 \4/' data/references/GRCh38.p13.fa > data/references/GRCh38.23andMe.fa
docker run --rm -v ./data:/data -w /data uyg-to-pharme \
  samtools faidx references/GRCh38.23andMe.fa
docker run --rm -v ./data:/data -w /data uyg-to-pharme \
  CrossMap vcf --no-comp-alleles references/hg19ToHg38.over.chain.gz data.vcf \
  references/GRCh38.23andMe.fa data.hg38.vcf
```

### Normalization

To normalize the VCF file, run

```bash
docker run --rm -v ./data:/data -w /data uyg-to-pharme \
  bcftools norm -m+ -c ws -Oz -o data.normalized.vcf \
  -f references/GRCh38.23andMe.fa data.hg38.vcf
```

(also see
[PharmCAT Docs](https://pharmcat.org/using/VCF-Requirements/#requirement-3---use-parsimonious-left-aligned-variant-representation)).

### Sort by Position

```bash
docker run --rm -v ./data:/data -w /data uyg-to-pharme \
  bcftools sort -Oz data.normalized.vcf -o data.sorted.vcf
```

### Chromosome Fix

To prefix the chromosome with `chr`, use

```bash
docker run --rm -v ./data:/data -w /data uyg-to-pharme \
  perl -pe '/^((?!^chr).)*$/ && s/^([^#])/chr$1/gsi' data.sorted.vcf \
  > data/data.preprocessed.vcf
```

(also see
[PharmCAT Docs](https://pharmcat.org/using/VCF-Requirements/#requirement-5---the-chrom-field-must-be-in-the-format-chr)).

### Inspecting PharmCAT Created Files

You can check the content of (intermediate) compressed processed VCFs (when
running the preprocessing command with the `-k` option) with:
`docker run --rm -v ./data:/data -w /data uyg-to-pharme bgzip -k -d data.vcf.bgz`

## TODOs

* Describe how to load into PharMe
* Imputation
