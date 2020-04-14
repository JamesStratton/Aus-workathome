use "${results}/shares_by_edu", clear 
sort teleworkable 
gen pos = _n 
assert pos == 1 if level == "edu_school"
assert pos == 2 if level == "edu_dipcert"
assert pos == 3 if level == "edu_bach"
assert pos == 4 if level == "edu_postgrad"

replace teleworkable = 100 * teleworkable

tw ///
	(bar teleworkable pos, barwidth(0.5) color(dkgreen)) /// 
	, /// 
	ytitle("Share of Jobs Able to be Completed From Home (%)") /// 
	xlabel(1 `" "No Post-Secondary" "Qualifications" "' 2 `" "Diploma/Certificate" "Completion" "' 3 `" "Bachelor's" "Completion" "' 4 `" "Postgraduate" "Completion" "', labsize(small)) ///
	graphregion(color(white)) bgcolor(white) /// 
	xtitle("Educational Attainment Level of Job Holder") /// 
	ylab(0(20)80, nogrid)
graph export "${results}/education graph.pdf", as(pdf) replace 
