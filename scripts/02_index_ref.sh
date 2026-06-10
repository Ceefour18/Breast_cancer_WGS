#!/bin/bash
set -e

REF_DIR="data/ref"
REF_FASTA="${REF_DIR}/Homo_sapiens_assembly38.fasta"

echo "========================================="
echo "STEP 1: Downloading Human Reference Genome (GRCh38) from S3..."
echo "========================================="
aws s3 cp s3://broad-references/hg38/v0/Homo_sapiens_assembly38.fasta "${REF_FASTA}" --no-sign-request

echo "========================================="
echo "STEP 2: Installing BWA and Generating BWA Index..."
echo "========================================="
sudo apt-get install -y bwa
bwa index "${REF_FASTA}"

echo "========================================="
echo "STEP 3: Generating FAI Index..."
echo "========================================="
sudo docker run --rm -v $(pwd):/workspace -w /workspace broadinstitute/gatk:4.6.0.0 \
    samtools faidx "${REF_FASTA}"

echo "========================================="
echo "STEP 4: Creating GATK Sequence Dictionary..."
echo "========================================="
sudo docker run --rm -v $(pwd):/workspace -w /workspace broadinstitute/gatk:4.6.0.0 \
    gatk CreateSequenceDictionary -R "${REF_FASTA}"

echo "========================================="
echo "GENOME INDEXING COMPLETE!"
echo "========================================="
