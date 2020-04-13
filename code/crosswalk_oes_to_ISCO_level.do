/*

This .do file is a slightly adapted version of "country_level_measures.do", created by Dingel and Neiman. 
The file differs in three ways: 
	(1) I crosswalk to four-digit ISCO codes, rather than two-digit ISCO codes. 
		This has a small number of consequences for merges throughout. 
	(2) Dingel and Neiman use an international dataset that is long on country x year x ISCO, 
		whereas I use an Australian dataset that is long on level (e.g. national, state, etc.) x ISCO. 

*/


* ------------------------------
* Prepare SOC to ISCO crosswalk  
* ------------------------------
import excel "${raw_data}/ISCO_SOC_Crosswalk.xls", sheet("ISCO-08 to 2010 SOC") cellrange(A7:F1132) firstrow clear
drop part
gen SOC_2010 = trim(SOCCode)
gen ISCO08_Code = trim(ISCO08Code) 
rename ISCO08TitleEN ISCO08Title 
keep ISCO08_Code SOC_2010 SOCTitle ISCO08Title 
isid ISCO08_Code SOC_2010

drop if substr(SOC_2010,1,3)=="55-" //Drops military occupations


tempfile ISCO_4_digit_SOC_Crosswalk 
save `ISCO_4_digit_SOC_Crosswalk' 

* ------------------------------
* Generate 2018 OES code to 6-digit SOC crosswalk   
* ------------------------------
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
isid SOC_2010
keep OES_2018 OES_TITLE SOC_2010 SOC_TITLE
save `OES_SOC_temp'

* ------------------------------
* Generate 2018 OES code to 4-digit ISCO crosswalk   
* ------------------------------
use "`ISCO_4_digit_SOC_Crosswalk'", clear
drop if substr(SOC_2010,1,3)=="55-" //Drops military occupations
merge m:1 SOC_2010 using `OES_SOC_temp'
assert inlist(SOC_2010,"25-3099","25-3097","25-3098") if _merge!=3

replace ISCO08Title = "23 - Teaching professionals" if inlist(OES_2018,"25-3097","25-3098") & _merge==2 & missing(ISCO08_Code)==1
replace ISCO08_Code = "2359" if inlist(OES_2018,"25-3097","25-3098") & _merge==2 & missing(ISCO08_Code)==1
drop if _merge==1
drop _merge
keep ISCO08_Code ISCO08Title OES_2018 OES_TITLE
duplicates drop
sort OES_2018
clonevar OCC_CODE = OES_2018
tempfile OES_ISCO_4digit_Crosswalk
save `OES_ISCO_4digit_Crosswalk' //This mapping is many (OES_2018 / OCC_CODE) to many (ISCO08_Code)

* ------------------------------
* Load US OES employment counts as weights; map to 4-digit ISCO    
* ------------------------------
* Load US employment counts 
import excel using "${raw_data}/national_M2018_dl.xlsx", firstrow clear
keep if OCC_GROUP=="detailed"

* Merge to OES codes 
merge 1:m OCC_CODE using `OES_ISCO_4digit_Crosswalk'

* Confirm only a small number unmerged 
assert inlist(OES_TITLE, "Fishers and Related Fishing Workers", "Hunters and Trappers") if _merge != 3 
drop if _merge != 3 
drop _merge 

* Merge to teleworkable scores 
merge m:1 OCC_CODE using "${raw_data}/onet_teleworkable_blscodes.dta", keep(1 3) nogen

keep OCC_CODE OCC_TITLE TOT_EMP ISCO08_Code ISCO08Title teleworkable
rename TOT_EMP USA_OES_employment
tempfile oes_isco4_merged_file
save `oes_isco4_merged_file' //This file is many-to-many

* ------------------------------
* Load Australian data on 4-digit employment, split by level    
* ------------------------------
use "${derived_data}/long_aus_data", replace 
gen ISCO08_Code_2digit = substr(isco_code,1,2)
drop if inlist(ISCO08_Code_2digit,"01","02","03") // Drop military occupations
rename isco_code ISCO08_Code

//Join ISCO 2-digit employment with US-based telework scores and OES employment weights
joinby ISCO08_Code using `oes_isco4_merged_file', unmatched(both)

* Confirm that all Australian occupations are matched 
assert inlist(_merge, 2, 3)  

* Confirm that only a small number of codes in the ISCO/OES crosswalk have no Australian records 
assert inlist(ISCO08Title, "Traditional chiefs and heads of villages", "Physical and earth science professionals", ///
	"Paramedical practitioners", "Ship and aircraft controllers and technicians", "Subsistence crop farmers") ///
	| inlist(ISCO08Title, "Subsistence livestock farmers", "Subsistence mixed crop and livestock farmers", "Drivers of animal-drawn vehicles and machinery", ///
	"Street and related service workers", "Water and firewood collectors") if _merge != 3 
drop if _merge != 3 	
egen tag = tag(level OCC_CODE ISCO08_Code)
assert tag!=0
drop _merge tag

//Aggregate 6-digit SOC telework scores to country-specific 4-digit ISCO scores
bys level OCC_CODE: egen tot_emp_occ = total(employment) if missing(employment)==0 & employment!=0
gen weight = USA_OES_employment*employment/tot_emp_occ	if missing(employment)==0 & employment!=0 //Allocates SOC's employment across ISCOs in proportion to ISCO employment shares

* ------------------------------
* Collapse to level x ISCO means     
* ------------------------------
collapse (mean) teleworkable (firstnm) employment [aweight = weight], by(level ISCO08_Code)

* ------------------------------
* Output      
* ------------------------------
save "${derived_data}/telework_shares", replace 
