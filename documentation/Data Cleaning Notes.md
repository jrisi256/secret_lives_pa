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

## Linking lawyers to supreme court numbers

The following lawyer were not able to be linked to a supreme court number. In some cases when an office is listed, there would be instances in which a supreme court number was also listed. In those cases, we are able to keep that entry.

* , p.c. daffner & associates, esq.
* ., esq.
* adshead, llp hughes,kalkbrenner &, esq.
* allegheny county district attorney's office
* allegheny county public defenders office
* ann johns, esq. --> Could be Anne Naomi John as they appear on the same docket, but I cannot know for certain.
* aul kov. public defender p, esq. and paul kov. public defender, esq. --> Paul John Kovatch or Richard Paul Kovacs? Likely Kovatch? Can't be sure.
* beaver county district attorney's office
* bedford county district attorney's office
* berks county district attorney, esq.
* blair county district attorney's office
* blair county public defenders office
* boyd & karver, esq.
* brian atty. jones, esq. --> Unclear which Brian Jones this could be.
* bucks county public defenders office
* c defender dauphin county publi, esq.
* c defenders dauphin county publi, esq.
* c walfish & noonan, ll, esq.
* cambria county district attorney's office
* cambria county public defenders office
* carluccio, esq. --> Unclear if this is Thomas or Carolyn Carluccio.
* centre county district attorney's office
* centre county public defenders office
* chester county district attorney's office
* chris hoffman, esq. and christopher hoffman, esq. --> Unclear if they are Christopher M. Hoffman or Paul Christopher Hoffman.
* christopher parisi, esq. --> They could be Chris S. or Chris E. We cannot tell.
* clark & mcgill, p.c, esq.
* clint kelley, esq. --> The closest match is Gregory Clinton Kelley, but I can't be certain these are the same person.
* da's office, esq.
* dan regan, esq. --> We think he is different from Daniel Donahue, but we are not sure.
* dauphin county district attorney
* dauphin county district attorney's office
* dauphin county public defenders office",
* david sharger, esq. --> They could be David S. or David J. There is no way to tell.
* david walker, esq. --> There are too many potential David Walker's to identify which one this one is.
* deactivated, esq.
* defender public, esq.
* delaware county public defenders office
* dennis blackwell, esq. --> They could be junior or senior (both work at the same location).
* district attorney, esq.
* district atty, esq.
* donald turner, esq. --> They could be Donald Charles Turner or Donald N. Turner.
* edward smith, esq. --> There are too many potential Edward Smith's to identify which one this one is.
* eric hoffmann, esq. --> They could be Eric D. or just Eric.
* erie county district attorney's office
* erie county public defenders office
* ernest sharif, esq. and ernest shariff, esq. --> They could be Ernest H. or just Ernest.
* fice public defender's of, esq.
* haff, esq.
* heather kelley, esq. --> They could be Heather Kelly, Heather Anne, or Heather Zink.
* ice public defenders off, esq.
* ict attorney dauphin county distr, esq.
* jack dwyer, esq. --> They could be John Dwyer.
* joe williams, esq. and joseph williams, esq. --> There are too many potential Joe Williams's to identify which one this one is.
* atty. lee rothman, esq., lee atty. rothman, esq., and lee rothman, esq. --> They could be Lee M. or Lee G.
* law care, esq.
* mauger & meter, esq.
* montgomery county district attorney's office
* montgomery county public defenders office
* pd's office, esq.
* public def, esq.; public defender
* public defender, esq.
* public defenders, esq.
* s newman and associate, esq.
* soc. keenan,ciccitto & as, esq.
* sociates keenan ciccitto & as, esq.
* urer dauphin county treas, esq.
* ralph frank --> Could be Frank W. Ralph or their own person. They remain blank
* rhin, esq. --> Uncertain if this is a unique person or not.

### Lawyers given a unique supreme court number by us

The following lawyers did not have a supreme court number, but we decided to give them one.

