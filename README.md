# UYG to PharMe Data Conversion

🚧 Work in progress, still figuring this out!

Dockerfile and instructions to convert (my) genetic data from the (2020) UYG
course :bulb: to a format that can be used by PharMe. :dna::pill:

## Prerequisites

* Your full genetic data in `data/data.dat` and `data/data.txt`

## How to use

1. Build Docker container `docker build -t uyg-to-pharme .`
2. Run Docker container and mount data directory as volume
   `docker run -v ./data:/data -w /data -it --rm uyg-to-pharme`
3. Convert your data to VCF with `plink --recode vcf TODO` _(still trying to_
   _find out what format the data is in exactly to recode)_

_Future steps: normalize to hg38 (needs reference file), call star alleles with_
_PharmCAT, possibly need to impute before, parse output to PharMe format,_
_describe how to load into PharMe._
