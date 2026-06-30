# HCC1395 Somatic WGS Pipeline — SEQC2 Benchmark

End-to-end tumour-normal whole genome sequencing somatic variant 
calling pipeline on HCC1395 (triple-negative breast cancer) and 
HCC1395BL (matched normal), benchmarked against the SEQC2 v1.2 
gold-standard truth set.

> ⚠️ **Status: In Progress** — pipeline is actively being developed 
> and validated. Results will be updated as stages are completed.

## Pipeline Overview
FASTQ → FastQC → Read-name Normalisation → BWA-MEM → 
MarkDuplicates → BQSR → Mutect2 → FilterMutectCalls → 
SnpEff → SEQC2 Validation → ROC Analysis

## Progress
- [x] FASTQ QC and read-name normalisation
- [x] BWA-MEM alignment
- [x] MarkDuplicates and BQSR
- [x] Mutect2 tumour-normal calling
- [ ] FilterMutectCalls and variant refinement
- [ ] SnpEff annotation
- [ ] SEQC2 benchmark validation
- [ ] ROC analysis

## Key Challenge Solved — FASTQ Read-Name Mismatch
BWA-MEM initially produced empty BAMs with zero mapped reads.
Root cause: inconsistent read-name suffixes between tumour R1 and R2 
files after SRA download and local rename step. BWA requires strictly 
paired read names — a mismatch produces zero proper pairs and a 
pipeline that completes but yields no callable variants.

**Fix:** wrote a normalisation script to strip platform-specific 
suffixes and enforce consistent read naming across all four FASTQ 
files. Confirmed paired-end integrity with FastQC before resubmitting 
alignment. This single fix unblocked the entire downstream 
Mutect2 chain.

## Infrastructure
| Resource | Specification |
|----------|--------------|
| AWS EC2 | r6i.4xlarge — 16 vCPU, 128 GB RAM |
| Storage | 500 GB gp3 |
| Compute | Google Colab Pro+ with Drive mount |
| Reference | GRCh38 / hg38 |

## Tools & Environment
| Tool | Purpose |
|------|---------|
| GATK 4.6 | Mutect2 calling & filtering |
| BWA-MEM | Paired-end alignment |
| SAMtools | BAM processing |
| SnpEff | Functional annotation |
| Docker | Reproducibility |
| Python / R | Validation & visualisation |

## Data
- Tumour: HCC1395 (triple-negative breast cancer cell line)
- Normal: HCC1395BL (matched blood normal)
- Source: SEQC2 consortium SRA
- Reference: GRCh38

## Planned Next Steps
- Complete FilterMutectCalls and SEQC2 benchmark validation
- Port pipeline to Nextflow with nf-core conventions
- Integrate RNA-seq for multi-omics driver confirmation
- Add CNV calling given HCC1395 known aneuploidy profile

## Author
Clement Akinsola (Ceefour18)
Clinical Bioinformatician | Cancer Genomics
Portfolio: https://ceefour18.github.io
LinkedIn: linkedin.com/in/clement-akinsola
