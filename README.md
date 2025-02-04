# Instructions for running the code

Folders are numbered sequentially to indicate in what order the code should be run.

## 1. Scrape all counties from 1899 to 1949

First, you will want to scrape all counties from 1899 to 1949 using a 6-month range (the maximum allowed range). There are hardly any court cases during this time period so the scraper built for this case is relatively simple compared to the later scrapers. This means it is less *robust* so to speak i.e. it cannot handle errors so well. On the other hand, it is much more light-weight and the code is less verbose. It is well-suited for the relatively simple task it has to accomplish.

## 2. Scrape all counties from 1950 to 2023 systematically changing the range from 6 months to 1 day

The workflow for scraping goes like this:

1. Run **create_search_params.R** making sure to specify: A) the browser you will be using, B) the path to the log file (the first time you run this, do not worry about this), C) the number of days you wish to search by, and D) the name you want for the table which will be created containing your search parameters. This program will output a table where each row corresponds to a specific search to be made in the PA Case Portal (i.e., a specific county + date range).

2. Run **scrape_ROAR_Collab.R** (called this because we ran it on the Penn State ROAR Collab super computing cluster). Make sure you specify: A) All the directories correctly, B) the name you want for your log file, C) the web browser you will be using, and D) the name of the **search table** containing the search terms. When you run this program, it will scrape the table of court cases as well as the links to the PDF files associated with each search term. It will also be updating the **log file** as you scrape each table (or record that the date range contains too many cases to be displayed). If the program crashes for any reason, one can simply re-run the program, and it will read the log file and continue from where it left off.

3. After the scraper completes successfully, one can run **create_search_params.R** again, but this time make sure to specify the name of the log file you want to use (usually the one which was just created). The program will look through the log file and see which search parameters were not scraped (because there were too many cases) while ignoring those search parameters which were successfully scraped. You would then usually indicate a smaller date range to search by, and the program will create a new search table for you.

4. To give an example, I will explain what we did. First, we created a search table which looked through every county 6 months at a time. Our scraper scraped every table it could, but some date ranges for some counties had too many cases to be displayed (e.g., Philadelphia from January 1, 2000 - June 1 2000). So we created a new search table, this time with a 5 month date range for those search parameters which previously failed when searched for using 6 months. We did this going all the way down to a 1 day search (e.g., Philadelphia from January 1, 2000 to January 2, 2000) gradually decreasing the date range we looked through each time.

5. Note that when running the scraper that the scraper will also generate console log .txt files so when one can try and figure out how the scraper crashed. Once the scraper completes, one can do whatever one wishes these console logs.

6. Additionally, there are some Bash shell scripts. The **run_scraper.sh** shell script was used on the Penn State ROAR Collab computing cluster to submit our programming request as a Slurm job. The **zip.sh** shell script was used to zip all the scraped tables together into one zipped file every each scrape. The name of the zipped file was changed in the script after every scrape to match the date range used.

7. Finally, one last thing to note. I have commented out the *binary* argument in the RSelenium function call. This is because it is usually not necessary when running the script on one's local computer. On the Penn State ROAR Collab computing cluster, we had to provide the path to the browser, though.

## 3. Scrape all remaining counties and date ranges using 0 days

1. So any remaining county + date ranges which were leftover had to be scraped day-by-day. There were **a lot** of county + date ranges left to be scraped this way, and it could not be done in one job request like we had normally been doing it through Slurm. Since the Penn State ROAR Collab computing cluster has a 48-hour limit on job run times, we had to split up our search table into chunks where each chunk could could be completed within two days.

2. The workflow remains largely the same. First, one would run **create_search_params.R** to create the search table. Next, there is a slight change. One would run **split_search_table.R**. This splits the search table into chunks which can be theoretically completed in 48 hours. Next, one would run the scraper **scrape_ROAR_Collab_interactive.R**. It is largely the same as **scrape_ROAR_Collab.R** with only a few key differences. The first difference is that it can extract the chunk number from the provided search table and use that chunk number for the log file and console output. The second difference is that it takes the search table and Selenium port number as runtime arguments. This change was made so we could run multiple scrapers at the same time. One could submit the scraper in separate jobs and just supply the arguments at runtime. An example is provided in **run_scraper_interactive_0.sh**.

## 4. Scrape all remaining counties and date ranges using 0 days but still had too many cases

1. In hindsight, I should have done this a bit better. The previous scrapers would assume that once you hit a date that had too many cases all subsequent dates for that county would also have too many cases. I should have changed it for the 0 day scraper. In any case, it is what it is. All remaining county + date ranges either had too many cases or were skipped in this fashion. The workflow remains largely the same, but the scraper logic has changed quite a bit. I will specify the high-level details here.

2. The first step is to run **create_search_params_too_many_cases.R**. This will take all the log files created during previous scrape of 0 days and create a new search table based on those tables which were not scraped.

3. Next, run **split_search_table.R**. This will take the search table and split it into a series of search tables which can theoretically be completed within 48 hours.

