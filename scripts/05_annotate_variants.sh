#!/bin/bash
set -e

echo "========================================="
echo "STEP 1: Pulling Ensembl VEP Tool..."
echo "========================================="
sudo docker pull ensemblorg/ensembl-vep:release.110

echo "========================================="
echo "STEP 2: Annotating Filtered VCF Output..."
echo "========================================="
sudo docker run --rm -v $(pwd):/workspace -w /workspace ensemblorg/ensembl-vep:release.110 \
    vep \
    -i data/output/somatic_filtered.vcf \
    -o data/output/annotated_variants.txt \
    --database \
    --assembly GRCh38 \
    --symbol \
    --terms SO \
    --hgvs

echo "========================================="
echo "ANNOTATION COMPLETE!"
echo "========================================="
