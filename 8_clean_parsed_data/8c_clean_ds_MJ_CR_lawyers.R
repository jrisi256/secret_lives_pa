library(here)
library(dplyr)
library(tidyr)
library(purrr)
library(readr)
library(stringr)

################################################################################
# Read in flattened json file.
################################################################################
flattened_json_ds_mj <-
    readRDS(here("output", "pdf_parse_list", "flattened_json_ds_mj.rds"))

################################################################################
# Clean lawyer information.
################################################################################
lawyer_df <-
    flattened_json_ds_mj |>
    filter(L2 == "attorney_info") |>
    pivot_wider(
        id_cols = c("L1", "L3"),
        names_from = "L4",
        values_from = "value"
    )

lawyer_df_fix_parser_error <-
    lawyer_df |>
    group_by(L1) |>
    filter(any(is.na(name))) |>
    summarise(
        across(
            matches("name|type|representing|counsel_status|supreme_court_nr|L3"),
            function(col) {na.omit(col)[1]}
        )
    ) |>
    ungroup()

lawyer_df_error_fixed <-
    lawyer_df |>
    group_by(L1) |>
    filter(all(!is.na(name))) |>
    ungroup() |>
    bind_rows(lawyer_df_fix_parser_error)

############################# Harmonize lawyer names with supreme court numbers.
lawyer_df_error_fixed_harmonized <-
    lawyer_df_error_fixed |>
    mutate(
        supreme_court_nr =
            case_when(
                name %in%
                    c(
                        ", esquire kathleen a. cribbins, esq.",
                        "kathleen anne cribbins, esq.",
                        "kathleen cribbens, esq.", "kathy cribbens, esq.",
                        "kathy cribbins"
                    ) ~ "041109",
                name %in%
                    c(
                        ", esquire stephen r. greenberg, esq.",
                        "stephen atty. greenberg, esq.",
                        "stephen greenberg, esq.", "stephen r. greenberg, esq.",
                        "stephen greenburg, esq.", "stephen r. greenburg, esq.",
                        "steve greenburg, esq."
                    ) ~ "062691",
                name == "a charles peruto, jr." ~ "030634",
                name == "aaron kostyk, esq." ~ "320463",
                name %in% c("abramovitz, kevin, esq.", "kevin abranovitz, esq.") ~ "200202",
                name == "ada stephen geday, esq." ~ "204011",
                name %in%
                    c(
                        "ada todd stephens, esq.", "todd stephens, esq.",
                        "w. todd stephens, esq."
                    ) ~ "085753",
                name == "adam hill, esq." ~ "089049",
                name == "adam michael bishop, esq." ~ "307922",
                name == "adam reynolds, esq." ~ "319157",
                name == "alan paul skwarla, esq." ~ "090630",
                name == "alan ross, esq." ~ "081301",
                name == "alexander thomas korn, esq." ~ "323957",
                name == "alexandra lynn mcnulty, esq." ~ "327398",
                name %in% c("alex cashman, esq.", "alexaner cashman, esq.") ~ "306686",
                name == "alicia sutton werner, esq." ~ "314232",
                name %in% c("alison m. scarpitti", "alison m. scarpitti, esq.") ~ "087549",
                name %in% c("allen c. welch", "allen welch, esq.") ~ "034962",
                name == "allen lynn cohen, esq." ~ "047085",
                name == "amamda bonnesen, esq." ~ "203359",
                name %in% c("aman m. barber iii", "aman m. barber iii, esq.") ~ "069355",
                name == "amanda joyce brash, esq." ~ "331801",
                name %in% c("amber racunas, esq.", "racunas, amber rae, esq.") ~ "091468",
                name == "amita maram, esq." ~ "330716",
                name == "amy jay nowak, esq." ~ "323660",
                name %in% c("an vecchio, joshua jord, esq.", "joshua vecchio, esq.") ~ "093354",
                name == "andrew c. laird" ~ "202101",
                name == "andrew jarbola" ~ "314659",
                name == "andrew joseph capone, esq." ~ "310238",
                name == "andrew michael enders, esq." ~ "306488",
                name == "andrew ostrowski, esq." ~ "066420",
                name %in%
                    c(
                        "angela carsia, esq.", "angela rene carsia, esq.",
                        "angelia carcia, esq."
                    ) ~ "085544",
                name == "angela yavonne hayden, esq." ~ "308267",
                name %in%
                    c(
                        "anne gingrich, esq.", "anne gingrich-cornick",
                        "ann gingrich, esq."
                    ) ~ "092909",
                name == "ann mendelson steiner, esq." ~ "063715",
                name == "anne parsons, esq." ~ "331753",
                name == "annelise margaret baumgartner, esq." ~ "330710",
                name == "anthony bittner, esq." ~ "034300",
                name == "anthony deluca, esq." ~ "018067",
                name == "anthony e. stefanski, esquire" ~ "054497",
                name == "anthony erlain, esq." ~ "076047",
                name == "anthony f. list jr" ~ "081961",
                name == "anthony j. petrone, esq." ~ "042242",
                name == "anthony joseph george hassey, esq." ~ "324939",
                name == "april lynn cressler, esq." ~ "308353",
                name == "ari weitzman, esq." ~ "081927",
                name == "arik t benari" ~ "087133",
                name == "arnold klein, esq." ~ "048793",
                name == "ashcroft, barbara l, esq." ~ "086678",
                name %in% c("atty. david beyer, esq.", "david l. beyer, esq.") ~ "079709",
                name == "atty. erin connelly, esq." ~ "091106",
                name == "lee m. rothman, esq." ~ "077445",
                name %in% c("michael deriso, esq.", "atty. michael deriso, esq.") ~ "076555",
                name == "atty. raquel taylor, esq." ~ "090906",
                name == "barry g. goldman" ~ "061056",
                name == "barry j. palkovitz" ~ "044375",
                name == "barry miller, esq." ~ "013192",
                name == "basil d. beck iii" ~ "063349",
                name == "benjamin cooper, esq." ~ "058914",
                name == "benjamin jeffery bentley, esq." ~ "329774",
                name %in% c("bernard atty. tully, esq.", "bernard michael tully, esq.") ~ "030820",
                name == "bernie coates, esq." ~ "044686",
                name %in% c("beth hirz", "elizabeth anne hirz, esq.") ~ "083516",
                name == "bianca nalaschi, esq." ~ "329021",
                name == "bill stanislaw, esq." ~ "043226",
                name == "bjorn dakin, esq." ~ "200399",
                name %in%
                    c(
                        "blaine atty. jones, esq.", "blaine jones",
                        "blaine jones, esq.", "r. blaine jones, esq.",
                        "blane jones, esq."
                    ) ~ "094070",
                name %in% c("bonnie-ann brill keagy, esq.", "bonnie-ann keagy, esq.") ~ "077435",
                name %in% c("brad winnick, esq.", "m winnick, bradley ada, esq.") ~ "078413",
                name == "bradley deckel" ~ "332203",
                name == "bradley thomas marscher, esq." ~ "323828",
                name %in% c("brandon ging, esq.", "brandon paul ging, esq.")  ~ "207116",
                name == "brandon james bingle, esq." ~ "209133",
                name == "breese brittanyann lantzy, esq." ~ "325625",
                name == "brian daniel arrowsmith, esq." ~ "308092",
                name == "brian hokamp" ~ "314436",
                name == "brian jordan, esq." ~ "207223",
                name %in% c("brian mcquillan, esq.", "bryan matthew mcquillan, esq.") ~ "087967",
                name == "brian michael o'connor, esq." ~ "306746",
                name == "brian patrick mcdermott, esq." ~ "209322",
                name %in%
                    c(
                        "brent atty. mccune, esq.", "brent mccune, esq.",
                        "t. brent mccune, esq.", "uire t. brent mccune, esq."
                    ) ~ "047794",
                name %in%
                    c(
                        "brian walk, esq.", "bryan s. walk, esq.",
                        "bryan walk, esq.", "s. walk, bryan s"
                    ) ~ "063881",
                name == "brittany nicole petricca, esq." ~ "324366",
                name %in% c("brooks t. thompson", "brooks thomas thompson, esq.") ~ "311943",
                name %in%
                    c(
                        "bruce a. carsia, esq.", "bruce carsia",
                        "carsia, bruce a, esq.", "attny. bruce carcia, esq.",
                        "bruce carcia, esq."
                    ) ~ "018107",
                name == "bruce lee castor iii, esq." ~ "324577",
                name == "bruce wolbrette, esq." ~ "085572",
                name == "bryan eugene depowell jr., esq." ~ "308156",
                name %in%
                    c(
                        "c defender nathan giunta, publi, esq.",
                        "f. n. giunta public defender's of, esq."
                    ) ~ "092803",
                name %in% c("c procter, esq.", "christy procter, esq.") ~ "000003",
                name == "cailee marie st jean, esq." ~ "329087",
                name == "caitlin faith o'malley, esq." ~ "331007",
                name %in%
                    c(
                        "candace gervase ragin, esq.", "candace ragin, esq.",
                        "candace regan, esq.", "candice regan, esq."
                    ) ~ "204067",
                name %in% c("candace stockey, esq.", "candice stockey, esq.") ~ "203760",
                name %in% c("carluccio, thomas e, esq.", "thomas carluccio, esq.") ~ "081858",
                name == "carly cordaro nogay, esq." ~ "325758",
                name == "caroline rose goldstein, esq." ~ "322790",
                name == "casey swiski" ~ "326401",
                name == "casey white, esq." ~ "207470",
                name %in%
                    c(
                        "celeste whitford, esq.", "celeste whitford, esq.",
                        "ste whiteford, mary cele, esq.",
                        "celeste whiteford, esq."
                    ) ~ "085536",
                name == "cessalie harris, esq." ~ "203537",
                name == "chad j. vilushis, esq." ~ "080117",
                name == "charbel latouf, esq." ~ "083455",
                name == "charles atty. hoebler, esq." ~ "204179",
                name %in% c("charles atty. porter, esq.", "charles porter, esq.") ~ "043676",
                name == "charles gallo, esq." ~ "091200",
                name == "charles lopresti, esq." ~ "052758",
                name == "charles sacco, esq." ~ "036751",
                name == "charles schwartz, esq." ~ "022561",
                name %in% c("chelsea arianna robbins, esq.", "chelsea fry") ~ "321898",
                name == "chelsie ann pratt, esq." ~ "209260",
                name == "chris avetta, esq." ~ "049472",
                name %in% c("chris eyster, esq.", "christophre eyster, esq.") ~ "044166",
                name %in% c(
                    "chris stone, esq.", "christopher mark stone, esq.",
                    "christopher stone, esq.", "chris stoen, esq."
                ) ~ "200878",
                name %in% c("christine fuhrman konzel, esq.", "christine konzel, esq.") ~ "035197",
                name == "christopher atty. patarini, esq." ~ "041506",
                name == "christopher fiore" ~ "083018",
                name == "christopher h. cooper, esq." ~ "321384",
                name == "christopher joseph marsili, esq." ~ "321848",
                name == "christopher nicholas urbano, esq." ~ "091466",
                name == "christopher robert amthor, esq." ~ "319154",
                name == "christy foreman, esq." ~ "086886",
                name %in%
                    c(
                        "cindy cook, esq.", "cindy cooke, esq.",
                        "cynthia gail cooke, esq."
                    ) ~ "087708",
                name == "claudine montecillo, esq." ~ "208880",
                name == "codi marie tucker, esq." ~ "205158",
                name == "colby joseph miller, esq." ~ "311599",
                name == "colton david whitener, esq." ~ "331363",
                name %in% c("corky goldstein", "herbert goldstein, esq.") ~ "007182",
                name == "courtney amber king, esq." ~ "332200",
                name == "craig m. kellerman" ~ "047119",
                name == "craig lee, esq." ~ "062423",
                name == "craig thomas hosay, esq." ~ "058730",
                name %in% c("d.stephen ferito, esq.", "stephen d. ferito, esq.") ~ "005221",
                name == "dale klein, esq." ~ "083296",
                name == "damian joseph destefano, esq." ~ "206336",
                name == "damon hopkins, esq." ~ "076003",
                name == "daniel d. pond, esq." ~ "321920",
                name == "daniel edward fitzsimmons, esq." ~ "036474",
                name == "daniel f. gleixner, esq." ~ "314333",
                name == "daniel jacob eichinger, esq." ~ "311766",
                name == "daniel joseph kiss, esq." ~ "205920",
                name == "daniel-paul alva" ~ "015640",
                name %in% c("danielle berger kramer, esq.", "danielle berger, esq.") ~ "206979",
                name == "darrell n. vanormer" ~ "022046",
                name == "darryl dugan, esq." ~ "033924",
                name %in% c("david atty. shrager, esq.", "david shrager, esq.") ~ "022993",
                name == "david joel shrager, esq." ~ "083395",
                name == "david c. agresti, esq." ~ "079582",
                name == "david cercone, esq." ~ "048961",
                name == "david d. pardini, esq." ~ "077388",
                name == "david edward wilson, esq." ~ "209836",
                name == "david garcia, esq." ~ "054351",
                name == "david hershey, esq." ~ "043092",
                name == "david l. beyer, esq." ~ "079709",
                name == "david r. warner jr." ~ "206212",
                name %in% c("david sprugeon, esq.", "david spurgeon, esq.") ~ "078211",
                name == "david tornetta, esq." ~ "042881",
                name %in% c("david ungerman", "j. david ungerman, esq.") ~ "018128",
                name == "deanna arlene muller, esq." ~ "070348",
                name == "diana lanell page, esq." ~ "310127",
                name == "diane l. morgan, esq." ~ "053820",
                name == "donald atty. balsley, esq." ~ "033638",
                name == "donald henry presutti ii, esq." ~ "327808",
                name == "doug lavenberg" ~ "313651",
                name %in% c("douglas atty. sughrue, esq.", "doug sughrue, esq.") ~ "083970",
                name == "douglas b. breidenbach jr., esq." ~ "029985",
                name == "douglas james keating, esq." ~ "052037",
                name == "dudik, duane allen, esq." ~ "021349",
                name %in% c("shelley a. duff, esq.", "duff, shelley a, esq.") ~ "080955",
                name == "e vernon parkinson" ~ "077729",
                name == "edward bigham" ~ "079321",
                name == "edward d song, esq." ~ "208468",
                name == "edward e. zang, esq." ~ "059665",
                name == "edward joseph rideout iii, esq." ~ "087194",
                name == "edward michael marsico jr., esq." ~ "053915",
                name == "edward scheid, esq." ~ "034274",
                name == "edward spreha jr., esq." ~ "078661",
                name == "elana robin lange, esq." ~ "206736",
                name %in% c("albert gray, esq.", "elbert gray, esq.") ~ "205159",
                name %in% c("elisabaeth carmichael, esq.", "elisabeth k. carmichael") ~ "000004",
                name == "elizabeth pasqualini" ~ "201665",
                name %in% c("elliot atty. howsie, esq.", "elliot howsie, esq.") ~ "083441",
                name == "emanuel oakes jr., esq." ~ "081431",
                name == "emily claire downing, esq." ~ "322988",
                name == "emily marie hoff, esq." ~ "330859",
                name %in% c("emily clare mcnally, esq.", "emily mcnally, esq.") ~ "206591",
                name == "emmett madden" ~ "086894",
                name == "eric delp, esq." ~ "202521",
                name == "eric j. mikovich" ~ "073502",
                name == "eric jobe, esq." ~ "093890",
                name == "erica kreisman, esq." ~ "031241",
                name == "erin varley, esq." ~ "326230",
                name == "ethan oshea, esquire" ~ "069713",
                name == "evan lowery" ~ "306911",
                name == "evan robert charles correia, esq." ~ "321485",
                name == "f. suher, gregory f" ~ "077119",
                name == "finn l. skovdal, esq." ~ "316774",
                name %in%
                    c(
                        "fiorindo a vagnozzi, esq.", "fiorindo a. vagnozzi",
                        "fiorindo a. vagnozzi, esq."
                    ) ~ "031618",
                name %in%
                    c(
                        "flick, frank, esq.", "frank c. flick",
                        "frank c. flick, esq.", "frank flick, esq."
                    ) ~ "066178",
                name == "francis dacey wymard, esq." ~ "094749",
                name == "francis j. genovese" ~ "082308",
                name == "francis recchuitti, esq." ~ "009284",
                name == "frank atty. rapp, esq." ~ "036909",
                name %in% c("frank c. walker iii", "frank walker, esq.") ~ "094840",
                name == "frank moore, esq." ~ "060039",
                name %in% c("frank ralph, esq.", "frank w. ralph, esq.") ~ "202653",
                name %in% c("frank reilly, esq.", "frank riley, esq.") ~ "017378",
                name %in%
                    c(
                        "fred atty. rabner, esq.", "fred rabner, esq.",
                        "rabner, fred gordon, esq."
                    ) ~ "077337",
                name == "furrah jahan qureshi, esq." ~ "321340",
                name == "g. patrick polli iii, esq." ~ "317265",
                name %in% c(
                    "william g bills jr., esq.", "george atty bills, esq.",
                    "g. william bills jr., esq."
                ) ~ "020133",
                name == "gabriel magee" ~ "311646",
                name == "gabriella eileen glenning, esq." ~ "327409",
                name == "gabrielle christine hughes, esq." ~ "322448",
                name == "gail souders, esq." ~ "068740",
                name == "garrett taylor, esq." ~ "072643",
                name == "gary alan kern, esq." ~ "091166",
                name %in% c("gary atty gerson, esq.", "gary gerson, esq.") ~ "049511",
                name == "gary atty. zimmerman, esq." ~ "010080",
                name %in% c("gary kelley, esq.", "gary l. kelley, esq.") ~ "046801",
                name == "gary ogg, esq." ~ "034515",
                name == "gene placidi, esq." ~ "030331",
                name == "george a. miller" ~ "022525",
                name == "george matangos, esq." ~ "070297",
                name %in% c("george porter, esq.", "gerald w. porter, esq.") ~ "042752",
                name == "george s. yacoubian, jr" ~ "206576",
                name == "george shultz, esq." ~ "032684",
                name == "gerald nelson, esq." ~ "056790",
                name == "gerard paul shotzbarger, esq." ~ "035475",
                name == "gery t. nietupski, esq." ~ "041488",
                name %in%
                    c(
                        "giuseppe rosselli, esq.", "giuseppi oselli, esq.",
                        "giuseppi roselli, esq.", "giuseppi rosselli, esq."
                    ) ~ "087248",
                name == "glen steimer, esq." ~ "027506",
                name == "grant stephen malleus, esq." ~ "324289",
                name == "grant thomas miller, esq." ~ "319970",
                name == "greg schwab, esq." ~ "043918",
                name == "gregory corbett mills, esq." ~ "091560",
                name == "gregory francis stein, esq." ~ "321100",
                name == "gregory noonan, esq." ~ "048544",
                name == "guy r. sciolla ii, esq." ~ "019051",
                name %in%
                    c(
                        "h difenderfer, william, esq.",
                        "william difenderfer, esq.", "bill diffendorfer, esq.",
                        "william h. difendefer, esq.", ""
                    ) ~ "039348",
                name %in% c("harry r. ruprecht, esq.", "harry ruprecht, esq.") ~ "016439",
                name == "j. hartwell hillman iv, esq." ~ "085481",
                name %in%
                    c(
                        "hartnett, krista m, esq.", "kirsta hartnett, esq.",
                        "krist hartnett, esq.", "krista hartnett, esq.",
                        "krista m hartnett, esq."
                    ) ~ "000005",
                name %in%
                    c(
                        "hasan mansori, esq.", "hasan monsori, esq.",
                        "hasan zubair mansori, esq."
                    ) ~ "205521",
                name == "heather ann serrano, esq." ~ "320443",
                name == "heather hines, esq." ~ "306509",
                name %in% c("henderson-bryan, esq.", "lena bryan henderson") ~ "061689",
                name %in% c("henry s. hilles, iii", "hilles, henry s, esq.") ~ "073968",
                name == "hillary catterton hall, esq." ~ "322964",
                name == "iphigenia atty. toridas, esq." ~ "074597",
                name == "ire brent j. lemon, esq." ~ "086478",
                name %in% c("j michael sheldon, esq.", "michael sheldon, esq.") ~ "083098",
                name == "j. timothy george, esq." ~ "067107",
                name == "jackie kearney, esq." ~ "052706",
                name == "jackson eric lurie, esq." ~ "082535",
                name == "jacob belvin reinhart, esq." ~ "201290",
                name == "jacob wesley wyland, esq." ~ "201081",
                name == "jake daniel morrison, esq." ~ "322552",
                name == "james a. crosby" ~ "082298",
                name == "james abraham, esq." ~ "046352",
                name %in% c("james attorney ecker, esq.", "james ecker, esq.") ~ "010775",
                name %in%
                    c(
                        "james atty. sheets, esq.",
                        "james patrick sheets, esq.", "james sheets, esq.",
                        "james sheetz, esq.", "jim sheets, esq."
                    ) ~ "082913",
                name == "james corsetti, esq." ~ "058348",
                name == "james cunillo, esq." ~ "022148",
                name %in% c("james depasquale, esq.", "james eugene depasquale, esq.") ~ "030223",
                name == "james egan durkin, esq." ~ "025542",
                name %in% c("james flood, esq.", "james w. flood") ~ "045661",
                name == "james herb, esq." ~ "027854",
                name == "james schwartz, esq." ~ "023631",
                name == "james wymard, esq." ~ "010527",
                name == "jamie mead, esq." ~ "039610",
                name %in% c("jamie wingard, esq.", "wingard, jami l, esq.") ~ "087635",
                name == "wingard, barry duane, esq." ~ "078984",
                name %in% c("medoff, jan ira, esq.", "jan medoff, esq.") ~ "036782",
                name == "janet necessary, esq." ~ "028931",
                name == "jason atty walsh, esq." ~ "078010",
                name %in% c("jason nard, esq.", "jason nards, esq.") ~ "093178",
                name %in% c("jasroop gill-gakhal, esq.", "jasroop gil-gachal, esq.") ~ "094766",
                name == "jay kalasnik" ~ "076063",
                name == "jeanne marie emhoff, esq." ~ "325315",
                name == "jediah grobstein, esq." ~ "329374",
                name %in% c("jeff connelly, esq.", "jeffrey a. connelly, esq.") ~ "026145",
                name %in% c(
                    "jeffrey wasak, esq.", "jeffrey atty wasak, esq.",
                    "jeff wasak, esq."
                ) ~ "052770",
                name == "jeffery howard tisak, esq." ~ "321202",
                name == "jenna l lewis, esq." ~ "308829",
                name == "jenna marie fliszar, esq." ~ "310035",
                name == "jennifer digiovanni, esq." ~ "078728",
                name == "jennifer lee edmiston, esq." ~ "308138",
                name == "jennifer marie buono, esq." ~ "332221",
                name == "jennifer wisniewski gettle, esq." ~ "079191",
                name %in% c("jeremy abidiwan-lupo", "jeremy lupo") ~ "306763",
                name == "jessica lauren bush, esq." ~ "094624",
                name == "jill j holden, esq." ~ "092119",
                name == "jim zoll, esq." ~ "203660",
                name == "jividen, jacob m, esq." ~ "087519",
                name %in% c("joanne marie o'brien, esq.", "joanne o'brien") ~ "319397",
                name == "joel d. peppetti, esq." ~ "093134",
                name %in% c("joel hogentogler, esq.", "joel richard hogentogler, esq.") ~ "306539",
                name %in% c("john a. bledrzycki, esq.", "john biedrzycki, esq.") ~ "091400",
                name %in%
                    c(
                        "john atty. mcnoon, esq.", "john macnoon",
                        "john maknoon, esq.", "john mcnoon, esq.",
                        "jon atty. maknoon, esq.", "jon maknoon, esq.",
                        "komron jon maknoon, esq."
                    ) ~ "090466",
                name %in% c("john baer, esq.", "john c baer, esq.") ~ "201632",
                name %in% c("john canavan, esq.", "john r. canavan iv, esq.") ~ "084728",
                name == "john ciroli jr., esq." ~ "080422",
                name %in% c("john d'intino jr., esq.", "john d'intonio, esq.") ~ "083473",
                name == "john david sisto, esq." ~ "072912",
                name == "john dougherty, esq." ~ "070680",
                name %in% c("john elash, esq.", "john esquire elash, esq.") ~ "022585",
                name == "john f. siford, esq." ~ "073140",
                name == "john fenner, esq." ~ "052701",
                name == "john fitzgerald, esq." ~ "081137",
                name == "john g. munoz, esq." ~ "316003",
                name == "john glace, esq." ~ "023933",
                name %in%
                    c(
                        "john mcmahon jr., esq.", "john mcmahon jr",
                        "john i. mcmahon jr., esq."
                    ) ~  "053777",
                name == "john j. griffin" ~ "042891",
                name %in% c("john j. mcauliffe jr.", "john j. mcauliffe, jr.") ~ "003593",
                name == "john k. lewis jr" ~ "083722",
                name == "john knorr, esq." ~ "019803",
                name == "john m. solt, esq." ~ "089146",
                name == "john mancke, esq." ~ "007212",
                name %in% c("john marcellaro, esq.", "m macellaro, esq.") ~ "025946",
                name == "john michael arose, esq." ~ "318868",
                name == "john n. gradel, esq." ~ "061958",
                name == "john scott robinette, esq." ~ "066127",
                name %in% c("john francis walko ii, esq.", "john walko a.d.a., esq.") ~ "206446",
                name == "john zagari, esq." ~ "033753",
                name == "jonathan david lusty, esq." ~ "311180",
                name == "jonathan peter schultz, esq." ~ "307651",
                name == "jonathan stewart, esq." ~ "087557",
                name %in% c("jonathan white", "jonathan randle white, esq.") ~ "313808",
                name == "jonathon reichman, esq." ~ "088200",
                name == "r.emmett madden, esq." ~ "000002", # Fairly certain this is senior.
                name == "adam hobaugh, esq." ~ "000006",
                name == "alexndria kramer" ~ "000001",
                name == "alyssa john, esq." ~ "000007",
                name == "amanda chesar" ~ "000008",
                name == "anthony beeraro, esq." ~ "000010",
                name == "anthony borello, esq." ~ "000011",
                name == "anthony moses" ~ "000012",
                name == "anthony rodriguez, esq." ~ "208546",
                name == "barb swartz, esq." ~ "000013",
                name == "bob heyward, esq." ~ "000014",
                name == "brad breslin, esq." ~ "000015",
                name == "cassie vasicak" ~ "000016",
                name == "charles fidel, esq." ~ "000017",
                name == "daniel n. schwartz, esq." ~ "000018",
                name == "david campbell, esq." ~  "000019",
                name == "donald minahan, esq." ~ "000020",
                name == "duke morris, esq." ~ "000021",
                name == "erica burry" ~ "000022",
                name == "fincourt b. shelton, esq." ~ "000023",
                name == "foley law offices of jerry, esq." ~ "000024",
                name == "francis a. mccormick" ~ "000025",
                name == "gail marr-williams" ~ "000026",
                name == "glenn j. smith" ~ "000027",
                name == "greg mcfarland, esq." ~ "000028",
                name %in% c(
                    "guy rosalyn mccorkle, esq.", "rosalyn guy mccorkle, esq.",
                    "rosalyn guy-mccorkle, esq.", "roslyn guy-mccorkle, esq.",
                    "rosalyn atty. guy, esq.", "roslyn atty. guy, esq."
                ) ~ "058827",
                name == "hart hillman, esq." ~ "000030",
                name == "hary chestnut, vernon zac, esq." ~ "000009",
                name == "james black, esq." ~ "000031",
                name == "jean trenbeath" ~ "000032",
                name == "jerry atty. sklavounakis, esq." ~ "000000",
                name == "jerry johnson, esq." ~ "000033",
                name == "jesse juilante, esq." ~ "000034",
                name == "john burt, esq." ~ "000035",
                name == "john mccall, esq." ~ "000036",
                name == "john n. salla" ~ "000037",
                name == "john noonan, esq." ~ "000039",
                name=="rakiesha foster, esq." ~ "093835",
                name=="joseph curcillo, esq." ~ "044060",
                name=="joseph atty. kanfoush, esq." ~ "010446",
                name=="joseph david horowitz, esq." ~ "076650",
                name=="joseph horowitz, esq." ~ "076650",
                name=="joseph kanfoush, esq." ~ "010446",
                name=="joseph john peluso jr., esq."~ "322819",
                name=="joseph m. sembrot, esq." ~ "073076",
                name=="joseph patrick green jr., esq" ~ "032604", 
                name=="joseph p. d'alonzo,ii" ~ "207416", 
                name=="joseph v. luvara, esq." ~ "079834",
                name=="joshua guckert, esq."~ "322571",
                name=="joshua marcus bower, esq."~ "318527",
                name=="joshua russell roberts, esq."~ "307787",
                name=="joshua traver" ~ "323332",
                name=="jr., esquire james j. gillespie,, esq."~ "035263",
                name=="julia althea zebley, esq."~ "316776",
                name=="julia jacobs van leeuwen, esq."~ "326054",
                name=="justin james smith, esq."~ "324305",
                name=="justin john-earl ketchel, esq."~ "209718",
                name=="justin john-earl ketchel, esq"~ "209718",
                name=="justin thomas romano, esq."~ "307879",
                name=="kadin brown, esq."~ "200816",
                name=="kaitlyn sherry clarkson, esq."~ "323612",
                name=="karen irene koelsch, esq."~ "068919",
                name=="karl e. rominger"~ "081924",
                name=="katherine porter lovelace, esq."~ "210209",
                name=="kathryne louise hemmings, esq."~ "320676",
                name=="katie lynee adam, esq."~ "318416", 
                name=="keith donnelly, esq."~ "020114",
                name=="keith harbinson" ~ "072708",
                name=="kelli j. kleeb, esq."~ "087328",
                name=="kelly mclaughlin, esq."~ "325951",
                name=="kenneth allen bickel, esq."~ "091890",
                name=="kenneth jay haber, esq."~ "065968",
                name=="kenneth richard harris jr., esq."~ "089091",
                name=="kevin abranovitz, esq."~ "200202",
                name=="kevin alan chernosky, esq."~ "092972",
                name=="kevin michael scheibel, esq."~ "313926",
                name=="kevin atty. trower, esq." ~ "066071",
                name=="kim atty. riester, esq."~ "019920",
                name=="kim wm. reister, esq."~ "019920",
                name=="kim atty. reister, esq."~ "019920",
                name=="kimberly june hudak, esq."~ "092863",
                name=="komron jon maknoon, esq."~ "090466",
                name=="korey leslie" ~ "090866",
                name=="kristen leigh weisenberger, esq."~ "084757",
                name=="kristie m. falbo, esq."~ "315977",
                name=="kristyne michelle crist, esq."~ "313743",
                name=="kristy falbo"~ "315977",
                name=="l. charles fedel"~ "056428",
                name=="l. todd goodwin, esq."~ "056727",
                name=="mark d. lancaster, esq."~ "058783",
                name=="lancaster, mark d, esq."~ "058783",
                name=="landa lakisha porter, esq."~ "323612",
                name=="lauren irene heron, esq."~ "205552",
                name=="lautner, esq."~ "080134",
                name=="scott lautner"~ "080134",
                name=="lawrence d'ambrosio, esq."~ "006512",
                name=="lawrence elliot sachs, esq."~ "040579",
                name=="lawrence rosen, esq."~ "010625",
                name=="lawrence sachs, esq."~ "040579", 
                name=="lea terlonge, esq."~ "200892",
                name=="leigh p. narducci, esq."~ "009269",
                name=="leo c. harper jr., esq."~ "028072",
                name=="leonard d. biddison"~ "068070",
                name=="leonard j. berger jr., esq."~ "081822",
                name=="lisa middleman, esq."~ "049557",
                name=="louis a. emmi, esq."~ "332024",
                name=="louis atty emmi, esq."~ "332024",
                name=="lou coles, esq." ~ "028743",
                name=="louis c. coles"~ "028743",
                name=="louis emmi, esq."~ "047518",
                name=="louise atty. porac, esq."~ "021983",
                name=="louise m. petrillo"~ "078598",
                name=="louise petrillo, esq."~ "078598",
                name=="lyle lewis dresbold, esq."~ "208123",
                name=="marc david daffner, esq."~ "070615",
                name=="marc daffner, esq."~ "070615",
                name=="mark daffner, esq." ~"070615",
                name=="margaret gold, esq."~ "054685",
                name=="mark davis nolfi, esq."~ "323592",
                name=="mark bayley, esq."~ "087663",
                name=="mark lancaster, esq."~ "058783",
                name=="mark p. much"~ "060043",
                name=="mark richmond, esq." ~ "034513",
                name=="mark smith, esq."~ "040489",
                name=="markovitz, lee, esq."~ "036755",
                name=="marlin markley, esq."~ "084745",
                name=="martin benjamin lock, esq."~ "312716",
                name=="martin dietz, esq."~ "069182",
                name=="marvin atty. leibowitz, esq."~ "025034",
                name=="mary c. fittipaldi, esq."~ "066237",
                name=="mary summer ford carroll, esq."~ "205466",
                name=="matt dugan, esq."~ "900001",
                name=="matthew bentley goddard, esq."~ "307879",
                name=="matthew bingham banks, esq."~ "312355",
                name=="matthew blaze dante, esq."~ "207707",
                name=="matthew james rippin, esq."~ "204037",
                name=="matthew thomas ness, esq"~ "208026",
                name=="max benjamin walko, esq."~ "313846",
                name=="max daniel cotton, esq."~ "313096",
                name=="meghan e. jones-rolla, esq."~ "089481",
                name=="meghan mcnaughton"~ "316199",
                name=="melissa rose ruggiero, esq."~ "094710",
                name=="melissa john, esq."~ "090260",
                name=="melissa johns, esq."~ "090260",
                name=="melvin l. vatz, esq."~ "023655",
                name=="meredith nicole pfundheller, esq."~ "325926",
                name=="michael atty. moser, esq."~ "078844",
                name=="michael moser, esq."~ "078844",
                name=="michael atty. healey, esq."~ "027283",
                name=="michael atty. o'day, esq."~ "077698",
                name=="michael atty. witherel, esq."~ "027726",
                name=="witherel, michael j, esq."~ "027726",
                name=="michael d. foglia, esq."~ "017283",
                name=="michael duda, esq."~ "047749",
                name=="michael f. dunn, esq."~ "032599",
                name=="michael h. applebaum, esq."~ "001926",
                name=="michael j. yoder, esq."~ "086210",
                name=="michael l. rozman, esq."~ "035063",
                name=="michael m. finley, esq."~ "323432",
                name=="michael moser, esq."~ "078844",
                name=="michael madeira, esq."~ "055865",
                name=="michael oresto palermo jr., esq."~ "093334",
                name=="michael p. quinn"~ "050471",
                name=="michael paul petro, esq."~ "076688",
                name=="michael robert ball, esq."~ "036474",
                name=="michael v. wergel, esq."~ "093391",
                name=="michael w. cassidy"~ "034724",
                name=="michael yoder, esq."~ "900002",
                name=="michael yoder-pd, esq."~ "900002",
                name=="michelle hope shefton, esq."~ "322060",
                name=="molly ann campbell, esq."~ "331832",
                name=="murphy, robert p, esq."~ "062315",
                name=="nicholas m. mancini, esq."~ "030282",
                name=="nicole lee carnevale, esq."~ "321054",
                name=="nina martinelli, esq."~ "322543",
                name=="ohn christmas, anthony j, esq."~ "093389",
                name=="p. richard wagner, esq."~ "023103",
                name=="thomassey, esq."~ "022864",
                name=="patrick thomassey, esq."~ "022864",
                name=="patrick atty. thomassey, esq."~ "022864",
                name=="patrick atty. nightingale, esq."~ "076015",
                name=="patrick nightengale, esq." ~ "076015",
                name=="patrick thomas klena, esq."~ "088144",
                name=="paul gettleman, esq."~ "018244",
                name=="paul atty. gettleman, esq."~ "018244",
                name=="paul iannetti"~ "204478",
                name=="paul david boas, esq."~ "325653",
                name=="paul muller, esq."~ "073799",
                name=="paul watson muller, esq."~ "073799",
                name=="paul orr, esq."~ "071786",
                name=="perry demarco, esq." ~ "022640",
                name=="peter nyches, esq." ~ "027931",
                name=="ph perkins, robert jose, esq."~ "200961",
                name=="robert joseph reilley, esq."~ "046487",
                name=="phillip dilucente, esq."~ "087295",
                name=="phillip atty. dilucente, esq."~ "087295",
                name=="philip dilucente, esq."~ "087295",
                name=="phillip carlos hong-barco, esq."~ "204286",
                name=="phillip charles kirchner, esq."~ "093334",
                name=="pietro j. d'angelo"~ "090873",
                name=="qawl rahman"~ "090454",
                name=="patrick schulte, esq."~ "093619",
                name=="paul boas, esq."~ "325653",
                name=="phil melograne, esq."~ "050454",
                name=="r. david conwell"~ "063143",
                name=="rachael c. arieanna santoriella, esq."~ "207299",
                name=="rachel fleiming, esq."~ "093763",
                name=="rachel flemign, esq."~ "093763",
                name=="rachel fleming, esq."~ "093763",
                name=="rachel catherine fleming, esq."~ "093763",
                name=="rache; fleming, esq."~ "093763",
                name=="rachel blevins, esq."~ "330241",
                name=="rachel marie geizura, esq."~ "210209",
                name=="rakiesha foster, esq."~ "093835",
                name=="ralph karsh, esq."~ "058782",
                name=="yoder, michael j, esq."~ "086210",
                name=="yemi tama-re olaiya, esq."~ "330344",
                name=="woodward, timothy, esq." ~ "064321",
                name=="william s. flynn, esq."~ "331553",
                name=="lysaght, gary, esq."~ "039183",
                name=="steven e. kellis"~ "066694",
                name=="steven e. kellis, esq."~ "066694",
                name=="rakiesha foster, esq." ~ "093835",
                name=="kelli mcginnis" ~ "319664",
                name=="william craig penglase, esq." ~ "086875",
                name=="william shreve, esq." ~ "082337",
                name=="william steffes, esq." ~ "033370",
                name=="wililam e. stockey, esq." ~ "015581",
                name=="william stockey, esq." ~ "015581",
                name=="joseph patrick green jr., esq." ~ "032604",
                name=="nklin maffett, richard fra, esq." ~ "035539",
                name=="matthew thomas ness, esq." ~ "208026",
                name=="mark r. falconi" ~ "900004",
                name=="mackenzie iocona" ~ "900005",
                name=="robert samuel walker, esq." ~ "333084",
                name=="richard john fuschino jr., esq." ~ "206094",
                name=="ray gricar, esq." ~ "900007",
                name=="leo harper, esq." ~ "028072",
                name=="re leo c. harper, esq." ~ "028072",
                name=="re lee markovitz, esq." ~ "036755",
                name=="joseph francis hartye, esq." ~ "200816",
                name=="joseph j. chester, esq." ~ "034608",
                name=="rebecca alyce auld, esq." ~ "091966",
                name=="rhiannon wheeler sisk, esq." ~ "207797",
                name=="kovacs, richard paul, esq." ~ "038884",
                name=="shore, casey grey, esq." ~ "085321",
                name=="re alonzo burney, esq." ~ "016306",
                name=="rebecca alpern, esq." ~ "084310",
                name=="rebecca hudak, esq." ~ "202134",
                name=="richard atty. narvin, esq." ~ "019882",
                name=="richard narvin, esq." ~ "019882",
                name=="sumner parker, esq." ~ "028611",
                name=="parker sumner, esq." ~ "028611",
                name=="nicole sloan" ~ "200044",
                name=="robert downey jr" ~ "049644",
                name=="richard e. romanko, esq." ~ "078285",
                name=="richard joyce, esq." ~ "035765",
                name=="richard p. gilmore, esq." ~ "900009",
                name=="richard q. hark, esq." ~ "069526",
                name=="richard start, esq." ~ "034315",
                name=="richard welch, esq." ~ "018158",
                name=="rick feinberg, harry fred, esq." ~ "079944",
                name=="risa ferman, esq." ~ "065228",
                name=="rita murillo, esq." ~ "039337",
                name=="robert alan alsberg, esq." ~ "043551",
                name=="robert g. delgreco jr., esq." ~ "034247",
                name=="robert attorney delgreco, esq." ~ "034247",
                name=="robewrt atty. delgreco, esq." ~ "034247",
                name=="robert atty. delgreco, esq." ~ "034247",
                name=="summer carroll" ~ "205466",
                name=="steven fisher fairlie, esq." ~ "075936",
                name=="sarah jane krolikowski, esq." ~ "318679",
                name=="sarah elizabeth malek, esq." ~ "324854",
                name=="sarah e. coblentz, esq." ~ "326314",
                name=="samuel william esterman, esq." ~ "325653",
                name=="sandra kozlowski, esq." ~ "089127",
                name=="robert e. mielnicki, esq." ~ "063489",
                name=="robert atty. mielnicki, esq." ~ "063489",
                name=="robert eskra" ~ "900010",
                name=="robert f. datner" ~ "063086",
                name=="robert koehler, esq." ~ "032780",
                name=="robert mirin, esq." ~ "025305",
                name=="robert murphy, esq." ~ "900011",
                name=="robert paul vincler, esq." ~ "020226",
                name=="robert shaffer disney, esq." ~ "322120",
                name=="robert stewart, esq." ~ "900012",
                name=="roderick mccord fancher iii, esq." ~ "319123",
                name=="robert vinceler, esq" ~ "900013",
                name=="ron tyszkiewicz, esq." ~ "051372",
                name=="ronald atty. haywood, esq." ~ "900014",
                name=="ronald haywood, esq." ~ "900014",
                name=="ronald makowski, esq." ~ "016409",
                name=="ronald russell, esq." ~ "042572",
                name=="royce morris, esq." ~ "064310",
                name=="ryan matthew tutera, esq." ~ "318679",
                name=="ryan patrick shovlin, esq." ~ "321177",
                name=="ryan smith, esq." ~ "086913",
                name=="ryan stephen kiray, esq." ~ "316718",
                name=="ryan stewart" ~ "900015",
                name=="s steele, charles elli, esq." ~ "036583",
                name=="sam pangburn, esq." ~ "010823",
                name=="samantha anne arena, esq." ~ "326160",
                name=="samantha elizabeth sridaran, esq." ~ "329181",
                name=="samantha leigh thompson, esq." ~ "319226",
                name=="samir sarna, esq." ~ "310372",
                name=="samuel m. difatta, esq." ~ "078156",
                name=="sandra stone, esq." ~ "900016",
                name=="sarah eileen linder marx, esq." ~ "328870",
                name=="sarah kimberly weikart, esq." ~ "322419",
                name=="sarah phillips" ~ "318535",
                name=="saul jay solomon" ~ "053971",
                name=="saul jay solomon, esq." ~ "053971",
                name=="savage, stuart e, esq." ~ "000966",
                name=="scott frame" ~ "316027",
                name=="scott nathan pletcher, esq." ~ "086910",
                name=="sean cullen" ~ "080051",
                name=="sean cullen, esq." ~ "080051",
                name=="segan, saul h, esq." ~ "010346",
                name=="seman, owen matthew, esq." ~ "091140",
                name=="shanicka kennedy, esq." ~ "088306",
                name=="shanika kennedy, esq." ~ "088306",
                name=="shawn curry" ~ "202061",
                name=="shi novak, esq." ~ "040218",
                name=="shirley atty. novak, esq." ~ "040218",
                name=="shirley novak, esq." ~ "040218",
                name=="sidney atty. sokolsky, esq." ~ "016358",
                name=="simquita bridges, esq." ~ "080318",
                name=="sim bridges, esq." ~ "080318",
                name=="squire david p. strellec, e, esq." ~ "039324",
                name=="stacey lyn steiner, esq." ~ "082861",
                name=="stanley atty. greenfield, esq." ~ "000622",
                name=="stanley esquire fudor, esq." ~ "083563",
                name=="stanton atty. levenson, esq." ~ "000765",
                name=="stephanie allison eshenbaugh, esq." ~ "327539",
                name=="stephanie m. muick" ~ "094135",
                name=="stephen a. seidel, esq." ~ "021472",
                name=="stephen begler, esq." ~ "038521",
                name=="stephen atty. begler, esq." ~ "038521",
                name=="stephen bruce jarrett, esq." ~ "063007",
                name=="stephen charles sliger, esq." ~ "323508",
                name=="stephen r. zawisky, esq." ~ "089458",
                name=="stephen mcclintock, esq." ~ "081594",
                name=="stephie kapourales, esq." ~ "900017",
                name=="steve e. jarmon, jr" ~ "200600",
                name=="steve statmiller, esq." ~ "053332",
                name=="steven stadtmiller, esq." ~ "053332",
                name=="steven ernest kellis, esq." ~ "066694",
                name=="steven michael jones, esq." ~ "205498",
                name=="steve townsend, esq." ~ "089263",
                name=="steven a. liss" ~ "900018",
                name=="steven mckee liboski, esq." ~ "324755",
                name=="steven michael jones, esq." ~ "205498",
                name=="sylvia marakas, esq." ~ "312243",
                name=="tabia cole, esq." ~ "205829",
                name=="tami l. fees" ~ "201104",
                name=="tashawna quamira page, esq." ~ "328759",
                name=="taylor brindle staiger, esq." ~ "324904",
                name=="taylor marie corn, esq." ~ "326906",
                name=="terlonge, lea, esq." ~ "200892",
                name=="terrance j. mcgowan" ~ "039129",
                name=="terrence peter hanna jr., esq." ~ "319502",
                name=="terry w. despoy, esq." ~ "042071",
                name=="theodore a. bugda" ~ "900019",
                name=="thomas atty. caulfield, esq." ~ "063373",
                name=="thomas brasco" ~ "306410",
                name=="thomas c. egan iii" ~ "052530",
                name=="thomas c. egan iii, esq." ~ "052530",
                name=="thomas c. egan, esq." ~ "052530",
                name=="thomas farrell, esq." ~ "048976",
                name=="thomas ferrell, esq." ~ "048976",
                name=="thomas paul kelly, esq." ~ "316652",
                name=="tiffany marie gray, esq." ~ "314446",
                name=="tilman paul larson, esq." ~ "308943",
                name=="tim atty. sheerer, esq." ~ "000992",
                name=="timothy g. daly, esq." ~ "093652",
                name=="timothy gill lavoie, esq." ~ "312111",
                name=="timothy mccormick, esq." ~ "029490",
                name=="timothy mccullough, esq." ~ "900020",
                name=="timothy tomasic, esq." ~ "205126",
                name=="todd atty. hollis, esq." ~ "072510",
                name=="todd elliot, esq." ~ "080756",
                name=="todd goodwin, esq." ~ "056727",
                name=="tracey anne olszewski, esq." ~ "315763",
                name=="tracey l. potere" ~ "202251",
                name=="trevor north" ~ "900021",
                name=="ttorney at law frank l cecchetti, a, esq." ~ "023292",
                name=="turahn jenkins, esq." ~ "201267",
                name=="tur jenkins, esq." ~ "201267",
                name=="tyler alan lindquist, esq." ~ "323677",
                name=="uire lester crawford, esq." ~ "058024",
                name=="uire regina m. brown, esq." ~ "091493",
                name=="valarie l. potell" ~ "313069",
                name=="vera freshwater, esq." ~ "076740",
                name=="veronica brestensky, esq." ~ "201361",
                name=="vicki piontek, esq." ~ "083559",
                name=="vincent margiotti, esq." ~ "079655",
                name=="warren lee crilly iii, esq." ~ "307387",
                name=="wendy grella, esq." ~ "085164",
                name=="wendy j f. grella" ~ "085164",
                name=="wendy jean farver grella, esq." ~ "085164",
                name=="wendy lynne williams, esq." ~ "050379",
                name=="william atty. brennan, esq." ~ "019684",
                name=="william brennan, esq." ~ "019684",
                name=="william e. cercone jr." ~ "000322",
                name=="william atty. cercone, esq." ~ "000322",
                name=="william i. english, jr" ~ "010087",
                name=="william i. english jr., esq." ~ "010087",
                name=="william atty. caye, esq." ~ "070387",
                name=="william caye ii, esq." ~ "070387",
                name=="william byrd, esq." ~ "900022",
                name=="william denardo, esq." ~ "080697",
                name=="william fetterhoff, esq." ~ "023148",
                name=="william fleske, esq." ~ "900023",
                name=="william j. fulton" ~ "025457",
                name=="william j. goldman jr., esq." ~ "021201",
                name=="william lyons, esq." ~ "900024",
                name=="william karl wigman, esq." ~ "900025",
                name=="wendy williams, esq." ~ "050379",
                name=="wendy atty. williams, esq." ~ "050379",
                name=="thomas fitzgerald, esq." ~ "043580",
                name=="petrie, charles e, esq." ~ "029029",
                name=="mittman, jeremy z, esq." ~ "072985",
                name=="joseph a. malley iii, esq." ~ "027866",
                name=="mitchell, lawrence m, esq." ~ "060000",
                name=="natalie heil, esq." ~ "900028",
                name=="natehan guinta, esq." ~ "092803",
                name=="nathan junta, esq." ~ "092803",
                name=="paula hutchinson, esq." ~ "900029",
                name=="michelle collins, esq." ~ "900030",
                name=="turahn lamont jenkins, esq." ~ "201267",
                name=="michael profeta, esq." ~ "900031",
                name=="michael fives, esq." ~ "026085",
                name=="megan flores, esq." ~ "900032",
                name=="lisa ferrick, esq." ~ "082381",
                name=="kaalil muhammad, esq." ~ "900033",
                name=="martin scaratow, esq." ~ "900034",
                name=="mcgraw larry, esq." ~ "900035",
                name=="patrick atty. coyne, esq." ~ "900036",
                name=="julia l. dellinger" ~ "900037",
                name %in% c("thomas pratt", "thomas pratt, esq.") ~ "900038",
                name=="vincent a. cirillo jr." ~ "900039",
                name=="vincent a. cirillo jr., esq." ~ "900039",
                name=="megan strait" ~ "900040",
                name=="kathryn hunter-nonas" ~ "900042",
                name=="karen avery, esq." ~ "900043",
                name=="katie wymard" ~ "200408",
                name=="kelsey ashworth" ~ "323288",
                name=="kelly stuwart, esq." ~ "202917",
                name=="michael waltman, esq." ~ "206746",
                name=="mike waltman, esq." ~ "206746",
                name=="megan hazel reppy, esq." ~ "084047",
                name=="phillip kirchner" ~ "093334",
                name=="melissa rosa, esq." ~ "083448",
                name=="nick peters" ~ "900044",
                name=="nichole smith, esq." ~ "200855",
                name=="nialena caravasos, esq." ~ "900045",
                name=="michael worgul" ~ "093391",
                name=="mike worgul, esq." ~ "093391",
                name=="mark rubenstein, esq." ~ "028952",
                name=="kevin zinski, esq." ~ "056875",
                name=="michael lederman, esq." ~ "085941",
                name=="michael kalocay, esq." ~ "066764",
                name=="lauren melfa, esq." ~ "206905",
                name=="kyle mcgee, esq." ~ "900046",
                name=="larr barto, esq." ~ "900047",
                name=="lawrence singer, esq." ~ "900048",
                name=="megan black, esq." ~ "084943",
                name=="k wynett, esq." ~ "900049",
                name=="kenneth haber, esq." ~ "065968",
                name=="lonny fish" ~ "201594",
                name=="kristyne sharpe" ~ "900050",
                name=="kim spackman" ~ "900051",
                T ~ supreme_court_nr
            )
    )