4. Finally, there is **scrape_too_many_cases_ROAR_Collab_interactive.R**. This is the new scraper to deal with county + date searches that have too many cases. We can either have too many **magisterial court cases** or too many **common plea court cases** or both. When there are too many magisterial court cases, we can systematically go through every magisterial court office in the drop-down menu and collect cases this way. However, if there are too many common plea court cases, there is nothing we can do. There is no way to further refine the search to obtain these missing cases. We just collect the table which is returned from the search. If we have too many cases of both kinds, we can still collect all the magisterial court cases but not all the common plea court cases. Much like **scrape_ROAR_Collab_interactive.R**, one can submit the scraper in a Slurm job as seen in **run_scraper_interactive_0_too_many_cases.sh**.

## 5. Scrape all remaining counties and date ranges which had too many MDJS cases

1. There were a tiny number of search entries where it was the case that there were too many cases even when we search within the date + county by MDJS. When this would happen, the scraper would skip that whole county + date. I could have had the scraper collect them (or at least collect as much as we could), but I wanted to check and see if there would be a way to collect all of the cases. As it turns out, there is no way to collect all the cases in these situations. So this is the final scraping step. First, one needs to run **create_search_params_too_many_mdjs.qmd** which will find the problematic search entries and create a search table.

2. Next, one needs to run **remove_cases.R**. This removes all tables which were collected from the problematic entries. When the scraper came across a MDJS entry that had too many cases, it skipped the rest of the MDJS offices in that county. However, those MDJS offices which came before the problematic entry were still collected. To ensure there is no redundancy, we remove these cases and will simply collect them again in the next scrape.

3. Next, one would run **zip_too_many_cases.sh**. There were so many files which needed to be zipped that using the regular tar command did not work. A new modified version of the shell script had to be created to allow for the files to be zipped.

4. Finally, one would run **scrape_too_many_mdjs_cases.R** which will collect the remaining cases from those dates + counties which had too many MDJS cases. Then, one can run **zip.sh** which will zip up the files.
   1. **NOTE**: During the scrape, for October 4 2019 for Lackawanna county, we were able to obtain every table. This means some cases must have been purged in between scrapes.

## 6. Downloading the PDFs

1. With all the tables and PDF links scraped, one needs to combine all these data tables into one table. Run **create_pdf_download_list.R** which will combine all the individual data tables.

   1. There are 313,460 data tables that were collected, and together they capture 18,736,590 cases.
   2. We drop 67,947 records because the scrape for that date range + county yielded no results (i.e., there were no recorded cases during the specific date range in the specific county). This yields 18,668,643 cases.
      1. 1. CR = Criminal, CV = Civil, JM = Juvenile Miscellaneous, LT = Landlord/Tenant, MD = Miscellaneous, NT = Non-Traffic, SA = Summary Appeal, SU = Summary, TR = Traffic.
      2. I am not sure what JV cases are. I suspect they are some sort of Juvenile case. No JV cases have download links to a PDF (meaning none of them have PDFs). Because they have no PDFs to download, they are dropped. There are only 7 JV cases. After dropping these cases, the total number of cases is 18,668,636.
   3. Using the **PA Counties Date of Digital Caseload Adoption.pdf**, we filter out cases which were filed before the counties moved to a completely digital caseload. This is because counties do not have the complete record of cases available prior to the adoption of the digital caseload system. The cases that are available digitally prior to the county adopting the digital caseload system represent only a subset of cases heard during the pre-digital time period. We do not know the criteria by which these cases were selected for migration into the digital system. Absent this domain knowledge and absent the full record of cases, there is no way to know how representative these cases are of the cases heard in the pre-digital period. As a result, we drop these cases. This leads to 3,961,349 cases being dropped which leaves us with 14,707,287 cases.
   4. Of these 14,707,287 cases, 4,070,587 correspond to criminal cases and 1,012,570 correspond to Landlord/tenant cases.
      1. Some cases have duplicate entries which is due to a quirk in the way the data is scraped from the PA website. Cases which have *calendar events* (e.g., jury trial) are listed multiple times in the search results table (albeit within different tabs in the table). We remove cases with the same docket number (which should be the unique identifier).
      2. Criminal cases --> From 4,070,587 cases to 4,046,443 cases.
      3. Landlord/tenant cases --> From 1,012,570 cases to 993,821 cases.
      4. Other cases --> From 9,624,130 cases to 9,314,573 cases.

2. The general flow for downloading PDFs goes as follows:
   1. Run **create_log_file.py** and provide two runtime arguments where the first argument is the file name of the *old log file* and the second argument will be the name of the *new log file*. If running for the first time, the second argument does not matter.
   2. Next, run **download_PDFs.py** and provide as a runtime argument the name of the log file to be used.
   3. After **download_PDFs.py** finishes running (e.g., it completes, it crashes, the server closes), run** **create_log_file.py** where the recently used log file will be the *old log file*.
   4. Iterate until all the PDFs are downloaded.
