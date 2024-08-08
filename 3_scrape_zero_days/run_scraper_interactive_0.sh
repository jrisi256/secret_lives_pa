#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=8GB
#SBATCH --time=48:00:00
#SBATCH --partition=open

module load r
Rscript scrape_ROAR_Collab_interactive.R all_counties_0_days_part_0.csv 4545
