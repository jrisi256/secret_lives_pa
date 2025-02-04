#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=8GB
#SBATCH --cpus-per-task=25
#SBATCH --time=48:00:00
#SBATCH --partition=open

module load anaconda/2023
conda activate myenv
python download_PDFs.py pdf_download_log_2025_02_04.csv 20
