# UYG to PharMe Data Conversion

Dockerfile and instructions to convert (my) genetic data from the (2020) UYG
course :bulb: to a format that can be used by PharMe. :dna::pill:

## Prerequisites

### Data

* (Your) genetic data in 23andMe format or in PLINK format
* Docker installed
* Potentially rename your data to match commands (or rename the paths in the
  commands below): `data/data.txt` (23andMe format) or in
    `data/data.bim`, `data/data.bed`, `data/data.fam` (PLINK format)

### Setup

1. Either pull this Docker image or build it locally (e.g., if you would like to
   make changes):
   * Pull Docker image:
     * `docker pull ghcr.io/tamslo/uyg-pharme-conversion:main`
     * For Apple Silicon you may need to add `--platform linux/x86_64`
     * The container ID to start the container will be
      `ghcr.io/tamslo/uyg-pharme-conversion:main`
   * Clone this repository and build locally:
     * `docker build -t uyg-to-pharme .`
     * The container ID to start the container will be `uyg-to-pharme`
2. Pull the latest PharmCAT image: `docker pull pgkb/pharmcat`.
3. Potentially download reference files as needed:
   * Start container (see [below](#how-to-use))
   * Run script with `bash scripts/download_reference_data.sh`
   * You will not need all if the PharmCAT preprocessing works for you or you do
     not want to impute (comment out what you will not need at the end of
     `scripts/download_reference_data.sh`)

## How to use

Start the Docker container in one terminal window with
`docker run -it --rm -v ./data:/data -w /data CONTAINER_ID` (e.g.,
`docker run -it --rm -v ./data:/data -w /data ghcr.io/tamslo/uyg-pharme-conversion:main`).

All commands below BUT the PharmCAT commands can be executed in this container.

1. Convert your data to VCF
   * If your data is in PLINK format, first convert it to 23andMe format:

     ```bash
      plink --bed data.bed --bim data.bim --fam data.fam \
        --recode 23 --out data
     ```

   * To convert the 23andMe format, do:

     ```bash
      bcftools convert -c ID,CHROM,POS,AA --tsv2vcf data.txt \
        -f /data/references/genomes/GRCh37.num_id.fa -s Sample -Oz -o data.vcf
     ```

     (for more information refer to this
     [BCFtools tutorial](https://samtools.github.io/bcftools/howtos/convert.html))

2. Preprocess VCF file ([Docs](https://pharmcat.org/using/VCF-Preprocessor/));
   if you run into any problems, such as a lot of missing variants, please
   refer to the [Manual Preprocessing](#manual-preprocessing) section

     ```bash
     docker run --rm -v ./data:/data -w /data pgkb/pharmcat \
       pharmcat_vcf_preprocessor -v -vcf data.vcf
     ```

3. Optionally, impute your data (see [Imputation](#imputation))
4. Run PharmCAT

     ```bash
     docker run --rm -v ./data:/data -w /data pgkb/pharmcat \
       pharmcat_pipeline data.[preprocessed|imputed].vcf[.gz]

     ```

## Manual Preprocessing

Manual preprocessing steps to fix and/or clarify problems. Also see
[PharmCAT Docs](https://pharmcat.org/using/VCF-Requirements).

For me, the PharmCAT preprocessing script worked after the manual liftover.

### Liftover

Manual liftover to GRCh38.p13 (the reference genome used by PharmCAT) using
the BCFTools
[liftover plugin](https://github.com/freeseek/score?tab=readme-ov-file#liftover-vcfs).

```bash
# Before this, manually remove lines with position zero: `	0	IlmnSeq`
bcftools +liftover -Oz data.vcf -- \
  -s references/genomes/GRCh37.num_id.fa \
  -f references/genomes/GRCh38.p13.num_id.fa \
  -c references/hg19ToHg38.over.chain.gz \
  --reject liftover_rejected_variants.bcf \
  -Oz data.hg38.vcf | bcftools sort -Ob -o data.hg38.vcf
```

### Normalization

```bash
bash scripts/normalize.sh data.hg38.vcf data.normalized.vcf
```

### Sort by Position

```bash
bash scripts/sort.sh data.normalized.vcf data.sorted.vcf
```

### Chromosome Fix

To prefix the chromosome with `chr`, use

```bash
bash scripts/fix_chromosomes.sh data.sorted.vcf data.preprocessed.vcf
```

### Imputation

... using [Beagle](https://faculty.washington.edu/browning/beagle/beagle.html)
(also see the
[Documentation](https://faculty.washington.edu/browning/beagle/beagle_5.5_17Dec24.pdf)).

ℹ️ The imputation script already takes care of all the other preprocessing
steps on the single chromosome files (otherwise some commands may fail on the
large merged file).

```bash
bash scripts/impute.sh data.hg38.vcf data.imputed.vcf.gz
```

#### Workaround

⚠️ *Currently PharmCAT directly using the `data.imputed.vcf.gz` yields less*
*results than the original preprocessed file. Possibly the filtering also*
*removes actual variants, need to check this.*

Run PharmCAT with your non-imputed data first and amend imputed variants that
are included in the `data.preprocessed.missing_pgx_var.vcf` file.

```bash
# First intersect the imputed data with positions that are interesting
bgzip data.preprocessed.missing_pgx_var.vcf
tabix -p vcf data.preprocessed.missing_pgx_var.vcf.gz
tabix -p vcf data.imputed.vcf.gz
bcftools isec -p isec_output -Oz data.imputed.vcf.gz data.preprocessed.missing_pgx_var.vcf.gz

# Merge imputed and missing variants into preprocessed data
bgzip -d data.preprocessed.vcf.bgz
bgzip data.preprocessed.vcf
tabix -p vcf data.preprocessed.vcf.gz
bcftools concat -a data.preprocessed.vcf.gz isec_output/0002.vcf.gz -o data.concat.preprocessed.imputed.vcf.gz
tabix -p vcf data.concat.preprocessed.imputed.vcf.gz
bcftools sort data.concat.preprocessed.imputed.vcf.gz -Oz -o data.final.preprocessed.imputed.vcf.gz
```

#### Caveats

⚠️ *I had a problem for the Y chromosome reports, may be fixed if you actually*
*have a Y chromosome; however, changing the ploidy to diploid for all Y*
*variants for diploid in `adapt_y_ploidy.py` as part of the `impute.sh` script*
*for now.*

⚠️ *The normalization tool has problems with merging description fields of*
*some variants with missing genotype calls with the same position, therefore a*
*script removes the INFO and FORMAT fields added in the imputation.*

⚠️ *Known problem: the normalization may fail with*
*`Error at <chr>:<pos>: incorrect allele index 1`*

*in this case, please review and update the `imputed.chr<chr>.clean.vcf.gz`*
*file manually at `<pos>`, i.e., decompress, decide which variant to keep, and*
*compress updated (see*
*[Inspecting Intermediate Files](#inspecting-intermediate-files)), e.g.:*

```bash
currentChrom=<chr>
# Delete incomplete normalization file
rm imputation-temp/imputed.chr$currentChrom.normalized.vcf.gz
bgzip -d imputation-temp/imputed.chr$currentChrom.clean.vcf.gz
# Manually edit file at <pos> and potentially keep a record of your changes
bgzip imputation-temp/imputed.chr$currentChrom.clean.vcf
```

### Inspecting Intermediate Files

This may be helpful when you encounter preprocessing errors.

You can check the content of (intermediate) compressed processed VCFs (for
manual preprocessing or when running the PharmCAT preprocessing command with
the `-k` option) with:

`bgzip -d <file.[b]gz>`

Compress files again without the `-d` option.

## Load Into PharMe

🚧 *TODO: describe how to load into PharMe; e.g., without PharmCAT and master's*
*project or properly parse and upload to (local) lab server setup. But one*
*could also check the PharmCAT output, I guess someone who can make these*
*scripts work will manage with the "expert version".* 😊
