/*

This .do file crosswalks teleworkable measures from O*NET/SOC occupation codes 
to ISCO occupation codes. 

*/


* ------------------------------
* Import ONET data from Dingel and Neiman 
* ------------------------------
* Import file 
import excel "${raw_data}/dingel_neiman_telework_data.xlsx", sheet("Sheet1") firstrow clear

* Confirm structure 
isid onetsoccode 
assert !mi(teleworkable)  

* Note that there are no weights for eight-digit professions! 
	// see national_M2018_dl 
	// instead, stick to six digits 
drop if substr(onetsoccode, 9, 2) != "00" 
replace onetsoccode = substr(onetsoccode, 1, 7) 
rename onetsoccode soc_code 
rename title onet_title 

* Save as tempfile 
keep soc_code teleworkable onet_title 
tempfile onet_data 
save `onet_data' 

* ------------------------------
* Import US national employment shares  
* ------------------------------
	// We are doing this because we want to collapse to the ISCO level, and 
	// we need to get the right weights for that collapse. 
import excel "${raw_data}/national_M2018_dl.xlsx", sheet("national_dl") firstrow clear
rename OCC_CODE soc_code 
rename TOT_EMP us_employment 
keep if OCC_GROUP == "detailed" 
rename OCC_TITLE soc_text  
isid soc_code 
keep soc_code soc_text us_employment 

* ------------------------------
* Merge together US data 
* ------------------------------
* First merge 
merge 1:1 soc_code using `onet_data', gen(soc_onet_merge)  

* Note that "all other" codes are only in employment data, not telework data; 
	// distribute over all with same first five digits, according to weight  
gen all_other = strpos(soc_text, "All Other") > 0  
assert soc_onet_merge == 1 if all_other == 1  
gen first_five = substr(soc_code, 1, 6)
gen other_employment = us_employment if all_other == 1 
egen to_distribute_all_other = sum(other_employment), by(first_five) 
egen total_first_five = sum(us_employment) if all_other != 1, by(first_five)
gen share_first_five = us_employment/total_first_five
replace us_employment = us_employment + share_first_five * to_distribute_all_other if !mi(to_distribute_all_other) 
drop if all_other == 1 

* Where missing telework, take category share telework  
egen five_digit_category_mean = wtmean(teleworkable), weight(us_employment) by(first_five)
egen five_digit_category_sd = sd(teleworkable), by(first_five)
replace teleworkable = five_digit_category_mean if mi(teleworkable) 

gen first_four = substr(soc_code, 1, 5)
egen four_digit_category_mean = wtmean(teleworkable), weight(us_employment) by(first_four)
egen four_digit_category_sd = sd(teleworkable), by(first_four)
replace teleworkable = four_digit_category_mean if mi(teleworkable)

* Deal specifically with some occupations  
sum teleworkable if onet_title == "Tour Guides and Escorts" | onet_title == "Travel Guides" 
assert `r(mean)' == 0 
assert mi(teleworkable) if soc_text == "Tour and Travel Guides"
replace teleworkable = 0 if soc_text == "Tour and Travel Guides"

sum teleworkable if soc_text == "Farmworkers, Farm, Ranch, and Aquacultural Animals"
assert `r(mean)' == 0 
assert mi(teleworkable) if soc_text == "First-Line Supervisors of Farming, Fishing, and Forestry Workers"
replace teleworkable = 0 if soc_text == "First-Line Supervisors of Farming, Fishing, and Forestry Workers"

* Check to see that no longer missing 	
assert !mi(teleworkable) 

* Save 
replace soc_text = onet_title if mi(soc_text) 
keep teleworkable soc_text soc_code us_employment 
tempfile us_data 
save `us_data' 

* ------------------------------
* Merge ISCO codes  
* ------------------------------
* Import crosswalk from ONET to ISCO 
import excel "${raw_data}/ISCO_SOC_Crosswalk.xls", sheet("ISCO-08 to 2010 SOC") cellrange(A7:F1132) firstrow clear
rename SOCCode soc_code 
replace soc_code = subinstr(soc_code, " ", "", .)
replace ISCO08Code = subinstr(ISCO08Code," ","",.)
rename ISCO08Code isco_code  
rename ISCO08TitleEN isco_text 
keep soc_code isco_code isco_text

* Merge together 
merge m:1 soc_code using `us_data', gen(isco_soc_merge)

* Exclude military occupations 
gen military = strpos(isco_text, "armed") > 0 
replace military = 1 if strpos(isco_text, "Armed") > 0 
assert isco_soc_merge == 1 if military == 1 
drop if military == 1

* Replace with mean from category where missing 
gen first_four_isco = substr(isco_code, 1, 4)
egen mean_first_four_isco = wtmean(teleworkable), weight(us_employment) by(first_four_isco) 
replace teleworkable = mean_first_four_isco if mi(teleworkable)

gen first_three_isco = substr(isco_code, 1, 3)
egen mean_first_three_isco = wtmean(teleworkable), weight(us_employment) by(first_three_isco) 
replace teleworkable = mean_first_three_isco if mi(teleworkable)

gen first_two_isco = substr(isco_code, 1, 2)
egen mean_first_two_isco = wtmean(teleworkable), weight(us_employment) by(first_two_isco) 
replace teleworkable = mean_first_two_isco if mi(teleworkable)

drop if mi(isco_code)
assert !mi(teleworkable)

* Dummy for US employment 
replace us_employment = 0.01 if mi(us_employment) 

* ------------------------------
* Collapse to level of ISCO code   
* ------------------------------
collapse (mean) teleworkable [w = us_employment], by(isco_code) 
save "${derived_data}/teleworkable_isco_level", replace 