1. r.emmett madden, esq. --> 000002
2. adam hobaugh, esq. --> 000006
3. alexndria kramer --> 000001
4. alyssa john, esq. --> 000007
5. amanda chesar --> 000008
6. anthony beeraro, esq. --> 000010
7. anthony borello, esq. --> 000011
8. anthony moses --> 000012
9. barb swartz, esq. --> 000013
10. bob heyward, esq. --> 000014
11. brad breslin, esq. --> 000015
12. cassie vasicak --> 000016
13. charles fidel, esq. --> 000017
14. daniel n. schwartz, esq. --> 000018
15. david campbell, esq. --> 000019
16. donald minahan, esq. --> 000020
17. duke morris, esq." ~ "000021
18. erica burry --> 000022
19. fincourt b. shelton, esq. --> 000023
20. foley law offices of jerry, esq. --> 000024
21. francis a. mccormick --> 000025
22. gail marr-williams --> 000026
23. glenn j. smith --> 000027
24. greg mcfarland, esq. --> 000028
25. name == "hart hillman, esq. --> 000030
26. hary chestnut, vernon zac, esq. --> 000009
27. james black, esq. --> 000031
28. jean trenbeath --> 000032
29. jerry atty. sklavounakis, esq. --> 000000
30. jerry johnson, esq. --> 000033
31. jesse juilante, esq. --> 000034
32. john burt, esq. --> 000035
33. john mccall, esq. --> 000036
34. john n. salla --> 000037
35. john noonan, esq. --> 000039
36. matt dugan, esq. + matt dugan, esq. --> 900001
37. michael yoder, esq. + michael yoder-pd, esq. --> 900002
38. mark r. falconi --> 900004
39. mackenzie iocona --> 900005
40. ray gricar --> 900007
41. richard p. gilmore, esq. --> 900009
42. robert eskra --> 900010
43. robert murphy, esq. --> 900011
44. robert stewart, esq. --> 900012
45. robert vinceler, esq --> 900013
46. ronald atty. haywood + ronald haywood, esq. --> 900014
47. ryan stewart --> 900015
48. sandra stone, esq. --> 900016
49. stephie kapourales, esq. --> 900017
50. steven a. liss --> 900018
51. theodore a. bugda --> 900019
52. timothy mccullough, esq. --> 900020
53. trevor north --> 900021
54. william byrd, esq. --> 900022
55. william fleske, esq. --> 900023
56. william lyons, esq. --> 900024
57. william karl wigman, esq. --> 900025
58. natalie heil, esq. --> 900028
60. paula hutchinson, esq. --> 900029
61. michelle collins, esq. --> 900030
62. michael profeta, esq. --> 900031
63. megan flores, esq. --> 900032
64. kaalil muhammad, esq. --> 900033
65. martin scaratow, esq. --> 900034
66. mcgraw larry, esq. --> 900035
67. patrick atty. coyne, esq. --> 900036
68. julia l. dellinger --> 900037
69. thomas pratt + thomas pratt, esq. --> 900038
70. vincent a. cirillo jr. + vincent a. cirillo jr., esq. --> 90003
71. megan strait --> 900040
72. kathryn hunter-nonas --> 900042
73. karen avery, esq. --> 900043
74. nick peters --> 900044
75. nialena caravasos, esq. --> 900045
76. kyle mcgee, esq. --> 900046
77. larr barto, esq. --> 900047
78. lawrence singer, esq. --> 900048
79. k wynett, esq. --> 900049
80. kristyne sharpe --> 900050
81. kim spackman --> 900051

## Bail

We start with 410,429 docket sheets.

* Cases without any bail information are dropped (n = 65,791).
* Cases which: 1) originated in the court of common pleas, or 2) did not otherwise represent the initial bond setting are dropped (n = 39,161).
* Cases with: 1) monetary bail but the monetary amount was 0 or 2) non-monetary bail but the amount was greater than 0 are dropped (n = 2).
* Final sample size is 305,475.

## Judges + Demographic information

