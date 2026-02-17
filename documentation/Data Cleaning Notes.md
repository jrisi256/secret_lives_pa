# Data Cleaning Notes

* The methodology for determining each individual's prior record score [can be found here](https://www.pacodeandbulletin.gov/Display/pacode?file=/secure/pacode/data/204/chapter303/s303.15.html&d=reduce).

## Blair County, January 10th 2017

* What happened was that for 26 cases (more were affected but the cases swapped were not criminal or landlord/tenant cases), the download links got swapped. So the download link for case 1 was case 2, and the download link for case 2 was case 1. As a result, the cases got mislabeled.
* I cannot find the origin of this error, unfortunately. Either our web scraper made a mistake, or the website itself had a mistake. Many of the MJ court cases are no longer publicly available so it cannot be verified what download link they had.
* If you investigate the **criminal_cases.rds** output file, you'll see each file has has the download links swapped.
* If you investigate the **Blair_2017-01-10_2017-01-10.csv** in scraped tables, you will also see the download links swapped there, as well.
* If you investigate the website now (looking at Blair County on January 10th, 2017), the links are correct.
* I usually am against manually changing things, but in this case, I see no better option. What I did for each PDF file...
  1. MJ-24304-TR-0000013-2017 is really CP-07-CR-0000047-2017 (and vice versa).
     1. MJ-24304-TR-0000013-2017 (with the CP-07-CR-0000047-2017 link) was never downloaded because we did not download traffic PDFs.
     2. The download link for MJ-24304-TR-0000013-2017 did not work at the time of download therefore CP-07-CR-0000047-2017 does not exist. I download the correct files manually, and add them to the chunk lists.
  2. MJ-24302-NT-0000023-2017 is really CP-07-CR-0000048-2017 (and vice versa).
     1. MJ-24302-NT-0000023-2017 (with the CP-07-CR-0000048-2017 link) was never downloaded because we did not download non-traffic PDFs.
     2. I delete the file called CP-07-CR-0000048-2017 as it is really MJ-24302-NT-0000023-2017. I then download the correct files manually.
  3. MJ-24302-CV-0000011-2017 is really CP-07-CR-0000049-2017 (and vice versa).
     1. MJ-24302-CV-0000011-2017 (with the CP-07-CR-0000049-2017 link) was never downloaded because we did not download civil PDFs.
     2. I delete the file called CP-07-CR-0000049-2017 as it is really MJ-24302-CV-0000011-2017. I then download the correct files manually.
  4. MJ-24302-CV-0000010-2017 is really CP-07-CR-0000050-2017 (and vice versa).
     1. MJ-24302-CV-0000010-2017 (with the CP-07-CR-0000050-2017 link) was never downloaded because we did not download civil PDFs.
     2. I delete the file called CP-07-CR-0000050-2017 as it is really MJ-24302-CV-0000010-2017. I then download the correct files manually.
  5. MJ-24302-CR-0000008-2017 is really CP-07-CR-0000051-2017 (and vice versa).
     1. I rename MJ-24302-CR-0000008-2017 to CP-07-CR-0000051-2017, and add the files to the chunk lists.
     2. MJ-24302-CR-0000008-2017 was removed from public view. I remove the files from the chunk lists.
  6. MJ-24302-CR-0000007-2017 is really CP-07-CR-0000052-2017 (and vice versa).
     1. I rename MJ-24302-CR-0000007-2017 to CP-07-CR-0000052-2017.
     2. I rename CP-07-CR-0000052-2017 to MJ-24302-CR-0000007-2017.
  7. MJ-24302-CR-0000006-2017 is really CP-07-CR-0000053-2017 (and vice versa).
     1. I rename MJ-24302-CR-0000006-2017 to CP-07-CR-0000053-2017.
     2. I rename CP-07-CR-0000053-2017 to MJ-24302-CR-0000006-2017.
  8. MJ-24302-CR-0000005-2017 is really CP-07-CR-0000054-2017 (and vice versa).
     1. I rename MJ-24302-CR-0000005-2017 to CP-07-CR-0000054-2017.
     2. I rename CP-07-CR-0000054-2017 to MJ-24302-CR-0000005-2017.
  9. MJ-24301-TR-0000017-2017 is really CP-07-CR-0000055-2017 (and vice versa).
      1. MJ-24301-TR-0000017-2017 (with the CP-07-CR-0000055-2017 link) was never downloaded because we did not download traffic PDFs.
      2. The download link for MJ-24301-TR-0000017-2017 did not work at the time of download therefore CP-07-CR-0000055-2017 does not exist. I download the correct files manually, and add them to the chunk lists.
  10. MJ-24301-CR-0000007-2017 is really CP-07-MD-0000122-2017 (and vice versa).
      1. I delete the file called MJ-24301-CR-0000007-2017 as it is really CP-07-MD-0000122-2017. I then download the correct files manually.
      2. CP-07-MD-0000122-2017 (with the MJ-24301-CR-0000007-2017 link) was never downloaded because we did not download Miscellaneous PDFs.
  11. MJ-24103-TR-0000030-2017 is really MJ-24102-CR-0000015-2017 (and vice versa).
      1. MJ-24103-TR-0000030-2017 (with the MJ-24102-CR-0000015-2017 link) was never downloaded because we did not download traffic PDFs.
      2. The download link for MJ-24103-TR-0000030-2017 did not work at the time of download therefore MJ-24102-CR-0000015-2017 does not exist. I download the correct files manually, and them to the chunk lists.
  12. MJ-24103-TR-0000029-2017 is really MJ-24102-CR-0000018-2017 (and vice versa).
      1. MJ-24103-TR-0000029-2017 (with the MJ-24102-CR-0000018-2017 link) was never downloaded because we did not download traffic PDFs.
      2. The download link for MJ-24103-TR-0000029-2017 did not work at the time of download therefore MJ-24102-CR-0000018-2017 does not exist. I download the correct files manually, and them to the chunk lists.
  13. MJ-24103-CR-0000010-2017 is really MJ-24102-NT-0000054-2017 (and vice versa).
      1. The download link for MJ-24102-NT-0000054-2017 did not work at the time of download therefore MJ-24103-CR-0000010-2017 does not exist. I download the correct files manually, and them to the chunk lists.
      2. MJ-24102-NT-0000054-2017 (with the MJ-24103-CR-0000010-2017 link) was never downloaded because we did not download non-traffic PDFs.

