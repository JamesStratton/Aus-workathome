/*

This .do file is a master file for the full code. 

*/

* --------------------------------------------------
* Set relevant globals 
* --------------------------------------------------
global aus_work_home "/Users/Jimmy/Desktop/aus_work_home"
global raw_data  "${aus_work_home}/raw_data"
global derived_data "${aus_work_home}/derived_data"
global results "${aus_work_home}/results"
global code "${aus_work_home}/code"

* --------------------------------------------------
* Set graphing options  
* --------------------------------------------------
set scheme s1color 
global img pdf 

* --------------------------------------------------
* Run code  
* --------------------------------------------------
* Create Australian employment data at ANZSCO code level 
do "${code}/create_aus_anzsco_level.do"

* Clean Australian employment data at ANZSCO code level
do "${code}/clean_aus_anzsco_level.do"

* Crosswalk Australian employment data to ISCO code level 
do "${code}/crosswalk_aus_to_isco_level.do"

* Create teleworkable shares at ISCO code level 
do "${code}/telework_ISCO.do"

* Produce results 
do "${code}/produce_results.do"


* --------------------------------------------------
* Merge together Aus data with teleworkable shares 
* --------------------------------------------------
use "${data}aus_data_isco_state", clear 
merge 1:1 isco_code using "${data}teleworkable_isco_level" , assert(2 3) keep(3)
sum teleworkable [w = aus_employment]

* --------------------------------------------------
* Calculate share teleworkable in each state  
* --------------------------------------------------
foreach geo in nsw vic qld sa wa tas nt act aus {
	di "`geo'"
	sum teleworkable [w = `geo'_employment]
}

* ------------------------------
* Import ONET data from Dingel and Neiman 
* ------------------------------
* Import file 
import excel "${data}/dingel_neiman_telework_data.xlsx", sheet("Sheet1") firstrow clear

* Confirm structure 
isid onetsoccode 
assert !mi(teleworkable)  

* Note that there are no weights for eight-digit professions! 
	// see national_M2018_dl 
	// instead, stick to six digits 
drop if substr(onetsoccode, 9, 2) != "00" 
replace onetsoccode = substr(onetsoccode, 1, 7) 
rename onetsoccode soc_code 

* Save as tempfile 
keep soc_code teleworkable 
tempfile onet_data 
save `onet_data' 

* ------------------------------
* Merge in US national employment shares  
* ------------------------------
import excel "${data}/national_M2018_dl.xlsx", sheet("national_dl") firstrow clear
rename OCC_CODE soc_code 
rename TOT_EMP US_employment 
keep if OCC_GROUP == "detailed" 
isid soc_code 
keep soc_code US_employment 
merge 1:1 soc_code using `onet_data', keep(2 3) // only keep if there is teleworkable estimate available  

* Save as tempfile 
tempfile US_data 
save `US_data' 

* ------------------------------
* Merge to ISCO codes  
* ------------------------------
* Import crosswalk from ONET to ISCO 
import excel "${data}/ISCO_SOC_Crosswalk.xls", sheet("ISCO-08 to 2010 SOC") cellrange(A7:F1132) firstrow clear
rename SOCCode soc_code 
replace soc_code = subinstr(soc_code, " ", "", .)
replace ISCO08Code = subinstr(ISCO08Code," ","",.)
rename ISCO08Code isco_code  
rename ISCO08TitleEN isco_text 
keep soc_code isco_code isco_text

merge m:1 soc_code using `US_data', gen(_merge_2)
keep if !mi(teleworkable) 

* ------------------------------
* Collapse so that data are one row per ISCO code   
* ------------------------------
collapse (mean) teleworkable [w = US_employment], by(isco_code)
tempfile isco_teleworkable 
save `isco_teleworkable' 

/*
* ------------------------------
* Import data on Australian workers    
* ------------------------------
import excel "${data}/australian_occupations_matrix.xlsx", cellrange(A4:K725) firstrow clear 
duplicates drop 
rename EmploytNov2018000 aus_employment
rename Occupation anzsco_text 
keep aus_employment anzsco_text 
drop if mi(aus_employment) 
isid anzsco_text 
sort anzsco_text
replace anzsco_text = subinstr(anzsco_text, "and", "or", .)
gen bracket = strpos(anzsco_text, "(") 
replace anzsco_text = substr(anzsco_text, 1, bracket - 3)

tempfile aus_worker_data 
save `aus_worker_data' 

* ------------------------------
* Import data on ISCO codes     
* ------------------------------
import excel "${data}/1220.0 ANZSCO Correspondence to ISCO-08 v2.xls", sheet("ANZSCO Version 1.2 to ISCO-08") cellrange(A9:C1286) clear
rename A anzsco_code 
rename B anzsco_text 
rename C isco_code 
drop if mi(isco_code) 
isid anzsco_code isco_code

merge m:1 anzsco_text using `aus_worker_data'
*/

* ------------------------------
* Import data on Australian workers      
* ------------------------------
import excel "/Users/Jimmy/Downloads/1. Census 2016 Occupation Summary - Australia.xlsx", sheet("Total-State") clear cellrange(A9:V1871) firstrow

* Check that sum of categories matches total employment 
sum Australia if length(ANZSCO) == 6 
local aus_listed_values = `r(sum)' 
sum Australia if UIDANZSCO == "&&&&&& Not stated"
assert `r(N)' == 1 
local aus_unlisted_values = `r(mean)'
local aus_total = `aus_listed_values' + `aus_unlisted_values'
di `aus_total'
sum Australia if UIDANZSCO == "0 Total Employed"
assert `r(N)' == 1 
assert inrange(`aus_total', 0.99 * `r(mean)', 1.01 * `r(mean)')

* Keep relevant data 
keep if length(ANZSCO) == 6 
rename ANZSCO anzsco_code 
rename Occupation anzsco_text 
rename Australia aus_employment 
keep anzsco_code anzsco_text aus_employment

* Check structure 
isid anzsco_code 

* Six-digit ANZSCO codes should not end in zero; only NFD 
assert substr(anzsco_code, 5, 2) == "00" if  substr(anzsco_text, -3, 3) == "nfd" 
assert substr(anzsco_text, -3, 3) == "nfd" if substr(anzsco_code, 5, 2) == "00" 

* Distribute NFD over rest in category 
forvalues i = 1/4 {
	local remaining_digits = 6 - `i'
	local zeros = substr("00000", 1, `remaining_digits')
	local start_pos = `i' + 1 
	gen code_is_`i'_dig = (substr(anzsco_code, `start_pos', `remaining_digits') == "`zeros'") 
}

forvalues i = 1/4 {
	gen code_`i'_dig = substr(anzsco_code, 1, `i') 
}

sum aus_employment 
local employment = `r(sum)'

forvalues i = 1/4 {
	gen to_distribute_`i' = aus_employment if code_is_`i'_dig == 1
	egen total_to_distribute_`i' = sum(to_distribute_`i'), by(code_`i'_dig)
	egen total_`i' = sum(aus_employment) if code_is_`i'_dig == 0, by(code_`i'_dig) 
	gen share_`i' = aus_employment/total_`i' 
	replace aus_employment = aus_employment + share_`i' * total_to_distribute_`i' if !mi(total_to_distribute_`i')
	drop if code_is_`i'_dig == 1 
	di `employment' 
	sum aus_employment 
	di `r(sum)'
	assert inrange(`r(sum)', `employment' * 0.99, `employment' * 1.01)
}

* Save as tempfile 
tempfile aus_worker_data 
save `aus_worker_data' 

