# rnaseq-bulk
Jackie's bulk RNA-seq workflow

## Requirements

Computing cluster with [modules](https://www.bu.edu/tech/support/research/software-and-programming/software-and-applications/modules/) for [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/), [MultiQC](https://multiqc.info/), [STAR aligner](https://doi.org/10.1093/bioinformatics/bts635), and [featureCounts](https://doi.org/10.1093/bioinformatics/btt656).

| Package  | Version |
| :------- | :------ |
| fastqc   | 0.11.7  |
| star     | 2.7.1a  |
| subread  | 1.6.2   |
| python   | 3.7.9   |
| multiqc  | 1.10.1  |

## Quick start

### 1. Download repo 

Cloning this repo will create a directory holding the pipeline script and assorted files. Move to the directory where you'd like to save the pipeline.

```
cd pipelines/
git clone https://github.com/neidl-connor-lab/transcriptomics-bulk.git
cd transcriptomics-bulk
```

### 2. Make alignment index

Coming soon...

### 3. Run pipeline

View pipeline options and required arguments by running `pipeline.sh` with the `-h` flag.

```
./pipeline.sh -h
```

The help message indicates the required arguments and how to pass them:

| Flag | Argument                        |
| :--- | :------------------------------ |
| `-P` | SCC project                     |
| `-N` | job name                        |
| `-i` | path to index created in step 2 |
| `-g` | path to GTF file used in step 2 |
| `-f` | directory with FASTQ files      |
| `-o` | output directory                |

```
usage: qsub -P PROJECT -N JOBNAME pipeline.sh -i INDEX -g GTF -f FASTQ -o OUTPUT

arguments (default):
  -i path to STAR index
  -g path to GTF annotation
  -f input FASTQ directory 
  -o output directory
  -h show this message and exit
```

Here is an example, where the index materials are in `indices/`, FASTQ input files are in `input-files/`, and output files should go to `output-files/`. The example job is named `test-job`, and the project allocation used is `test-project`. The job output will be written to a file named `log-test-job.qlog`.

```
qsub -P test-project \
     -N test-job pipeline.sh \
     -i indices/test-index/ \
     -g indices/test-index.gtf \
     -f input-files/ \
     -o output-files/
```

## Pipeline steps

### 0. Input

Raw paired-end FASTQ files should be gzipped and renamed such that each sample (e.g., `sample01`) has the following files in the input directory. I recommend putting all sample descriptors as columns in your metadata file instead of the filename!

1. `sample01-r1.fq.gz`
2. `sample02-r2.fq.gz`

### 1. Align to reference

Raw FASTQ files are aligned to the previously-constructed reference using [STAR aligner](https://doi.org/10.1093/bioinformatics/bts635). All output files have the sample ID as a prefix. The alignment itself is saved to `output/sample01-Aligned.out.bam`.

| Flag                  | Meaning                                                          |
| :-------------------  | :--------------------------------------------------------------- |
| `--runThreadN`        | parallelize this job                                             |
| `--runMode`           | align reads instead of making an index                           |
| `--genomeDir`         | give the path to the genome index                                |
| `--readFilesCommand`  | the input files are gzipped                                      |
| `--outSAM*`           | compress the output and don't bother sorting the reads           |
| `--readFilesIn`       | give the path to the R1 and R2 files                             |
| `--outFileNamePrefix` | where should the output files go, and what should they be named? |

```
STAR --runThreadN 16 \
     --runMode alignReads \
     --genomeDir 'indices/genomedir' \
     --readFilesCommand zcat \
     --outSAMtype BAM Unsorted \
     --outSAMunmapped Within \
     --readFilesIn 'input/sample01-r1.fq.gz' 'input/sample01-r2.fq.gz' \
     --outFileNamePrefix 'output/sample01-'
```

### 2. Quantify aligned reads

Aligned reads in the `*-Aligned.out.bam` file are quantified using [featureCounts](https://doi.org/10.1093/bioinformatics/btt656), which is a tool in the subread module. This will output a counts matrix, which is the input for differential expression calculations.

| Flag  | Meaning                                              |
| :---  | :--------------------------------------------------- |
| `-T`  | parallelize this job                                 |
| `-M`  | count reads that align to more than one locus        |
| `-p`  | these alignments come from paired-end sequencing     |
| `-t`  | the feature type to use for quantification           |
| `-g`  | the annotation feature to use for labeling           |
| `-O`  | collapse all counts to their respective `-g` feature |
| `-a`  | the annotation GTF file                              |
| `-o`  | path and name of the output count matrix             |
| `...` | BAM alignment files                                  |

```
featureCounts -T 16 \
              -M \
              -p \
              -t FEATURE \
              -g gene_name \
              -O \
              -a 'annotatiaon.gtf' \
              -o 'output/counts.tsv' \
              'output/sample01-Aligned.out.bam' ...
```

### 3. Check input quality

The [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) tool evaluates raw read quality. Running this on each sample allow us to flag potential problematic samples before running differential expression analysis.

| Flag        | Meaning                   |
| :---------- | :------------------------ |
| `--threads` | parallelize this job      |
| `--quiet`   | minimize output           |
| `--outdir`  | output directory          |
| `...`       | one FASTQ file per sample |

```
fastqc --threads 16 \
       --quiet \
       --outdir 'data' \
       'data/sample01-r1.fq.gz' ...
```

### 4. Compile QC metrics

The [MultiQC](https://multiqc.info/) tool will compile output logs from FastQC, STAR, and featureCounts to generate a report on our entire pipeline. This will be our first stop when `pipeline.sh` finishes running -- you can see here what any problems may be before moving forward.

| Flag         | Meaning           |
| :----------- | :---------------- |
| `--quiet`    | minimize output   |
| `--outdir`   | output directory  |
| `--filename` | output HTML file  |
| `--module`   | tool output to QC |
| `...`        | input directory   |

```
multiqc --quiet \
        --outdir 'data' \
        --filename 'multiqc.html' \
        --module fastqc \
        --module star \
        --module featureCounts \
        'data'
```

