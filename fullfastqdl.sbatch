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

# Source bashrc and activate the Conda environment
source ~/.bashrc
conda activate qebil


bioproject=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$1" | xargs)
MAX_JOBS=$2


count=0
mkdir /ddn_scratch/lxxu/fastqdl/$bioproject
curl -s "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=${bioproject}&result=read_run&fields=study_accession,sample_accession,experiment_accession,run_accession,tax_id,scientific_name,fastq_ftp,submitted_ftp,sra_ftp,bam_ftp&format=json&download=true&limit=0" >  "/ddn_scratch/lxxu/fastqdl/${bioproject}/${bioproject}.json"
grep -o '"fastq_ftp":"[^"]*"' "/ddn_scratch/lxxu/fastqdl/${bioproject}/${bioproject}.json" | \
sed 's/"fastq_ftp":"//' | \
tr ';' '\n' | \
sed 's/"$//' | \
while read -r url; do
        if [ -n "$url" ]; then
                wget --tries=5 --waitretry=5 -c "ftp://$url" -P "/ddn_scratch/lxxu/fastqdl/${bioproject}" &
                ((count++))
                if ((count % MAX_JOBS == 0)); then
                        wait
                fi
        fi
done
wait

grep -o '"fastq_ftp":"[^"]*"' "/ddn_scratch/lxxu/fastqdl/${bioproject}/${bioproject}.json" | sed 's/"fastq_ftp":"//' | tr ';' '\n' | sed 's/"$//' > "/ddn_scratch/lxxu/fastqdl/${bioproject}/urls.txt"

set -euo pipefail

URL_FILE="/ddn_scratch/lxxu/fastqdl/${bioproject}/urls.txt"
DOWNLOAD_DIR="/ddn_scratch/lxxu/fastqdl/${bioproject}"
MISSING_NAMES="/ddn_scratch/lxxu/fastqdl/${bioproject}/missing_files.txt"
MISSING_URLS="/ddn_scratch/lxxu/fastqdl/${bioproject}/missing_urls.txt"
FINAL_NAMES="/ddn_scratch/lxxu/fastqdl/${bioproject}/final_missing_files.txt"

# Step 1: Extract expected filenames from FTP URLs
basename -a $(cat "$URL_FILE") | sort > "/ddn_scratch/lxxu/fastqdl/${bioproject}/expected_files.txt"

# # Step 2: List downloaded filenames
ls "$DOWNLOAD_DIR" | sort > "/ddn_scratch/lxxu/fastqdl/${bioproject}/downloaded_files.txt"

# Step 3: Find missing files
comm -23 "/ddn_scratch/lxxu/fastqdl/${bioproject}/expected_files.txt" "/ddn_scratch/lxxu/fastqdl/${bioproject}/downloaded_files.txt" > "$MISSING_NAMES"

# Step 4: Extract full missing URLs
grep -Ff "$MISSING_NAMES" "$URL_FILE" > "$MISSING_URLS"

# Step 5 (optional): Retry download of missing files
echo "Retrying download of missing files..."
cat "$MISSING_URLS" | while read -r url; do
     echo "Downloading $url"
     wget --tries=5 --waitretry=10 -c "ftp://$url" -P "$DOWNLOAD_DIR"
done

echo "Done. Missing files (if any) are listed in $MISSING_NAMES"

comm -23 "/ddn_scratch/lxxu/fastqdl/${bioproject}/expected_files.txt" "/ddn_scratch/lxxu/fastqdl/${bioproject}/downloaded_files.txt" > "$FINAL_NAMES"