## Blair County, March 6th 2017

1. MJ-24304-TR-0000246-2017 is really MJ-24102-CR-0000089-2017 (and vice versa).
   1. Downloaded MJ-24102-CR-0000089-2017.
   2. Added MJ-24102-CR-0000089-2017 to chunk list. Manually parsed court summary.
2. MJ-24304-TR-0000245-2017 is really MJ-24102-CR-0000096-2017 (and vice versa).
   1. Downloaded MJ-24102-CR-0000096-2017.
   2. Added MJ-24102-CR-0000096-2017 to chunk list. Manually parsed court summary.
3. MJ-24304-TR-0000244-2017 is really MJ-24102-CR-0000097-2017 (and vice versa).
   1. Downloaded MJ-24102-CR-0000097-2017.
   2. Added MJ-24102-CR-0000097-2017 to chunk list. Manually parsed court summary.
4. MJ-24304-LT-0000004-2017 is really MJ-24102-TR-0000249-2017 (and vice versa).
   1. MJ-24304-LT-0000004-2017 is no longer publicly available.
5. MJ-24304-CR-0000070-2017 is really MJ-24103-CR-0000126-2017 (and vice versa).
   1. MJ-24304-CR-0000070-2017 is not publicly available.
   2. I rename the fake MJ-24304-CR-0000070-2017 PDF and JSON files to MJ-24103-CR-0000126-2017 (as well as within the chunk lists).
6. MJ-24304-CR-0000067-2017 is really MJ-24103-CV-0000032-2017 (and vice versa).
   1. MJ-24304-CR-0000067-2017 is not publicly available. I remove it from all chunk lists, and I remove all the erroneous PDF and JSON files.
7. MJ-24304-CR-0000066-2017 is really MJ-24103-CV-0000033-2017 (and vice versa).
   1. MJ-24304-CR-0000066-2017 is not publicly available. I remove it from all chunk lists, and I remove all the erroneous PDF and JSON files.
8. MJ-24303-CR-0000052-2017 is really MJ-24301-CR-0000131-2017 (and vice versa).
   1. MJ-24303-CR-0000052-2017 is not publicly available.
   2. I rename the fake MJ-24303-CR-0000052-2017 PDF and JSON files to MJ-24301-CR-0000131-2017 (as well as within the chunk lists).
9. MJ-24302-CR-0000120-2017 is really MJ-24301-CV-0000026-2017 (and vice versa).
   1. MJ-24302-CR-0000120-2017 is not publicly available. I remove the fake version from all chunk lists, and I remove all the erroneous PDF and JSON files.
10. MJ-24302-CR-0000119-2017 is really MJ-24301-LT-0000012-2017 (and vice versa).
    1. MJ-24302-CR-0000119-2017 is not publicly available. I remove the fake version from all chunk lists, and I remove all the erroneous PDF and JSON files.
11. MJ-24301-TR-0000230-2017 is really MJ-24301-LT-0000013-2017 (and vice versa).
    1. Downloaded MJ-24301-LT-0000013-2017.
    2. Added MJ-24301-LT-0000013-2017 to chunk lists.

