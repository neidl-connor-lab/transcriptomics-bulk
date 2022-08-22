# rnaseq-bulk
Jackie's bulk RNA-seq workflow

## Requirements

Computing cluster with [modules](https://www.bu.edu/tech/support/research/software-and-programming/software-and-applications/modules/) for [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/), [MultiQC](https://multiqc.info/), [STAR aligner](https://doi.org/10.1093/bioinformatics/bts635), and [featureCounts](https://doi.org/10.1093/bioinformatics/btt656).

| Package  | Version |
| :------: | :-----: |
| fastqc   | 0.11.7  |
| star     | 2.7.1a  |
| subread  | 1.6.2   |
| python   | 3.7.9   |
| multiqc  | 1.10.1  |

## Pipeline steps

### 0. Input

Raw paired-end FASTQ files should be gzipped and renamed such that each sample (e.g., `sample01`) has the following files in the input directory. I recommend putting all sample descriptors as columns in your metadata file instead of the filename!

1. `sample01-r1.fq.gz`
2. `sample02-r2.fq.gz`

### 1. Align to reference

Raw FASTQ files are aligned to the previously-constructed reference using [STAR aligner](https://doi.org/10.1093/bioinformatics/bts635). All output files have the sample ID as a prefix. The alignment itself is saved to `output/sample01-Aligned.out.bam`.

The flags in use mean:
- `--runThreadN` parallelize this job
- `--runMode` align reads instead of making an index
- `--genomeDir` give the path to the genome index
- `--readFilesCommand` the input files are gzipped (`*.gz`)
- `--outSAM*` compress the output and don't bother sorting the reads
- `--readFilesIn` give the path to the R1 and R2 files
- `--outFileNamePrefix` where should the output files go, and what should they be named?

```
STAR --runThreadN 16 --runMode alignReads --genomeDir 'indices/genomedir' --readFilesCommand zcat --outSAMtype BAM Unsorted --outSAMunmapped Within --readFilesIn 'input/sample01-r1.fq.gz' 'input/sample01-r2.fq.gz' --outFileNamePrefix 'output/sample01-'
```

### 2. Quantify aligned reads

Aligned reads in the `*-Aligned.out.bam` file are quantified using [featureCounts](https://doi.org/10.1093/bioinformatics/btt656), which is a tool in the subread module. This will output a counts matrix, which is the input for differential expression calculations.

The flags in use mean:
- `-T` parallelize this job
- `-M` count reads that align to more than one locus
- `-p` these alignments come from paired-end sequencing
- `-t` the annotation feature to use for quantification. Use `exon` if the library was prepared with polyA selection; otherwise, use `transcript`.
- `-g` the annotation feature to use for labeling. For example, using `gene_id` will pool all exon/transcript counts for a single gene. Using `gene_name` as shown below will use human-readable gene names, rather than IDs.
- `-O` collapse all counts to their respective `-g` feature, rather than counting by exon/transcript
- `-a` the annotation GTF file used to the build the index used in alignment
- `-o` path and name of the output count matrix
- `...` BAM alignment files generated in step 1

```
featureCounts -T 16 -M -p -t FEATURE -g gene_name -O -a 'annotatiaon.gtf' -o 'output/counts.tsv'  'output/sample01-Aligned.out.bam' ...
```

### 3. Check input quality

The [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) tool evaluates raw read quality. Running this on each sample allow us to flag potential problematic samples before running differential expression analysis.

```
fastqc --threads 16 --quiet --outdir 'data'  'data/sample01-r1.fq.gz' 'data/sample02-r1.fq.gz' ...
```

### 4. Compile QC metrics

The [MultiQC](https://multiqc.info/) tool will compile output logs from FastQC, STAR, and featureCounts to generate a report on our entire pipeline. This will be our first stop when `pipeline.sh` finishes running -- you can see here what any problems may be before moving forward.

```
multiqc --quiet --outdir 'data' --filename 'multiqc.html' --module fastqc --module star --module featureCounts 'data'
```

