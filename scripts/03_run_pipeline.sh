#!/bin/bash
set -e

REF="data/ref/Homo_sapiens_assembly38.fasta"
T_DIR="data/tumor"
N_DIR="data/normal"
OUT_DIR="data/output"
KNOWN_SITES_DIR="data/ref"

echo "========================================="
echo "STEP 1: Pulling Docker Images..."
echo "========================================="
sudo docker pull biocontainers/bwa:v0.7.17_cv1
sudo docker pull broadinstitute/gatk:4.6.0.0

echo "========================================="
echo "STEP 2: Downloading Known Variant Sites for BQSR..."
echo "========================================="
aws s3 cp s3://broad-references/hg38/v0/Homo_sapiens_assembly38.dbsnp138.vcf \
    "${KNOWN_SITES_DIR}/dbsnp138.vcf" --no-sign-request
aws s3 cp s3://broad-references/hg38/v0/Homo_sapiens_assembly38.dbsnp138.vcf.idx \
    "${KNOWN_SITES_DIR}/dbsnp138.vcf.idx" --no-sign-request
aws s3 cp s3://broad-references/hg38/v0/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz \
    "${KNOWN_SITES_DIR}/mills_indels.vcf.gz" --no-sign-request
aws s3 cp s3://broad-references/hg38/v0/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz.tbi \
    "${KNOWN_SITES_DIR}/mills_indels.vcf.gz.tbi" --no-sign-request

echo "========================================="
echo "STEP 3: Aligning Reads with BWA-MEM..."
echo "========================================="

echo "Aligning Normal Sample..."
sudo docker run --rm -v $(pwd):/workspace -w /workspace biocontainers/bwa:v0.7.17_cv1 \
    bwa mem -t 16 -R '@RG\tID:normal\tSM:normal\tPL:ILLUMINA' \
    "${REF}" "${N_DIR}/normal_R1.fastq.gz" "${N_DIR}/normal_R2.fastq.gz" | \
sudo docker run --rm -i -v $(pwd):/workspace -w /workspace broadinstitute/gatk:4.6.0.0 \
    samtools sort -@ 16 -o "${N_DIR}/normal_sorted.bam" -

echo "Aligning Tumor Sample..."
sudo docker run --rm -v $(pwd):/workspace -w /workspace biocontainers/bwa:v0.7.17_cv1 \
    bwa mem -t 16 -R '@RG\tID:tumor\tSM:tumor\tPL:ILLUMINA' \
    "${REF}" "${T_DIR}/tumor_R1.fastq.gz" "${T_DIR}/tumor_R2.fastq.gz" | \
sudo docker run --rm -i -v $(pwd):/workspace -w /workspace broadinstitute/gatk:4.6.0.0 \
    samtools sort -@ 16 -o "${T_DIR}/tumor_sorted.bam" -

echo "========================================="
echo "STEP 4: Marking Duplicates (Picard)..."
echo "========================================="

sudo docker run --rm -v $(pwd):/workspace -w /workspace broadinstitute/gatk:4.6.0.0 \
    gatk MarkDuplicates \
    -I "${N_DIR}/normal_sorted.bam" \
    -O "${N_DIR}/normal_dedup.bam" \
    -M "${N_DIR}/normal_metrics.txt" \
    --CREATE_INDEX true

sudo docker run --rm -v $(pwd):/workspace -w /workspace broadinstitute/gatk:4.6.0.0 \
    gatk MarkDuplicates \
    -I "${T_DIR}/tumor_sorted.bam" \
    -O "${T_DIR}/tumor_dedup.bam" \
    -M "${T_DIR}/tumor_metrics.txt" \
    --CREATE_INDEX true

echo "========================================="
echo "STEP 5: Base Quality Score Recalibration (BQSR)..."
echo "========================================="

# Normal - BaseRecalibrator
sudo docker run --rm -v $(pwd):/workspace -w /workspace broadinstitute/gatk:4.6.0.0 \
    gatk --java-options "-Xmx24g" BaseRecalibrator \
    -I "${N_DIR}/normal_dedup.bam" \
    -R "${REF}" \
    --known-sites "${KNOWN_SITES_DIR}/dbsnp138.vcf" \
    --known-sites "${KNOWN_SITES_DIR}/mills_indels.vcf.gz" \
    -O "${N_DIR}/normal_recal.table"

# Normal - ApplyBQSR
sudo docker run --rm -v $(pwd):/workspace -w /workspace broadinstitute/gatk:4.6.0.0 \
    gatk --java-options "-Xmx24g" ApplyBQSR \
    -I "${N_DIR}/normal_dedup.bam" \
    -R "${REF}" \
    --bqsr-recal-file "${N_DIR}/normal_recal.table" \
    -O "${N_DIR}/normal_bqsr.bam"

# Tumor - BaseRecalibrator
sudo docker run --rm -v $(pwd):/workspace -w /workspace broadinstitute/gatk:4.6.0.0 \
    gatk --java-options "-Xmx24g" BaseRecalibrator \
    -I "${T_DIR}/tumor_dedup.bam" \
    -R "${REF}" \
    --known-sites "${KNOWN_SITES_DIR}/dbsnp138.vcf" \
    --known-sites "${KNOWN_SITES_DIR}/mills_indels.vcf.gz" \
    -O "${T_DIR}/tumor_recal.table"

# Tumor - ApplyBQSR
sudo docker run --rm -v $(pwd):/workspace -w /workspace broadinstitute/gatk:4.6.0.0 \
    gatk --java-options "-Xmx24g" ApplyBQSR \
    -I "${T_DIR}/tumor_dedup.bam" \
    -R "${REF}" \
    --bqsr-recal-file "${T_DIR}/tumor_recal.table" \
    -O "${T_DIR}/tumor_bqsr.bam"

echo "========================================="
echo "STEP 6: Somatic Variant Calling (Mutect2)..."
echo "========================================="

sudo docker run --rm -v $(pwd):/workspace -w /workspace broadinstitute/gatk:4.6.0.0 \
    gatk --java-options "-Xmx24g" Mutect2 \
    -R "${REF}" \
    -I "${T_DIR}/tumor_bqsr.bam" \
    -I "${N_DIR}/normal_bqsr.bam" \
    -normal normal \
    -O "${OUT_DIR}/somatic_variants.vcf"

echo "========================================="
echo "STEP 7: Filtering Mutect2 Calls..."
echo "========================================="

sudo docker run --rm -v $(pwd):/workspace -w /workspace broadinstitute/gatk:4.6.0.0 \
    gatk FilterMutectCalls \
    -R "${REF}" \
    -V "${OUT_DIR}/somatic_variants.vcf" \
    -O "${OUT_DIR}/somatic_filtered.vcf"

echo "========================================="
echo "PIPELINE COMPLETE!"
echo "Output: ${OUT_DIR}/somatic_filtered.vcf"
echo "========================================="
