# UYG to PharMe Data Conversion

Dockerfile and instructions to convert (my) genetic data from the (2020) UYG
course :bulb: to a format that can be used by PharMe. :dna::pill:

## Prerequisites

* Your genetic data in 23andMe format or in PLINK format
* Docker installed
* Potentially rename your data to match commands (or rename the paths in the
  commands below): `data/data.txt` (23andMe format) or in
    `data/data.bim`, `data/data.bed`, `data/data.fam` (PLINK format)

## How to use

1. Build Docker container `docker build -t uyg-to-pharme .`
2. Download reference files as needed, using
   `docker run --rm -v ./data:/data -w /data uyg-to-pharme bash scripts/download_reference_data.sh`
   (you may not need all data, you can comment out what you will not need)
3. Convert your data to VCF
   * If your data is in 23andMe format, use

     ```bash
     docker run --rm -v ./data:/data -w /data uyg-to-pharme \
       bcftools convert  -c ID,CHROM,POS,AA --tsv2vcf data.txt \
         -f /data/references/genomes/GRCh37.23andMe.fa -s Sample -Oz -o data.vcf
     ```

     (for more information refer to this
     [BCFtools tutorial](https://samtools.github.io/bcftools/howtos/convert.html))
   * If your data is in PLINK format, use

     ```bash
     docker run --rm -v ./data:/data -w /data uyg-to-pharme \
       plink --bed data.bed --bim data.bim --fam data.fam \
         --recode vcf --out data
     ```

4. Preprocess VCF file ([Docs](https://pharmcat.org/using/VCF-Preprocessor/));
   if you run into any problems, such as a lot of missing variants, please
   refer to the [Manual Preprocessing](#manual-preprocessing) section

     ```bash
     docker run --rm -v ./data:/data -w /data pgkb/pharmcat \
       pharmcat_vcf_preprocessor -v -vcf data.vcf
     ```

5. Optionally, impute your data; if you are not imputing, PharmCAT will have
   quite some missing variants (see [Imputation](#imputation))
6. Run PharmCAT

     ```bash
     docker run --rm -v ./data:/data -w /data pgkb/pharmcat \
       pharmcat_pipeline data.imputed.vcf

     ```

## Reference Genome Notes

Different reference genomes are available from different sources, that may
differ in their notations, e.g.:

* The Ensembl hg19 reference genome:
  [Ensembl GRCh37](https://ftp.ensembl.org/pub/grch37/current/fasta/homo_sapiens/dna/Homo_sapiens.GRCh37.dna.primary_assembly.fa.gz)
* The NCBI hg19 reference genome:
  [NCBI GRCh37](https://www.ncbi.nlm.nih.gov/datasets/genome/GCF_000001405.13/)
* The NCBI hg38 reference genome (what PharMe works with):
  [GRCh38.p13](https://www.ncbi.nlm.nih.gov/datasets/genome/GCF_000001405.39/)

The NCBI reference genomes are loaded and preprocessed in the
`download_reference_data.sh` script.

## Manual Preprocessing

Manual preprocessing steps to fix and/or clarify problems. Also see
[PharmCAT Docs](https://pharmcat.org/using/VCF-Requirements).

### Liftover

Manual liftover to GRCh38.p13 (the reference genome used by PharmCAT) using
GATK/Picard.

This is taking a while, on an M3 MacBook Air with 16GB RAM it took about 5h and
30min for me. You can maybe play around with the memory settings `-Xmx12G` and
parameters such as `--MAX_RECORDS_IN_RAM`.
  
```bash
docker run --rm -v ./data:/data broadinstitute/gatk:4.1.3.0 ./gatk \
  CreateSequenceDictionary -R /data/references/genomes/GRCh38.p13.23andMe.fa
docker run --rm -v ./data:/data broadinstitute/gatk:4.1.3.0 ./gatk LiftoverVcf \
  --java-options  "-Xmx12G" \
  --TMP_DIR /data/liftover-temp \
  -I /data/data.vcf \
  -O /data/data.hg38.vcf \
  --CHAIN /data/references/GRCh37_to_GRCh38.chain.gz \
  --REJECT /data/liftover_rejected_variants.vcf \
  -R /data/references/genomes/GRCh38.p13.23andMe.fa
```

### Normalization

To normalize the VCF file, run

```bash
docker run --rm -v ./data:/data -w /data uyg-to-pharme \
  bcftools norm -m+ -c ws -Oz -o data.normalized.vcf \
  -f /data/references/genomes/GRCh38.p13.23andMe.fa data.hg38.vcf
```

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

### Inspecting PharmCAT Created Files

You can check the content of (intermediate) compressed processed VCFs (when
running the preprocessing command with the `-k` option) with:
`docker run --rm -v ./data:/data -w /data uyg-to-pharme bgzip -k -d data.vcf.bgz`

## Imputation

... using [Beagle](https://faculty.washington.edu/browning/beagle/beagle.html)

🚧 _TODO: update genotypes after liftover_
   _but genotype stayed 1/1_
🚧 _TODO: iterate per chromosome_
🚧 _TODO: merge_

```bash
docker run --rm -v ./data:/data -w /data uyg-to-pharme \
  java -jar /opt/beagle.jar gt=data.preprocessed.vcf \
    out=imputed.chr1 \
    chrom=1 \
    map=/data/references/imputation/maps/plink.chr1.GRCh38.map \
    ref=/data/references/imputation/reference/chr1.1kg.phase3.v5a.b37.bref3
```

## Load Into PharMe

🚧 _TODO: parse and describe how to load into PharMe_