## Erie County, April 26th - 28th 2019

The same thing happened for Erie county for the above dates.

1. MJ-06308-TR-0000646-2019 is really CP-25-CR-0001133-2019 (and vice versa).
   1. Downloaded CP-25-CR-0001133-2019.
   2. Added CP-25-CR-0001133-2019 to chunk lists.
2. MJ-06308-TR-0000645-2019 is really CP-25-CR-0001134-2019 (and vice versa).
   1. Downloaded CP-25-CR-0001134-2019.
   2. Added CP-25-CR-0001134-2019 to chunk lists.
3. MJ-06308-TR-0000644-2019 is really CP-25-CR-0001135-2019 (and vice versa).
   1. Downloaded CP-25-CR-0001135-2019.
   2. Added CP-25-CR-0001135-2019 to chunk lists.
4. MJ-06308-NT-0000143-2019 is really CP-25-CR-0001136-2019 (and vice versa).
   1. Removed fake CP-25-CR-0001136-2019.
   2. Downloaded real CP-25-CR-0001136-2019.
5. MJ-06308-NT-0000140-2019 is really CP-25-CR-0001137-2019 (and vice versa).
   1. Removed fake CP-25-CR-0001137-2019.
   2. Downloaded real CP-25-CR-0001137-2019.
6. MJ-06308-CR-0000140-2019 is really CP-25-CR-0001138-2019 (and vice versa).
   1. Renamed files to their correct names.
7. MJ-06308-CR-0000139-2019 is really CP-25-CR-0001139-2019 (and vice versa).
   1. Renamed MJ-06308-CR-0000139-2019 to CP-25-CR-0001139-2019. Its files are added to the chunk lists.
   2. The download link for MJ-06308-CR-0000139-2019 was not publicly available at the time of download. Its files are removed from the chunk lists.
8. MJ-06308-CR-0000138-2019 is really CP-25-CR-0001142-2019 (and vice versa).
   1. Renamed files to their correct names.
9. MJ-06306-TR-0001447-2019 is really CP-25-CR-0001143-2019 (and vice versa).
   1. Downloaded CP-25-CR-0001143-2019.
   2. Added CP-25-CR-0001143-2019 to chunk lists.
10. MJ-06306-TR-0001446-2019 is really CP-25-CR-0001144-2019 (and vice versa).
    1. Downloaded CP-25-CR-0001144-2019.
    2. Added CP-25-CR-0001144-2019 to chunk lists.
11. MJ-06306-TR-0001445-2019 is really CP-25-CR-0001146-2019 (and vice versa).
    1. CP-25-CR-0001146-2019 is no longer publicly available.
12. MJ-06306-TR-0001444-2019 is really CP-25-CR-0001148-2019 (and vice versa).
    1. Downloaded CP-25-CR-0001148-2019.
    2. Added CP-25-CR-0001148-2019 to chunk lists.
13. MJ-06306-TR-0001443-2019 is really CP-25-CR-0001149-2019 (and vice versa).
    1. Downloaded CP-25-CR-0001149-2019.
    2. Added CP-25-CR-0001149-2019 to chunk lists.
14. MJ-06306-TR-0001438-2019 is really MJ-06102-CR-0000160-2019 (and vice versa).
    1. Downloaded MJ-06102-CR-0000160-2019.
    2. Added MJ-06102-CR-0000160-2019 to chunk lists.
15. MJ-06306-TR-0001437-2019 is really MJ-06102-LT-0000124-2019 (and vice versa).
    1. Downloaded MJ-06102-LT-0000124-2019.
    2. Added MJ-06102-LT-0000124-2019 to chunk lists.
16. MJ-06306-TR-0001436-2019 is really MJ-06102-LT-0000125-2019 (and vice versa).
    1. Downloaded MJ-06102-LT-0000125-2019.
    2. Added MJ-06102-LT-0000125-2019 to chunk lists.
17. MJ-06306-TR-0001432-2019 is really MJ-06103-CR-0000160-2019 (and vice versa).
    1. Downloaded MJ-06103-CR-0000160-2019.
    2. Added MJ-06103-CR-0000160-2019 to chunk lists.
18. MJ-06306-TR-0001431-2019 is really MJ-06103-LT-0000165-2019 (and vice versa).
    1. Downloaded MJ-06103-LT-0000165-2019.
    2. Added MJ-06103-LT-0000165-2019 to chunk lists.
19. MJ-06306-TR-0001430-2019 is really MJ-06103-LT-0000166-2019 (and vice versa).
    1. Downloaded MJ-06103-LT-0000166-2019.
    2. Added MJ-06103-LT-0000166-2019 to chunk lists.
20. MJ-06306-TR-0001429-2019 is really MJ-06103-LT-0000167-2019 (and vice versa).
    1. Downloaded MJ-06103-LT-0000167-2019.
    2. Added MJ-06103-LT-0000167-2019 to chunk lists.
