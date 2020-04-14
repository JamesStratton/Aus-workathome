/*

This .do file preserves exactly the code used in Dingel and Neiman to 
verify that the results are similar when using two-digit ISCO codes for Australia. 
The only code that is added is (1) an added section under the heading 
"Rearrange Australian data to be at two-digit ISCO level", (2) an added line under 
the heading "Load and clean ILO data on 2-digit ISCO employment by country", and 
(3) and added section under the heading "Take mean". 

*/


clear

// === Rearrange Australian data to be at two-digit ISCO level ===

//Collapse to two-digit ISCOs 
use "${derived_data}/long_aus_data", clear 
keep if level == "geo_aus"
gen ISCO08_Code_2digit = substr(isco_code, 1, 2)
collapse (sum) employment, by(ISCO08_Code_2digit) 
rename employment obs_value
replace obs_value = obs_value/1000  

//Add total, unclassified, and ISCO code 63 
count 
local count_plus_one = `r(N)' + 1
local count_plus_two = `r(N)' + 2
local count_plus_three = `r(N)' + 3
set obs `count_plus_three'
replace ISCO08_Code_2digit = "63"  in `count_plus_one'
replace obs_value = 0 if ISCO08_Code_2digit == "63"  
gen classif1 = "OC2_ISCO08_" + ISCO08_Code_2digit
replace classif1 = "OC2_ISCO08_X"  in `count_plus_two'
sum obs_value 
replace obs_value = ${aus_tot_emp}/1000 - `r(sum)'  in `count_plus_two'
replace classif1 = "OC2_ISCO08_TOTAL"  in `count_plus_three'
replace obs_value = ${aus_tot_emp}/1000 if classif1 == "OC2_ISCO08_TOTAL" 
gen time = 2016 
gen obs_status = ""
gen obs_status_label = "" 
gen note_indicator = "" 
gen note_source = "Compiled by James Stratton from Australian Bureau of Statistics ANZSCO data"
gen note_source_label = ""
drop ISCO08_Code_2digit 

//Replicate structure of spreadsheet 
gen ïref_area = "AUS"
gen ref_arealabel = "Australia" 
gen source_label = "AUS - ABS - Census"
gen indicator_label = "Employment by sex and occupation - ISCO level 2 (thousands)"
gen sex = "SEX_T"
gen sex_label = "Sex: Total"

//Save 
save "${results}/two_digit_aus_data", replace 

// === Generate 6-digit SOC to 2-digit ISCO crosswalk ===

//2-digit ISCO code and title
import delimited using "${raw_data}/ilostat-2020-04-12.csv", clear
keep classif1 classif1label
duplicates drop


drop if inlist(classif1,"OC2_ISCO08_TOTAL","OC2_ISCO08_X")==1 
drop if strpos(classif1,"OC2_ISCO08")==0

gen ISCO08_TITLE_2digit= subinstr(classif1label,"Occupation (ISCO-08), 2 digit level: ","",1)
assert substr(classif1,-2,2) == substr(ISCO08_TITLE_2digit,1,2)
gen ISCO08_Code_2digit = substr(classif1,-2,2)
keep ISCO08_Code_2digit ISCO08_TITLE_2digit
compress
tempfile ISCO08_2digit
save `ISCO08_2digit'

//SOC to ISCO Crosswalk
import excel using "${raw_data}/ISCO_SOC_Crosswalk.xls", cellrange(A7:E1132) firstrow clear
drop part
gen SOC_2010 = trim(SOCCode)
gen str ISCO08_Code_2digit = substr(ISCO08Code,1,2)
keep ISCO08_Code_2digit SOC_2010 SOCTitle
duplicates drop
merge m:1 ISCO08_Code_2digit using `ISCO08_2digit', assert(match) keepusing(ISCO08_TITLE_2digit) nogen

tempfile ISCO_2digit_SOC_Crosswalk
save `ISCO_2digit_SOC_Crosswalk' //This mapping is many (2-digit 2008 ISCO) to many (6-digit 2010 SOC)

// === Generate 2018 OES code to 6-digit SOC crosswalk ===

