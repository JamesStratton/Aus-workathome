use "${results}/shares_by_ind", clear 

sort teleworkable 
drop if level == "ind_other" 

gen pos = _n 
gen zero = 0 
gen hundred = 100 

replace teleworkable = 100 * teleworkable 

* Assert order 
gen order = _n 
assert level == "ind_hosp" if order == 1 
assert level == "ind_agri" if order == 2
assert level == "ind_constr" if order == 3 
assert level == "ind_mining" if order == 4 
assert level == "ind_manuf" if order == 5 
assert level == "ind_health" if order == 6 
assert level == "ind_transp" if order == 7 
assert level == "ind_retail" if order == 8 
assert level == "ind_admin" if order == 9 
assert level == "ind_elec_gas_water" if order == 10
assert level == "ind_public_admin" if order == 11
assert level == "ind_arts" if order == 12 
assert level == "ind_wholesale" if order == 13 
assert level == "ind_rent_hire_real_estate" if order == 14 
assert level == "ind_media" if order == 15 
assert level == "ind_finance" if order == 16 
assert level == "ind_science_tech" if order == 17 
assert level == "ind_educ" if order == 18 

* Make graph 
tw ///
	(rbar zero teleworkable pos, barwidth(0.5) color(dkgreen) horiz) /// 
	, /// 
	ylabel(18 "Education" 17 "Science & Technology" 16 "Finance" 15 "Rental, Hire, Real Estate" 14 "Media" ///
		13 "Wholesale" 12 "Arts" 11 "Public Administration" 10 "Electric., Gas, Water" 9 "Administration" /// 
		8 "Retail" 7 "Manufacturing" 6 "Transport" 5 "Health" 4 "Mining" 3 "Construction" 2 "Agriculture" /// 
		1 "Hospitality", angle(0) nogrid) ///
	xlabel(0(20)100, nogrid) /// 
	legend(off) /// 
	ytitle("") /// 
	xtitle("Share of Jobs Able to be Completed From Home (%)") /// 
	graphregion(color(white)) bgcolor(white)
graph export "${results}/industry graph.pdf", as(pdf) replace 