21. MJ-06306-NT-0000127-2019 is really MJ-06103-LT-0000168-2019 (and vice versa).
    1. Downloaded MJ-06103-LT-0000168-2019.
    2. Added MJ-06103-LT-0000168-2019 to chunk lists.
22. MJ-06306-CR-0000132-2019 is really MJ-06103-TR-0000319-2019 (and vice versa).
    1. Downloaded MJ-06306-CR-0000132-2019.
    2. Added MJ-06306-CR-0000132-2019 to chunk lists.
23. MJ-06306-CR-0000131-2019 is really MJ-06103-TR-0000320-2019 (and vice versa).
    1. Downloaded MJ-06306-CR-0000131-2019.
    2. Added MJ-06306-CR-0000131-2019 to chunk lists.
24. MJ-06305-TR-0000543-2019 is really MJ-06104-CR-0000226-2019 (and vice versa).
    1. Downloaded MJ-06104-CR-0000226-2019.
    2. Added MJ-06104-CR-0000226-2019 to chunk lists.
25. MJ-06305-TR-0000542-2019 is really MJ-06104-CR-0000227-2019 (and vice versa).
    1. Downloaded MJ-06104-CR-0000227-2019.
    2. Added MJ-06104-CR-0000227-2019 to chunk lists.
26. MJ-06305-TR-0000540-2019 is really MJ-06104-CR-0000228-2019 (and vice versa).
    1. Downloaded MJ-06104-CR-0000228-2019.
    2. Added MJ-06104-CR-0000228-2019 to chunk lists.
27. MJ-06305-TR-0000537-2019 is really MJ-06104-CR-0000232-2019 (and vice versa).
    1. Downloaded MJ-06104-CR-0000232-2019.
    2. Added MJ-06104-CR-0000232-2019 to chunk lists.
28. MJ-06305-TR-0000532-2019 is really MJ-06105-LT-0000092-2019 (and vice versa).
    1. Removed fake MJ-06105-LT-0000092-2019.
    2. Downloaded real MJ-06105-LT-0000092-2019.
29. MJ-06305-CR-0000136-2019 is really MJ-06202-TR-0000675-2019 (and vice versa).
    1. Downloaded MJ-06305-CR-0000136-2019.
    2. Added MJ-06305-CR-0000136-2019 to chunk lists.
30. MJ-06303-TR-0000404-2019 is really MJ-06204-LT-0000015-2019 (and vice versa).
    1. Downloaded MJ-06204-LT-0000015-2019.
    2. Added MJ-06204-LT-0000015-2019 to chunk lists.
31. MJ-06303-NT-0000192-2019 is really MJ-06301-CR-0000140-2019 (and vice versa).
    1. Downloaded MJ-06301-CR-0000140-2019.
    2. Added MJ-06301-CR-0000140-2019 to chunk lists.
32. MJ-06303-NT-0000152-2019 is really MJ-06301-CR-0000141-2019 (and vice versa).
    1. MJ-06301-CR-0000141-2019 is no longer publicly available.
33. MJ-06303-LT-0000030-2019 is really MJ-06301-LT-0000046-2019 (and vice versa).
    1. Renamed files to their correct names.
34. MJ-06303-CR-0000105-2019 is really MJ-06301-NT-0000162-2019 (and vice versa).
    1. Removed fake MJ-06303-CR-0000105-2019.
    2. MJ-06303-CR-0000105-2019 is no longer publicly available.
    3. Removed files from chunk lists.
35. MJ-06303-CR-0000101-2019 is really MJ-06301-NT-0000176-2019 (and vice versa).
    1. MJ-06303-CR-0000101-2019 is no longer publicly available.
36. MJ-06303-CR-0000100-2019 is really MJ-06301-NT-0000177-2019 (and vice versa).
    1. Removed fake MJ-06303-CR-0000100-2019.
    2. Downloaded real MJ-06303-CR-0000100-2019.
37. MJ-06303-CR-0000099-2019 is really MJ-06301-TR-0000622-2019 (and vice versa).
    1. Downloaded MJ-06303-CR-0000099-2019.
    2. Added MJ-06303-CR-0000099-2019 to chunk lists.
38. MJ-06302-CR-0000081-2019 is really MJ-06301-TR-0000624-2019 (and vice versa).
    1. Removed fake MJ-06302-CR-0000081-2019.
    2. Downloaded real MJ-06302-CR-0000081-2019.
39. MJ-06302-CR-0000080-2019 is really MJ-06301-TR-0000625-2019 (and vice versa).
    1. Removed fake MJ-06302-CR-0000080-2019.
    2. Downloaded real MJ-06302-CR-0000080-2019.