import excel using "${raw_data}/oes_2019_hybrid_structure.xlsx", sheet(OES2019 Hybrid) cellrange(A6:H874) clear firstrow
rename (OES2018EstimatesCode OES2018EstimatesTitle) (OES_2018 OES_TITLE)
rename (G H) (SOC_2010 SOC_TITLE)
replace OES_TITLE = trim(OES_TITLE)
keep OES_2018 OES_TITLE SOC_2010 SOC_TITLE
duplicates drop
tempfile OES_SOC_temp
bys SOC_2010: egen total = total(1)
assert total==1 | SOC_2010=="25-3099" //This is many (SOC_2010) to one (OES_2018) except for SOC=25-3099 (misc teachers)
list if SOC_2010=="25-3099" //OES distinguishes between substitute teachers and others
replace SOC_2010 = OES_2018 if SOC_2010 == "25-3099" //This makes the SOC_2010 values in this crosswalk unique.
keep OES_2018 OES_TITLE SOC_2010 SOC_TITLE
save `OES_SOC_temp'


// === Generate 2018 OES code to 2-digit ISCO crosswalk ===
use "`ISCO_2digit_SOC_Crosswalk'", clear
drop if substr(SOC_2010,1,3)=="55-" //Drops military occupations
merge m:1 SOC_2010 using `OES_SOC_temp'
assert inlist(SOC_2010,"25-3099","25-3097","25-3098") if _merge!=3
replace ISCO08_TITLE_2digit = "23 - Teaching professionals" if inlist(OES_2018,"25-3097","25-3098") & _merge==2 & missing(ISCO08_Code_2digit)==1
replace ISCO08_Code_2digit = "23" if inlist(OES_2018,"25-3097","25-3098") & _merge==2 & missing(ISCO08_Code_2digit)==1
drop if _merge==1
drop _merge
keep ISCO08_Code_2digit ISCO08_TITLE_2digit OES_2018 OES_TITLE
duplicates drop
sort OES_2018
clonevar OCC_CODE = OES_2018
tempfile OES_ISCO_2digit_Crosswalk
save `OES_ISCO_2digit_Crosswalk' //This mapping is many (OES_2018 / OCC_CODE) to many (ISCO08_Code)

// ===  Construct country-level teleworkability index === 

//Load US OES employment counts to use as weights; map to 2-digit ISCO
import excel using "${raw_data}/national_M2018_dl.xlsx", firstrow clear
keep if OCC_GROUP=="detailed"
merge 1:m OCC_CODE using `OES_ISCO_2digit_Crosswalk', keep(3) nogen
merge m:1 OCC_CODE using "${raw_data}/onet_teleworkable_blscodes.dta", keep(1 3) nogen

keep OCC_CODE OCC_TITLE TOT_EMP ISCO08_Code ISCO08_TITLE teleworkable
rename TOT_EMP USA_OES_employment
tempfile oes_isco2_merged_file
save `oes_isco2_merged_file' //This file is many-to-many

//Load and clean ILO data on 2-digit ISCO employment by country
import delim using "${raw_data}/ilostat-2020-04-12.csv", clear
append using "${results}/two_digit_aus_data" 
rename ïref_area ref_area 
rename (ref_area ref_arealabel time obs_value) (country_code country year employment)
assert inlist(substr(classif1,1,10),"OC2_ISCO88","OC2_ISCO08")
bys country_code: egen int year_max = max(year)
assert year<=year_max
keep if year==year_max & sex == "SEX_T" //Use most recent year of data and disregard sex
assert inlist(country_code,"BWA","CRI","IDN","IND","KOS","NAM","NGA","NIC","PNG") | inlist(country_code,"TUN","TZA", "VNM", "YEM", "ZAF") if substr(classif1,1,10) != "OC2_ISCO08"
drop if substr(classif1,1,10) != "OC2_ISCO08" //Drop 14 countries using older ISCO codes in their most recent year
tempvar tv1 tv2
bys country_code year: egen `tv1' = max((classif1=="OC2_ISCO08_X")*employment)
by  country_code year: egen `tv2' = max((classif1=="OC2_ISCO08_TOTAL")*employment)
gen unallocated_employment_share = `tv1'/`tv2'
drop `tv1' `tv2'
drop if inlist(classif1,"OC2_ISCO08_TOTAL","OC2_ISCO08_X")==1
gen ISCO08_Code_2digit = substr(classif1,-2,2)
gen ISCO08_TITLE_2digit= subinstr(classif1label,"Occupation (ISCO-08), 2 digit level: ","",1)
drop if inlist(ISCO08_Code_2digit,"01","02","03") // Drop military occupations

//Join ISCO 2-digit employment with US-based telework scores and OES employment weights
joinby ISCO08_Code_2digit using `oes_isco2_merged_file', unmatched(both)
assert _merge==3 // if ISCO08_TITLE_2digit != "63 - Subsistence farmers, fishers, hunters and gatherers"
egen tag = tag(country_code year OCC_CODE ISCO08_Code)
assert tag!=0
drop _merge tag

//Aggregate 6-digit SOC telework scores to country-specific 2-digit ISCO scores
bys country_code year OCC_CODE: egen tot_emp_occ = total(employment) if missing(employment)==0 & employment!=0
gen weight = USA_OES_employment*employment/tot_emp_occ	if missing(employment)==0 & employment!=0 //Allocates SOC's employment across ISCOs in proportion to ISCO employment shares
collapse (mean) teleworkable (firstnm) emp country ISCO08_TITLE_2digit unallocated_employment_share [aweight = weight], by(country_code year ISCO08_Code)

//Take mean  
collapse teleworkable [w = employment], by(country) 
save "${results}/two-digit ISCO mean.dta", replace 
