#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=8GB
#SBATCH --time=20:00:00
#SBATCH --partition=open

module load r
Rscript scrape_ROAR_Collab.R