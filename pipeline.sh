#!/bin/bash -l

# qsub options
#$ -P lasvchal
#$ -l h_rt=48:00:00
#$ -l mem_per_core=12G
#$ -pe omp 16
#$ -j y
#$ -o log-$JOB_NAME.qlog

# job info
echo "=========================================================="
echo "Start date: $(date)"
echo "Running on node: $(hostname)"
echo "Current directory: $(pwd)"
echo "Job name: $JOB_NAME"
echo "Job ID: $JOB_ID"
echo "Task ID: $SGE_TASK_ID"
echo "=========================================================="
echo ""

## setup --------------------------------------------------------
# functions
mesg () { echo -e "[MSG] $@"; }
err () { echo -e "[ERR] $@"; exit 1; }
checkcmd () {
  if [ $? -eq 0 ]
  then
    mesg "$@ succeeded"
  else
    err "$@ failed"
  fi
}

# default values and help message
INDEX="star-hsapiens-kikwit-transcript"
GTF="genome/hsapiens-kikwit.gtf"
HELP="usage: qsub -N JOBNAME $(basename "$0") [OPTIONS] INDIR ODIR 

positional arguments:
  INDIR input directory with FASTQ files (*-r1/2.fq.gz)
  ODIR  output directory

options (default):
  -i path to STAR index ($INDEX)
  -g path to GTF annotation ($GTF)
  -h show this message and exit
"

# parsing arguments
while getopts ":hi:g:" opt 
do 
  case ${opt} in 
    i ) INDEX="${OPTARG}"
      ;;
    g ) GTF="${OPTARG}"
      ;;
    h ) echo "${HELP}" && exit 0
      ;;
    \? ) err "Invalid option ${opt}\n${HELP}"
      ;;
  esac
done
shift $((OPTIND -1))

# set input and output paths
INDIR="$1"
ODIR="$2"

## check inputs -------------------------------------------------
mesg "STEP 0: CHECKING INPUTS"

# input directory
if [ -z "$INDIR" ]
then
  err "No input directory provided"
elif [ -d "$INDIR" ]
then
  mesg "Valid input directory: $INDIR"
else
  mesg "Invalid input directory: $INDIR"
fi

# output directory
if [ -z "$ODIR" ]
then
  err "No output directory provided"
elif [ -d "$ODIR" ]
then
  mesg "Valid output directory: $ODIR"
else
  mesg "Creating output directory: $ODIR"
  mkdir -p "$ODIR"
fi

# index directory
if [ -d "$INDEX" ]
then
  mesg "Valid index directory: $INDEX"
else
  err "Index directory not found: $INDEX"
fi

# GTF file 
if [ -f "$GTF" ]
then
  mesg "Valid GTF file: $GTF"
else
  err "GTF file not found: $GTF"
fi

# get sample IDs
mesg "Extracting sample IDs:"
IDS=""
for i in $(ls -1 ${INDIR}/*-r1.fq.gz)
do
  IDS="$IDS $(basename $i -r1.fq.gz)"
  echo "      $(basename $i -r1.fq.gz)"
done
# double check there are actually FASTQ files
if [ -z "$IDS" ]
then
  err "No sample IDs found in input directory"
fi
echo ""

## STAR alignment loop ------------------------------------------
mesg "STEP 1: ALIGNMENT WITH STAR"

# load STAR
module load star/2.7.1a

# set up arguments
BASE="STAR --runThreadN 16 --runMode alignReads --genomeDir '$INDEX' --readFilesCommand zcat --outSAMtype BAM Unsorted --outSAMunmapped Within" 

# loop through samples
mesg "Beginning alignment loop through $(echo $IDS | wc -w) samples..."
echo ""
for i in $IDS
do
  mesg "Aligning sample: $i"
  R1="${INDIR}/${i}-r1.fq.gz"
  R2="${INDIR}/${i}-r2.fq.gz"
  PRE="${ODIR}/${i}-"
  CMD="$BASE --readFilesIn '$R1' '$R2' --outFileNamePrefix '$PRE'"
  mesg "CMD: $CMD"
  eval "$CMD"
  checkcmd "Alignment for $i"
  echo ""
done

mesg "Exiting alignment loop."

## quantify alignments ------------------------------------------
mesg "STEP 2: QUANTIFICATION WITH FEATURECOUNTS"

# load featureCounts
module load subread/1.6.2
featureCounts -v

# make list of BAMs
BAMS=""
for i in $IDS
do
  BAMS="$BAMS '${ODIR}/${i}-Aligned.out.bam'"
done

# set up command
mesg "Writing counts to ${ODIR}/counts.tsv"
CMD="featureCounts -T 16 -O -M -p -t exon -g gene_name -a '$GTF' -o '${ODIR}/counts.tsv' $BAMS"
mesg "CMD: $CMD"
eval "$CMD"
checkcmd "featureCounts"
echo ""

## final QC -----------------------------------------------------
mesg "STEP 3: QUALITY CHECK"

# FastQC on input FASTQ R1 files
mesg "FastQC on input FASTQ R1 files"
module load fastqc
FQ=""
for i in $IDS
do
  FQ="$FQ '${INDIR}/${i}-r1.fq.gz'"
done
CMD="fastqc --threads 16 --quiet --outdir '$ODIR' $FQ"
mesg "CMD: $CMD"
eval "$CMD"
checkcmd "FastQC"
echo ""

# MultiQC on FastQC, STAR, and featureCounts
mesg "MultiQC on FastQC, STAR,and featureCounts output"
module load python3/3.7.9
module load multiqc/1.10.1
CMD="multiqc --quiet --outdir '$ODIR' --filename 'multiqc.html' --module fastqc --module star --module featureCounts '$ODIR'" 
mesg "CMD: $CMD"
eval "$CMD"
checkcmd "MultiQC"
echo ""

## print package versions ---------------------------------------
mesg "FIN. PIPELINE COMPLETED SUCCESSFULLY."
module list
echo ""

