#!/bin/bash -l

# qsub options
#$ -l h_rt=48:00:00
#$ -l mem_per_core=12G
#$ -pe omp 16
#$ -j y
#$ -o log-$JOB_NAME.qlog

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
ARGS="--runThreadN 16 --runMode genomeGenerate --limitGenomeGenerateRAM 200000000000"
HELP="usage: qsub -P PROJECT -N JOBNAME $(basename "$0") -g GTF -f FASTA -o OUTPUT -x FEATURE

arguments (options):
  -g genome GTF file
  -f genome FASTA file
  -o output directory
  -x feature for alignments (transcript|exon)
  -h show this message and exit"

# parsing arguments
while getopts ":hg:f:o:x:" opt
do
  case ${opt} in
    g ) GTF="${OPTARG}"
      ;;
    f ) FASTA="${OPTARG}"
      ;;
    o ) OUTDIR="${OPTARG}"
      ;;
    x ) FEAT="${OPTARG}"
      ;;
    h ) echo "${HELP}" && exit 0
      ;;
    \? ) err "Invalid option ${opt}\n${HELP}"
      ;;
  esac
done
shift $((OPTIND -1))

## print job info for output log --------------------------------
echo "=========================================================="
echo "Start date: $(date)"
echo "Running on node: $(hostname)"
echo "Current directory: $(pwd)"
echo "Job name : $JOB_NAME"
echo "Job ID : $JOB_ID"
echo "=========================================================="
echo ""

## check inputs -------------------------------------------------
mesg "STEP 0: CHECKING INPUTS"

# genome GTF file
if [ -z "$GTF" ]
then
  err "No genome GTF file provided"
elif [ -f "$GTF" ]
then
  mesg "Valid GTF file: $GTF"
else
  err "Invalid GTF file: $GTF"
fi

# genome FASTA file
if [ -z "$FASTA" ]
then
  err "No genome FASTA file provided"
elif [ -f "$FASTA" ]
then
  mesg "Valid genome FASTA file: $FASTA"
else
  err "Invalid genome FASTA file: $FASTA"
fi

# output directory
if [ -z "$OUTDIR" ]
then
  err "No output directory provided"
elif [ -d "$OUTDIR" ]
then 
  mesg "Valid output directory: $OUTDIR"
else
  mesg "Creating output directory: $OUTDIR"
  mkdir -p "$OUTDIR"
fi

# alignment feature
if [ -z "$FEAT" ]
then
  err "No index feature provided"
elif [ "$FEAT" = "transcript" ]
then
  mesg "Valid index feature: $FEAT"
elif [ "$FEAT" = "exon" ]
then
  mesg "Valid index feature: $FEAT"
else
  err "Invalid index feature: $FEAT"
fi

# done checking inputs!
mesg "Done checking inputs!"
echo ""

## STAR index loop ----------------------------------------------
mesg "STEP 1: CREATE STAR INDEX"

# load STAR
module load star/2.7.1a

# build command
CMD="STAR $ARGS --genomeDir '$OUTDIR' --outFileNamePrefix '$OUTDIR' --sjdbGTFfile '$GTF' --genomeFastaFiles '$FASTA' --sjdbGTFfeatureExon $FEAT"
mesg "CMD: ${CMD}"
eval "${CMD}"
checkcmd "STAR index"
echo ""

## print package versions ---------------------------------------
mesg "FIN. INDEX CREATED SUCCESSFULLY."
module list
echo ""
