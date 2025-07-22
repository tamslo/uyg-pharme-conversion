# UYG to PharMe Data Conversion

Dockerfile and instructions to convert (my) genetic data from the (2020) UYG
course :bulb: to a format that can be used by PharMe. :dna::pill:

## Prerequisites

Added times ⏱️ so you know can estimate long it takes to set up.

### Setup

0. Have Docker installed 🐳
1. Either pull this Docker image or build it locally (e.g., if you would like to
   make changes):
   * Pull Docker image:
     * `docker pull ghcr.io/tamslo/uyg-pharme-conversion:main`
     * For Apple Silicon you may need to add `--platform linux/x86_64`
     * The image name to start the container will be
      `ghcr.io/tamslo/uyg-pharme-conversion:main`
     * ⏱️ *Pulling this image took about 2 min for me.*
   * Clone this repository and build locally:
     * `docker build -t uyg-to-pharme .`
     * The image name to start the container will be `uyg-to-pharme`
     * ⏱️ *Building this image took about 4 min for me.*
2. Pull the latest PharmCAT image:
   * `docker pull pgkb/pharmcat`
   * ⏱️ *Pulling this image took about 5 min for me.*
3. Start the Docker container in one terminal window (replace the image name
   if using local image)

   ```bash
   docker run -it --rm -v ./data:/data -w /data ghcr.io/tamslo/uyg-pharme-conversion:main
   ```

4. Start a separate terminal to run the PharmCAT commands 💊🐱

### Data

* (Your) genetic data in 23andMe format or in PLINK format
* Potentially rename your data to match commands (or rename the paths in the
  commands below): `data/data.txt` (23andMe format) or in
    `data/data.bim`, `data/data.bed`, `data/data.fam` (PLINK format)
* Potentially download reference files as needed:
  * You will not need all files if the PharmCAT preprocessing works for you or
    you do not want to impute (comment out what you will not need at the end of
    `scripts/download_reference_data.sh`)
  * Run script in Docker container `bash scripts/download_reference_data.sh`

⏱️ *Downloading the reference data without imputation data took about 6.5 min*
*for me, for the imputation data it took about 18 min.*

## How to use

1. Convert your data to VCF
   * If your data is in PLINK format, first convert it to 23andMe format:

     ```bash
     plink --bed data.bed --bim data.bim --fam data.fam --recode 23 --out data
     ```

   * To convert the 23andMe format, do:

     ```bash
     bcftools convert -c ID,CHROM,POS,AA --tsv2vcf data.txt \
         -f /data/references/genomes/GRCh37.num_id.fa -s Sample -Oz -o data.vcf
     ```

     (for more information refer to this
     [BCFtools tutorial](https://samtools.github.io/bcftools/howtos/convert.html))

2. Liftover from hg19 to hg38:

   ```bash
   bash scripts/liftover.sh data.vcf data.hg38.vcf
   ```

   If you get `Error: the reference allele N does not match the reference  at 1:0`, filter zero positions out before lifting over

   ```bash
   mv data.vcf data.with-zero-pos.vcf
   bcftools view --exclude 'POS=0' data.with-zero-pos.vcf -o data.vcf
   ```

3. Preprocess VCF file ([Docs](https://pharmcat.org/using/VCF-Preprocessor/))
   💊🐱

     ```bash
     docker run --rm -v ./data:/data -w /data pgkb/pharmcat \
       pharmcat_vcf_preprocessor -v -vcf data.hg38.vcf -o pharmcat-no-imputation
     ```

    If you run into any problems, such as pretty much all variants missing, the
    [Manual Preprocessing](#manual-preprocessing) could help to investigate.

4. Optionally, impute your data (see [Imputation](#imputation))

5. Run PharmCAT 💊🐱

     ```bash
     docker run --rm -v ./data:/data -w /data pgkb/pharmcat \
       pharmcat_pipeline <your_preprocessed_file>
     ```

## Imputation

Impute and liftover your data with the following script (uses
[Beagle 5.5](https://faculty.washington.edu/browning/beagle/beagle.html), see the [Documentation](https://faculty.washington.edu/browning/beagle/beagle_5.5_17Dec24.pdf))

```bash
bash scripts/impute.sh data.vcf data.imputed.hg38.vcf.gz
```

Then preprocess the imputed data using the PharmCAT preprocessing script 💊🐱

```bash
docker run --rm -v ./data:/data -w /data pgkb/pharmcat \
  pharmcat_vcf_preprocessor -v -vcf data.imputed.hg38.vcf.gz -o pharmcat-imputed
```

Using this data in PharmCAT directly will (strangely) lead to more missing
variants (if it does not for you, great, continue with the imputed data).

In the following, we will merge the present data with imputed variants that were
reported as missing when preprocessing your data (reported in
`data.preprocessed.missing_pgx_var.vcf`).

```bash
# First intersect the imputed data with positions that are interesting
bgzip -k pharmcat-no-imputation/data.hg38.missing_pgx_var.vcf
tabix -p vcf pharmcat-no-imputation/data.hg38.missing_pgx_var.vcf.gz
bcftools isec -p missing-imputed \
  -Oz pharmcat-imputed/data.imputed.hg38.preprocessed.vcf.bgz \
  pharmcat-no-imputation/data.hg38.missing_pgx_var.vcf.gz

# Merge imputed and missing variants into hg38 data
mkdir pharmcat-missing-imputed
bcftools concat -a pharmcat-no-imputation/data.hg38.preprocessed.vcf.bgz \
  missing-imputed/0002.vcf.gz -o \
  pharmcat-missing-imputed/data.hg38.missing-imputed.vcf.gz
tabix -p vcf \
  pharmcat-missing-imputed/data.hg38.missing-imputed.vcf.gz
bcftools sort \
  pharmcat-missing-imputed/data.hg38.missing-imputed.vcf.gz \
  -Oz -o pharmcat-missing-imputed/data.hg38.preprocessed.imputed.vcf.gz
```

Continue with running PharmCAT.

Please consider the following imputation **caveats**:

⚠️ *I am not sure why the imputation results in more missing variants for*
*PharmCAT; I suppose this could happen due to the normalization but did not*
*further look into it.*

⚠️ *I had a problem for the Y chromosome reports, may be fixed if you actually*
*have a Y chromosome; however, changing the ploidy to diploid for all Y*
*variants for diploid in `adapt_y_ploidy.py` as part of the `impute.sh` script*
*for now.*

⚠️ *We are currently not including any quality control to the imputed data.*

## Manual Preprocessing

Manual preprocessing steps to fix and/or clarify problems. Also see
[PharmCAT Docs](https://pharmcat.org/using/VCF-Requirements).

Have a look at the scripts for details.

```bash
bash scripts/normalize.sh data.hg38.vcf data.normalized.vcf
bash scripts/sort.sh data.normalized.vcf data.sorted.vcf
bash scripts/fix_chromosomes.sh data.sorted.vcf data.preprocessed.vcf
```

You can check the content of (intermediate) compressed processed VCFs (for
manual preprocessing or when running the PharmCAT preprocessing command with
the `-k` option) with:

`bgzip -d <file.[b]gz>`

Compress files again without the `-d` option.

## Load Into PharMe

You can use the preprocessed VCF file to load your data in PharMe.

Limitation: PharMe will only use the first possible genotype / phenotype, if
multiple are possible.

Further limitations: no CYP2D6 / HLA results (because we use PharmCAT as the
underlying technology).
