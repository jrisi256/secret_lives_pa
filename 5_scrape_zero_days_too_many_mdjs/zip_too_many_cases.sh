#!/bin/bash

cd ~/work/secret_lives_pa/scrape_links/output/scraped_tables/
find . -maxdepth 1 -type f -print | tar -czvf 0_days_too_many_cases_scraped_tables.tar.gz -T -
