# Instructions for running the code

Folders are numbered sequentially to indicate in what order the code should be run.

## 1. Scrape all counties from 1899 to 1949

First, you will want to scrape all counties from 1899 to 1949 using a 6-month range (the maximum allowed range). There are hardly any court cases during this time period so the scraper built for this case is relatively simple compared to the later scrapers. This means it is less *robust* so to speak i.e. it cannot handle errors so well. On the other hand, it is much more light-weight and the code is less verbose. It is well-suited for the relatively simple task it has to accomplish.

## 2. Scrape all counties from 1950 to 2023 systematically changing the range from 6 months to 1 day

The workflow for scraping goes like this:

    1. Run **create_search_params.R** making sure to specify: A) the browser you will be using, B) the path to the log file (the first time you run this, do not worry about this), C) the number of days you wish to search by, and D) the name you want for the table which will be created containing your search parameters. This program will output a table where each row corresponds to a specific search to be made in the PA Case Portal (i.e., a specificy county + date range).
    
    2. Run **scrape_ROAR_Collab.R** (called this because we ran it on the Penn State ROAR Collab super computing cluster). Make sure you specify: A) All the directories correctly, B) the name you want for your log file, C) the web browser you will be using, and D) the name of the **search table** containing the search terms. When you run this program, it will scrape the table of court cases as well as the links to the PDF files associated with each search term. It will also be updating the **log file** as you scrape each table (or record that the date range contains too many cases to be displayed). If the program crashes for any reason, one can simply re-run the program, and it will read the log file and continue from where it left off.
    
    3. After the scraper completes successfully, one can run **create_search_params.R** again, but this time make sure to specify the name of the log file you want to use (usually the one which was just created). The program will look through the log file and see which search parameters were not scraped (because there were too many cases) while ignoring those search parameters which were successfully scraped. You would then usually indicate a smaller date range to search by, and the program will create a new search table for you.
    
    4. To give an example, I will explain what we did. First, we created a search table which looked through every county 6 months at a time. Our scraper scraped every table it could, but some date ranges for some counties had too many cases to be displayed (e.g., Philadelphia from January 1, 2000 - June 1 2000). So we created a new search table, this time with a 5 month date range for those search parameters which previously failed when searched for using 6 months. We did this going all the way down to a 1 day search (e.g., Philadelphia from January 1, 2000 to January 2, 2000) gradually decreasing the date range we looked through each time.
    
    5. Note that when running the scraper that the scraper will also generate console log .txt files so when one can try and figure out how the scraper crashed. Once the scraper completes, one can do whatever one wishes these console logs.
    
    6. Additionally, there are some Bash shell scripts. The **run_scraper.sh** shell script was used on the Penn State ROAR Collab computing cluster to submit our programming request as a Slurm job. The **zip.sh** shell script was used to zip all the scraped tables together into one zipped file every each scrape. The name of the zipped file was changed in the script after every scrape to match the date range used.

    7. Finally, one last thing to note. I have commented our the *binary* argument in the RSelenium function call. This is because it is usually not necessary when running the script on one's local computer. On the Penn State ROAR Collab computing cluster, we had to provide the path to the browser, though.

## 3. Scrape all remaining counties and date ranges using 0 days

    1. So any remaining county + date ranges which were leftover had to be scraped day-by-day. There were **a lot** of county + date ranges left to be scraped this way, and it could not be done in one job request like we had normally been doing it through Slurm. Since the Penn State ROAR Collab computing cluster has a 48-hour limit on job run times, we had to split up our search table into chunks where each chunk could could be completed within two days.

    2. The workflow remains largely the same. First, one would run **create_search_params.R** to create the search table. Next, there is a slight change. One would run **split_search_table.R**. This splits the search table into chunks which can be theoretically completed in 48 hours. Next, one would run the scraper **scrape_ROAR_Collab_interactive.R**. It is largely the same as **scrape_ROAR_Collab.R** with only a few key differences. The first difference is that it can extract the chunk number from the provided search table and use that chunk number for the log file and console output. The second difference is that it takes the search table and Selenium port number as runtime arguments. This change was made so we could run multiple scrapers at the same time. One could submit the scraper in separate jobs and just supply the arguments at runtime. An example is provided in **run_scraper_interactive_0.sh**.
