# fastqdl

Input: a txt file that contains accessions to be downloaded line by line
Output: a folder of each accession with downloaded fastq files in gzip format

# General Outline
1. Download json file from EBI
2. Parse json file for FTP links
3. Attempt downloads on FTP links
4. Check which files were downloaded and which are missing
5. Retry download on missing files
6. Success (hopefully)
