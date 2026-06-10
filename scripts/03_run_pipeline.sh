#!/bin/bash
set -e

REF="data/ref/Homo_sapiens_assembly38.fasta"
T_DIR="data/tumor"
N_DIR="data/normal"
OUT_DIR="data/output"

echo "========================================="
echo "STEP 1: Installing SRA Toolkit & Downloading HCC1395 WGS FASTQs..."
echo "========================================="
if ! command -v fasterq-dump &>/dev/null; then
    echo "Installing SRA Toolkit..."
    sudo apt-get install -y sra-toolkit
fi

# Tumor: HCC1395 breast cancer WGS (SRR7890824)
echo "Downloading tumor sample (SRR7890824)..."
fasterq-dump SRR7890824 --outdir "${T_DIR}" --split-files --threads 16 --location AWS
mv "${T_DIR}/SRR7890824_1.fastq" "${T_DIR}/tumor_R1.fastq"
mv "${T_DIR}/SRR7890824_2.fastq" "${T_DIR}/tumor_R2.fastq"
gzip "${T_DIR}/tumor_R1.fastq" "${T_DIR}/tumor_R2.fastq"

# Normal: HCC1395BL matched normal WGS (SRR7890827)
echo "Downloading normal sample (SRR7890827)..."
fasterq-dump SRR7890827 --outdir "${N_DIR}" --split-files --threads 16 --location AWS
mv "${N_DIR}/SRR7890827_1.fastq" "${N_DIR}/normal_R1.fastq"
mv "${N_DIR}/SRR7890827_2.fastq" "${N_DIR}/normal_R2.fastq"
gzip "${N_DIR}/normal_R1.fastq" "${N_DIR}/normal_R2.fastq"

echo "========================================="
echo "STEP 2: Aligning Reads with BWA-MEM..."
echo "========================================="
echo "Aligning Normal Sample..."
sudo docker run --rm -v $(pwd):/workspace -w /workspace broadinstitute/gatk:4.6.0.0 \
    bwa mem -t 16 -R '@RG\tID:normal\tSM:normal\tPL:ILLUMINA' \
    "${REF}" "${N_DIR}/normal_R1.fastq.gz" "${N_DIR}/normal_R2.fastq.gz" | \
sudo docker run --rm -i -v $(pwd):/workspace -w /workspace broadinstitute/gatk:4.6.0.0 \
    samtools sort -@ 16 -o "${N_DIR}/normal_sorted.bam" -

echo "Aligning Tumor Sample..."
sudo docker run --rm -v $(pwd):/workspace -w /workspace broadinstitute/gatk:4.6.0.0 \
    bwa mem -t 16 -R '@RG\tID:tumor\tSM:tumor\tPL:ILLUMINA' \
    "${REF}" "${T_DIR}/tumor_R1.fastq.gz" "${T_DIR}/tumor_R2.fastq.gz" | \
sudo docker run --rm -i -v $(pwd):/workspace -w /workspace broadinstitute/gatk:4.6.0.0 \
    samtools sort -@ 16 -o "${T_DIR}/tumor_sorted.bam" -

echo "========================================="
echo "STEP 3: Marking Duplicates (Picard)..."
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
echo "STEP 4: Somatic Variant Calling (Mutect2)..."
echo "========================================="
sudo docker run --rm -v $(pwd):/workspace -w /workspace broadinstitute/gatk:4.6.0.0 \
    gatk Mutect2 \
    -R "${REF}" \
    -I "${T_DIR}/tumor_dedup.bam" \
    -I "${N_DIR}/normal_dedup.bam" \
    -normal normal \
    -O "${OUT_DIR}/somatic_variants.vcf"

echo "========================================="
echo "STEP 5: Filtering Mutect2 Calls..."
echo "========================================="
sudo docker run --rm -v $(pwd):/workspace -w /workspace broadinstitute/gatk:4.6.0.0 \
    gatk FilterMutectCalls \
    -R "${REF}" \
    -V "${OUT_DIR}/somatic_variants.vcf" \
    -O "${OUT_DIR}/somatic_filtered.vcf"

echo "========================================="
echo "PIPELINE COMPLETE!"
echo "========================================="
