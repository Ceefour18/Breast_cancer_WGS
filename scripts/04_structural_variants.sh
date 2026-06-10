#!/bin/bash
set -e

REF="data/ref/Homo_sapiens_assembly38.fasta"
T_BAM="data/tumor/tumor_dedup.bam"
N_BAM="data/normal/normal_dedup.bam"
MANTA_DIR="data/manta_work"

echo "========================================="
echo "STEP 1: Pulling Illumina Manta Container..."
echo "========================================="
sudo docker pull quay.io/biocontainers/manta:1.6.0--h9ee0642_1

echo "========================================="
echo "STEP 2: Configuring Manta Somatic Pipeline..."
echo "========================================="
sudo docker run --rm -v $(pwd):/workspace -w /workspace quay.io/biocontainers/manta:1.6.0--h9ee0642_1 \
    configManta.py \
    --normalBam "${N_BAM}" \
    --tumorBam "${T_BAM}" \
    --referenceFasta "${REF}" \
    --runDir "${MANTA_DIR}"

echo "========================================="
echo "STEP 3: Executing Manta Engine..."
echo "========================================="
sudo docker run --rm -v $(pwd):/workspace -w /workspace quay.io/biocontainers/manta:1.6.0--h9ee0642_1 \
    ${MANTA_DIR}/runWorkflow.py -m local -j 16

echo "========================================="
echo "STRUCTURAL VARIANT CALLING COMPLETE!"
echo "========================================="
