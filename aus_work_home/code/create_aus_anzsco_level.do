/*

This .do file assembles Australian data at the ANZSCO level. 

*/

* ------------------------------
* State and national data        
* ------------------------------
* Import data 
import excel "${raw_data}/1. Census 2016 Occupation Summary - Australia.xlsx", sheet("Total-State") clear cellrange(A9:V1871) firstrow

* Rename variables 
rename NewSouthWales geo_nsw  
rename Victoria geo_vic 
rename Queensland geo_qld 
rename SouthAustralia geo_sa 
rename WesternAustralia geo_wa 
rename Tasmania geo_tas 
rename NorthernTerritory geo_nt 
rename AustralianCapitalTerritory geo_act 
rename Australia geo_aus 
rename ANZSCO anzsco_code 
rename Occupation anzsco_text
keep geo_* anzsco_code anzsco_text

* Save
tempfile state_national_data
save `state_national_data'

* ------------------------------
* Industry data         
* ------------------------------
* Import data 
import excel "${raw_data}/1. Census 2016 Occupation Summary - Australia.xlsx", sheet("Industry") cellrange(B10:ABW1872) firstrow clear
rename B anzsco_code
keep anzsco_code AAgricultureForestryandFish BMining CManufacturing DElectricityGasWaterandWa ///
	EConstruction FWholesaleTrade GRetailTrade HAccommodationandFoodService ///
	ITransportPostalandWarehous JInformationMediaandTelecomm KFinancialandInsuranceServic ///
	LRentalHiringandRealEstate MProfessionalScientificandT NAdministrativeandSupportSer ///
	OPublicAdministrationandSafe PEducationandTraining QHealthCareandSocialAssista RArtsandRecreationServices SOtherServices

* Rename variables 	
rename AAgricultureForestryandFish ind_agri
rename BMining ind_mining 
rename CManufacturing ind_manuf 
rename DElectricityGasWaterandWa ind_elec_gas_water 
rename EConstruction ind_constr 
rename FWholesaleTrade ind_wholesale 
rename GRetailTrade ind_retail 
rename HAccommodationandFoodService ind_hosp 
rename ITransportPostalandWarehous ind_transp 
rename JInformationMediaandTelecomm ind_media 
rename KFinancialandInsuranceServic ind_finance
rename LRentalHiringandRealEstate ind_rent_hire_real_estate
rename MProfessionalScientificandT ind_science_tech 
rename NAdministrativeandSupportSer ind_admin 
rename OPublicAdministrationandSafe ind_public_admin
rename PEducationandTraining ind_educ
rename QHealthCareandSocialAssista ind_health 
rename RArtsandRecreationServices ind_arts 
rename SOtherServices ind_other 

* Save 
tempfile ind_data 
save `ind_data' 

* ------------------------------
* SA4 data          
* ------------------------------
* Import data
import excel "${raw_data}/1. Census 2016 Occupation Summary - Australia.xlsx", sheet("PT-FT-Met-Reg") cellrange(B11:DR1873) clear
rename B anzsco_code 
keep anzsco_code P-DR 

* Rename variables 
ds anzsco_code, not 
foreach var in `r(varlist)' {
	local name = "sa4" + "_" + substr(`var'[1], 1, 3)
	rename `var' `name'
}
drop if _n == 1

* Destring 
ds sa4_* 
foreach var in `r(varlist)' {
	destring `var', replace 
}

* Save 
tempfile sa4_data 
save `sa4_data' 

* ------------------------------
* Education data           
* ------------------------------
* Import data 
import excel "${raw_data}/1. Census 2016 Occupation Summary - Australia.xlsx", sheet("Age-HEAP-Sex") cellrange(B9:MW1873) clear
rename B anzsco_code 
keep anzsco_code MD-MK 

* Rename variables 
rename MD edu_postgrad1 
rename ME edu_postgrad2 
rename MF edu_postgrad3
rename MG edu_bach 
rename MH edu_dipcert1 
rename MI edu_dipcert2
rename MJ edu_dipcert3
rename MK edu_school 

keep if _n > 3 

* Destring 
ds edu_* 
foreach var in `r(varlist)' {
	destring `var', replace 
}

* Consolidate 
gen edu_postgrad = edu_postgrad1 + edu_postgrad2 + edu_postgrad3
drop edu_postgrad1 edu_postgrad2 edu_postgrad3 

gen edu_dipcert = edu_dipcert1 + edu_dipcert2 + edu_dipcert3 
drop edu_dipcert1 edu_dipcert2 edu_dipcert3

* Save 
tempfile edu_data 
save `edu_data' 

* ------------------------------
* Merge together            
* ------------------------------
use `state_national_data', clear 
merge 1:1 anzsco_code using `ind_data', assert(3) nogen  
merge 1:1 anzsco_code using `sa4_data', assert(3) nogen 
merge 1:1 anzsco_code using `edu_data', assert(3) nogen 

* ------------------------------
* Save            
* ------------------------------
save "${derived_data}/full_anzsco_data", replace  