We start with 305,475 docket sheets with valid bail information. Cases with a missing judge overwhelmingly come from municipal courts in Pittsburgh. Cases that are not missing the judge but have generic office titles come predominantly from night court and central courts. There is no case from any of these courts that has a judge listed.

* We drop 81,977 cases with missing judicial information leaving us with 223,498 cases.
* We drop 5,646 cases with either missing sex, race, or age of the defendant leaving us with 217,852 cases.
  * 1,616 cases are missing the sex of the defendant.
  * 4,764 cases are missing the race of the defendant.
  * 1,481 cases are missing the age of the defendant.

## Lawyers

We start with 217,852 cases.

* 44,739 cases are missing both the prosecutor and defense attorney. Cases can have a missing attorney due to: 1) the attorneys are truly missing (i.e., no one was listed), 2) only a generic office was listed, or 3) a defense attorney's listed client was the state or a prosecutor's listed client was the defendant. These cases are dropped.
  * Of the remaining cases, 80,309 are missing the prosecutor. We drop these as well.
  * Of the remaining cases, 18,452 are missing the defense.
    * Of these cases, there were 5,846 cases in which the defendant either requested counsel and/or was provided an application for the appointment of a public defender.
    * The reason I bring this up is because the vast majority of these cases featured a defendant who did not want/did not seek out/were not eligible for a defense attorney or was not made properly aware of their ability to utilize a defense attorney.
    * In our main analyses these cases are dropped, but we can still do something interesting with them potentially.
* Our final sample size is 74,352.

## Charges

The 74,352 cases have a cumulative 191,693 charges associated with them.

* 87,427 charges (45.61%) matched with the Pennsylvania Crime Code.
* 41,320 charges (21.56%) matched with the Pennsylvania Crime Code after either adding or removing a star.
* 20,308 charges (10.59%) did not match based on the charge but did match based on the Statutory Class (where we used the omnibus offense gravity score (OGS)).
* 31,787 charges (16.58%) were summary charges and were assigned an OGS of 0.
* 5,624 charges (2.93%) did not have a grade and could only be matched on charge.
* 2,112 charges (1.1%) did not have a grade and could only be matched on charge after adding or removing a star.
* 1,673 charges (0.87%) were manually assigned a Statutory Class by reviewing the charge description (and then matched based on Statutory Class where the omnibus OGS was used).
* 1,442 charges (0.75%) could not be assigned a Statutory Class even after manual review and thus do not have an OGS.

81 cases are dropped due to the fact that all of their charges are missing their OGS. After dropping theses cases, 626 cases remain that have at least one (but not all) of their charges missing the OGS score (we keep these cases). Final sample is 74,271.

## Court summary sheets

### Sex, Race, DOB

Any cases in which race, sex, or year of birth do not match across the docket sheet and court summary sheet leads to the case being dropped and recoded to missing. Some cases which were missing their sex/race/DOB in the docket sheet did not have them missing in their court summary. However, these cases were still missing other pertinent variables (e.g., prosecutor or judge).

* 2 cases are dropped due to mismatched race.
* 10 cases are dropped due to mismatched years of birth.

Final sample size is 74,259.

### Criminal history

* 39.364 cases have at least one case in their criminal history where it could not be determined if that case came before or after the focal case.
* 1,525 cases have totally unknown criminal history. In other words, for all cases on their court summary sheet, it could not be determined if they happened before or after the focal case. These cases are dropped.

After dropping these cases, we are left with 72,734 cases in our sample.

* 7,205 cases have at least one instance of a charge in their criminal history that was missing their grade.
* 892 of these have cases are missing the grade for all charges in their criminal history. These cases are dropped.

After dropping these cases, we are left with 71,842 cases.

## General data checks

166 cases are dropped because: 1) the defendant's age at the time of their hearing was under 14, and/or 2) the defense attorney's private/public status could not be determined, and/or 3) the main prosecutor and main defense attorney were the same person. 

Final sample size is 71,676.
