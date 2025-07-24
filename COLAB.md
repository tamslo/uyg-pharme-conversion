# UYG to PharMe Data Conversion

Annotate (your) data with PGx information using PharmCAT and use it in PharMe!

These instructions are for [Google Colab](https://colab.research.google.com/).
To run everything locally in Docker, please refer to the [README](README.md).

For reference, I also shared the full
[Colab Notebook](https://colab.research.google.com/drive/1n7c5Lu19GOkRmvu_teYvXPuHTvl4ZNnY?usp=sharing).

⚠️ **Disclaimers**:

* The GSA data does not include all relevant variants, which can lead to inconclusive results; you may want to
  try imputation (please refer to the [README](README.md) for a starting point)
* PharmCAT does not cover all relevant genes, especially CYP2D6 and HLA

## Setup

1. Get the example and reference data including reference genomes with numeric
   chromosome IDs and a chain file for the liftover (see the
   [processing script](data/scripts/download_reference_data.sh) for reference)
   * Add the Google Drive folder
     [UYG-Test-Data](https://drive.google.com/drive/folders/1u4p47bVK1Tzxo6qHbNOM6FO5xQkpRqJG?usp=share_link)
     to your Drive
   * Add a shortcut under "My Drive" (Actions > Organize > Add shortcut) to make
     it available in Colab
   * Mount your Drive in Colab

     ```python
     from google.colab import drive
     drive.mount('/content/drive', force_remount=True)
     ```

     The imported data should be available under
     `/content/drive/MyDrive/UYG-Test-Data`
   * Copy the example data to `/content` to work with the files

     ```bash
     %%bash
     mkdir -p /content/data
     cp /content/drive/MyDrive/UYG-Test-Data/data.{bed,bim,fam} /content/data

2. Install Docker

   ```bash
   %%bash
   pip install udocker
   udocker --allow-root install
   ```

3. Pull the Docker images for preprocessing and PharmCAT:

   ```bash
   %% bash
   udocker --allow-root pull ghcr.io/tamslo/uyg-pharme-conversion:main
   udocker --allow-root pull pgkb/pharmcat
   ```

## How to use

1. Convert your data to VCF; use the 23andMe format as an intermediate step to
   receive a properly formatted VCF from BCFtools

     ```bash
     %%bash
     udocker --allow-root run \
       -v /content/data:/data \
       -w /data ghcr.io/tamslo/uyg-pharme-conversion:main \
       plink --bed data.bed --bim data.bim --fam data.fam --recode 23 --out data
     udocker --allow-root run \
       -v /content/data:/data \
       -v /content/drive/MyDrive/UYG-Test-Data/references:/references \
       -w /data ghcr.io/tamslo/uyg-pharme-conversion:main \
       bcftools convert -c ID,CHROM,POS,AA --tsv2vcf data.txt \
         -f /references/GRCh37.num_id.fa -s Sample -Oz -o data.vcf
     ```

2. Liftover from hg19 to hg38:

   ```bash
   %%bash
   udocker --allow-root run \
     -v /content/data:/data \
     -v /content/drive/MyDrive/UYG-Test-Data/references:/references \
     -w /data ghcr.io/tamslo/uyg-pharme-conversion:main \
     bcftools +liftover -Oz data.vcf -o data.hg38.vcf -- \
       -s /references/GRCh37.num_id.fa \
       -f /references/GRCh38.p13.num_id.fa \
       -c /references/hg19ToHg38.over.chain.gz \
       --reject liftover_rejected_variants.bcf
   ```

   If you get
   `Error: the reference allele N does not match the reference  at 1:0`,
   filter zero positions out before lifting over

   ```bash
   %%bash
   mv data/data.vcf data/data.with-zero-pos.vcf
   udocker --allow-root run \
     -v /content/data:/data \
     -w /data ghcr.io/tamslo/uyg-pharme-conversion:main \
     bcftools view --exclude 'POS=0' data.with-zero-pos.vcf -o data.vcf
   ```

3. Preprocess VCF file ([Docs](https://pharmcat.org/using/VCF-Preprocessor/))

     ```bash
     %%bash
     udocker --allow-root run -v /content/data:/data -w /data pgkb/pharmcat \
       pharmcat_vcf_preprocessor -v -vcf data.hg38.vcf
     ```

4. Run PharmCAT

     ```bash
     %%bash
     udocker --allow-root run -v /content/data:/data -w /data pgkb/pharmcat \
       pharmcat_pipeline data.hg38.preprocessed.vcf.bgz
     ```

5. Have a look at your report in `data.hg38.preprocessed.report.html`

## Load Into PharMe

You can use the preprocessed VCF file to load your data in PharMe.

Decompress it using

```bash
%%bash
udocker --allow-root run \
  -v /content/data:/data \
  -w /data ghcr.io/tamslo/uyg-pharme-conversion:main \
  bgzip -d -k data.hg38.preprocessed.vcf.bgz
```

Limitation: PharMe will only use the first possible genotype / phenotype, if
multiple are possible.

Further limitations: no CYP2D6 / HLA results (because we use PharmCAT as the
underlying technology).
