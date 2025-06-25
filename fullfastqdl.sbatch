#!/bin/bash -l
#SBATCH --job-name=luisfull
#SBATCH --output=/home/lxxu/logs/%x-%j.out
#SBATCH --error=/home/lxxu/logs/%x-%j.err
#SBATCH --mail-type=ALL
#SBATCH --mail-user=lxxu@ucsd.edu
#SBATCH --time=24:00:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=1
#SBATCH --array=1-6%3

# initialize bash
source ~/.bashrc

# grab bioproject id from file using slurm array number
bioproject=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$1" | xargs)

# number of samples to be downloaded at the same time
MAX_JOBS=$2

# initialize count to see how many files are being downloaded
count=0

# create new directory and download json file using link template from ebi
mkdir /ddn_scratch/lxxu/fastqdl/$bioproject
curl -s "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=${bioproject}&result=read_run&fields=study_accession,sample_accession,experiment_accession,run_accession,tax_id,scientific_name,fastq_ftp,submitted_ftp,sra_ftp,bam_ftp&format=json&download=true&limit=0" >  "/ddn_scratch/lxxu/fastqdl/${bioproject}/${bioproject}.json"

# parse json file and gets ftp link
grep -o '"fastq_ftp":"[^"]*"' "/ddn_scratch/lxxu/fastqdl/${bioproject}/${bioproject}.json" | \
sed 's/"fastq_ftp":"//' | \
tr ';' '\n' | \
sed 's/"$//' | \

# reads through all ftp links and attempts to download
while read -r url; do
        if [ -n "$url" ]; then
                # tries download and runs it in the background
                wget --tries=5 --waitretry=5 -c "ftp://$url" -P "/ddn_scratch/lxxu/fastqdl/${bioproject}" &
                ((count++))
                # if number of downloads reaches max samples to download at the same time, waits until all are completed
                if ((count % MAX_JOBS == 0)); then
                        wait
                fi
        fi
done
wait

# same json parsing from before but redirects to file
grep -o '"fastq_ftp":"[^"]*"' "/ddn_scratch/lxxu/fastqdl/${bioproject}/${bioproject}.json" | sed 's/"fastq_ftp":"//' | tr ';' '\n' | sed 's/"$//' > "/ddn_scratch/lxxu/fastqdl/${bioproject}/urls.txt"

# filepaths for new files
URL_FILE="/ddn_scratch/lxxu/fastqdl/${bioproject}/urls.txt"
DOWNLOAD_DIR="/ddn_scratch/lxxu/fastqdl/${bioproject}"
MISSING_NAMES="/ddn_scratch/lxxu/fastqdl/${bioproject}/missing_files.txt"
MISSING_URLS="/ddn_scratch/lxxu/fastqdl/${bioproject}/missing_urls.txt"
FINAL_NAMES="/ddn_scratch/lxxu/fastqdl/${bioproject}/final_missing_files.txt"

# get filenames from url file
basename -a $(cat "$URL_FILE") | sort > "/ddn_scratch/lxxu/fastqdl/${bioproject}/expected_files.txt"

# find files that were downloaded
ls "$DOWNLOAD_DIR" | sort > "/ddn_scratch/lxxu/fastqdl/${bioproject}/downloaded_files.txt"

# find missing files from what was expected
comm -23 "/ddn_scratch/lxxu/fastqdl/${bioproject}/expected_files.txt" "/ddn_scratch/lxxu/fastqdl/${bioproject}/downloaded_files.txt" > "$MISSING_NAMES"

# get the ftp links from files
grep -Ff "$MISSING_NAMES" "$URL_FILE" > "$MISSING_URLS"

# retry download on missing files
cat "$MISSING_URLS" | while read -r url; do
     wget --tries=5 --waitretry=10 -c "ftp://$url" -P "$DOWNLOAD_DIR"
done

# lists any remaining files
comm -23 "/ddn_scratch/lxxu/fastqdl/${bioproject}/expected_files.txt" "/ddn_scratch/lxxu/fastqdl/${bioproject}/downloaded_files.txt" > "$FINAL_NAMES"