###################### Determine who is the prosecution vs. who is the defense.
lawyer_df_final <-
    lawyer_df_error_fixed_harmonized |>
    mutate(
        role =
            case_when(
                type %in%
                    c(
                        "district attorney", "assistant district attorney",
                        "attorney general", "complainant's attorney",
                        "special prosecutor"
                    ) ~ "prosecutor",
                type %in%
                    c(
                        "private", "public defender", "conflict counsel",
                        "court appointed - private", "legal aide", "co-counsel",
                        "court appointed", "court appointed - public defender",
                        "", "public defenders office", "standby - court appointed",
                        "montgomery county courthouse",
                        "montgomery cty courthouse",
                        "montgomery county public defender"
                    ) ~ "defense",
                type == "child advocate attorney" &
                    representing == "commonwealth of pennsylvania" ~ "prosecutor",
                type == "child advocate attorney" &
                    representing != "commonwealth of pennsylvania" ~ "defense",
                type == "certified legal intern" &
                    representing == "commonwealth of pennsylvania" ~ "prosecutor",
                type == "certified legal intern" &
                    representing != "commonwealth of pennsylvania" ~ "defense"
            ),
        supreme_court_nr =
            if_else(supreme_court_nr == "" | supreme_court_nr == "pubdef", NA_character_, supreme_court_nr),
        private_or_public =
            case_when(
                is.na(supreme_court_nr) | role == "prosecutor" ~ NA_character_,
                type %in%
                    c(
                        "private", "conflict counsel",  "court appointed",
                        "court appointed - private", "standby - court appointed"
                    ) & role == "defense" ~ "private",
                type %in% c("legal aide", "co-counsel") & role == "defense" ~ NA_character_,
                role == "defense" ~ "public"
            ),
        lawyer_nr = str_extract(L3, "[0-9]+")
    ) |>
    filter(
        (role == "prosecutor" & (representing == "commonwealth of pennsylvania" | is.na(representing))) |
        (role == "defense" & (representing != "commonwealth of pennsylvania") | is.na(representing))
    ) |>
    group_by(L1, supreme_court_nr) |>
    mutate(
        private_or_public =
            ifelse(
                # If the same lawyer is listed as public and private, list it as missing.
                length(unique(private_or_public)) > 1,
                NA_character_,
                unique(private_or_public)
            )
    ) |>
    ungroup() |>
    pivot_wider(
        id_cols = "L1",
        names_from = c("role", "lawyer_nr"),
        values_from = c("supreme_court_nr", "private_or_public")
    ) |>
    mutate(
        main_defense =
            coalesce(
                supreme_court_nr_defense_0, supreme_court_nr_defense_1,
                supreme_court_nr_defense_2, supreme_court_nr_defense_3,
                supreme_court_nr_defense_4, supreme_court_nr_defense_5,
                supreme_court_nr_defense_6, supreme_court_nr_defense_7
            ),
        main_prosecutor =
            coalesce(
                supreme_court_nr_prosecutor_0, supreme_court_nr_prosecutor_1,
                supreme_court_nr_prosecutor_2, supreme_court_nr_prosecutor_3,
                supreme_court_nr_prosecutor_4, supreme_court_nr_prosecutor_5,
                supreme_court_nr_prosecutor_6, supreme_court_nr_prosecutor_7
            ),
        main_defense_private_or_public =
            coalesce(
                private_or_public_defense_0, private_or_public_defense_1,
                private_or_public_defense_2, private_or_public_defense_3,
                private_or_public_defense_4, private_or_public_defense_5,
                private_or_public_defense_6, private_or_public_defense_7
            )
    ) |>
    mutate(
        any_private =
            pmap(
                across(starts_with("private_or_public")),
                function(...) {
                    x <- c(...)
                    x <- x[!is.na(x)]
                    x_test <- any(x == "private")
                }
            ) |>
            unlist(),
        defense_team =
            pmap(
                across(starts_with("supreme_court_nr_defense")),
                function(...) {
                    x <- c(...)
                    x <- x[!is.na(x)]
                    if(length(unique(x)) == 1) {
                        x[1]
                    } else {
                        paste(sort(x), collapse = "_")
                    }
                }
            ) |>
            unlist(),
        prosecutor_team =
            pmap(
                across(starts_with("supreme_court_nr_prosecutor")),
                function(...) {
                    x <- c(...)
                    x <- x[!is.na(x)]
                    if(length(unique(x)) == 1) {
                        x[1]
                    } else {
                        paste(sort(x), collapse = "_")
                    }
                }
            ) |>
            unlist(),
    ) |>
    relocate(
        "main_defense", "defense_team", "main_prosecutor", "prosecutor_team",
        .after = "L1"
    ) |>
    select(-matches("defense_[0-9]+|prosecutor_[0-9]+|private_or_public.*[0-9]+"))

################################################################################
# Save results.
################################################################################
write_csv(lawyer_df_final, here("output", "final_data", "ds_MJ_CR_lawyer.csv"))