* Crosswalk to ISCO codes 
import excel "${data}/1220.0 ANZSCO Correspondence to ISCO-08 v2.xls", sheet("ANZSCO Version 1.2 to ISCO-08") cellrange(A9:C1286) clear
rename A anzsco_code 
rename B anzsco_text 
rename C isco_code 
drop if mi(isco_code) 
isid anzsco_code isco_code
keep anzsco_code isco_code 
merge m:1 anzsco_code using `aus_worker_data'

* Distribute labourers NEC over rest in category 
gen labourer = strpos(anzsco_text, "Labourer") > 0 
egen total_labourer = sum(aus_employment) if labourer == 1 
gen share_labourer = aus_employment/total_labourer 
gen to_distribute_labourer = aus_employment if anzsco_text == "Labourers nec"
egen total_to_distribute_labourer = max(to_distribute_labourer), by(labourer)
gen test = share_labourer * total_to_distribute_labourer if !mi(total_to_distribute_labourer)
replace aus_employment = aus_employment + share_labourer * total_to_distribute_labourer if !mi(total_to_distribute_labourer)
drop if anzsco_text == "Labourers nec"

* Deal with other merge fails 


merge m:1 isco_code using `isco_teleworkable', gen(_merge_3)

e 


 

import delimited "/Users/Jimmy/Downloads/occupations_suburbs.csv", encoding(ISO-8859-1)clear
drop if _n <= 7 
rename v1 geography 
keep if geography == "Total" | geography == "OCCP - 4 Digit Level"
sxpose, clear force 
rename _var1 ANZSCO_text 
