**   Partner Performance
**   FY1&
**   Aaron Chafetz
**   Purpose: project out APR results 
**   Updated: July 27, 2017

/* NOTES
	- builds off structure of PPR base dataset
	- Data source: ICPI_Fact_View_OU_IM
	- run 00_initialize prior to using this do file
	- requires 06_partnerreport_officalnames to be saved in project folder
*/

********************************************************************************

** INITIAL SETUP **

	*set today's date for saving
		global date = subinstr("`c(current_date)'", " ", "", .)
		
	*set date of frozen instance - needs to be changed w/ updated data
		global datestamp "20170702_v2_1"
		
	*import/open data
		use "$fvdata/ICPI_FactView_OU_IM_${datestamp}.dta", clear

	
** WRANGLING **
	
	*keep only relevant indicators for analysis
		keep if ///
			inlist(indicator, "HTS_TST", "HTS_TST_POS", "TX_NEW", "TX_CURR", ///
			"TX_NET_NEW", "PMTCT_STAT") & disaggregate=="Total Numerator"
	
	*add future quarters in 
		foreach x in q2 q3 q4 apr{
			capture confirm variable fy2017`x'
			if _rc gen fy2017`x' = .
			}
			*end
			
	*create cumulative variable to sum up necessary variables
		egen fy2017cum = rowtotal(fy2017q*)
			replace fy2017cum = . if fy2017cum==0
		*adjust "snapshot" indicators since they are already cumulative
		local i 2 
		replace fy2017cum = fy2017q`i' if inlist(indicator, "OVC_SERV", ///
			"TX_CURR")
		replace fy2017cum =. if fy2017cum==0 //should be missing, but 0 due to egen

	*remove rows with no data (ie keep rows that contain FY16/17 data)
		egen kp = rowtotal(fy2016q1 fy2016q2 fy2016q3 fy2016q4 fy2016_targets ///
			fy2017q1 fy2017q2 fy2017_targets)
			drop if kp==0
			drop kp
			
	*update all partner and mech to offical names (based on FACTS Info)
		*tostring mechanismid, replace
		preserve
		run 06_partnerreport_officalnames
		restore
		merge m:1 mechanismid using "$output/officialnames.dta", ///
			update replace nogen keep(1 3 4 5) //keep all but non match from using
		
	*aggregate so there is only one obvervation per mechanism
		collapse (sum) fy*, by(operatingunit primepartner fundingagency ///
			mechanismid implementingmechanismname indicator)

	*remove cumulative and targets to be added back in later
		preserve
		keep operatingunit primepartner fundingagency mechanismid ///
			implementingmechanismname indicator *targets *apr *cum
		recode *targets *apr *cum (0 = .)

		save "$output/extradata.dta", replace
		restore
		drop *targets *apr *cum
		
		
** PROJECTIONS **

	*reshape long to allow dataset to become a timeseries & transform time variable to date format
		egen id = group(operatingunit primepartner fundingagency mechanismid ///
			implementingmechanismname indicator)
		reshape long fy, i(id) j(qtr, string)
		drop id
		
	*recode 0s to missing due to earlier collapse
		recode fy (0 = .)
		
	*identify groupings for timeseries
		gen qdate = quarterly(qtr, "YQ")
		egen pnl = group(operatingunit primepartner fundingagency mechanismid ///
			implementingmechanismname indicator)
		egen ind = group(operatingunit indicator)
		
	*identify dataset as timeseries
		tsset pnl qdate

	*create growth rate to moving average from - (pd_current-pd_prior)/pd_prior
		gen gr = D.fy/L.fy

	*format date
		format qdate %tq

	*create moving average for projection
		* moving average from prior 6 quarters
		* FY16Q1 - 224, FY17Q3 - 230, FY17Q4 - 231
		* FY17Q3 moving average
		bysort pnl: egen avg_gr = mean(gr) if inrange(qdate,224,231) //moving average mech/ind over past 6 quarters
			replace avg_gr = . if !inlist(qdate, 230, 231) //remove ma from other quaters
		bysort ind: egen avg_gr_overall = mean(gr) if inrange(qdate,224,231) //average ind growth over past 6 quarters if mech doesn't have data
			replace avg_gr_overall = . if !inlist(qdate, 230, 231)
			replace avg_gr = avg_gr_overall if avg_gr== . & inlist(qdate, 230, 231)
			
	*sort variables and add projected FYQ3 and Q4 data using moving average
		sort pnl qdate indicator
		replace fy = round((1+ avg_gr)*L.fy, 1) if inlist(qdate, 230, 231)

	*drop variables created in process
		drop qdate ind gr avg_gr_overall
		replace avg_gr = round(avg_gr, .001)
	*reshape back to original fact view setup
		reshape wide fy avg_gr, i(pnl) j(qtr, string)
		rename avg_gr2017q3 avg_gr
		ds avg_gr2*
		drop `r(varlist)' pnl
		order operatingunit-indicator

	*merge targets and cumulative variables back in and reorder
		merge 1:1 operatingunit primepartner fundingagency mechanismid ///
			implementingmechanismname indicator using "$output/extradata.dta", nogen
		order fy2015apr fy2016_targets, after(fy2015q4)
		order fy2016apr fy2017_targets, after(fy2016q4)
		order avg_gr, after(fy2017cum)
		
	*create APR variable
		egen fy2017apr_p = rowtotal(fy2017q1 fy2017q2 fy2017q3 fy2017q4)
			replace fy2017apr_p = fy2017q4 if inlist(indicator, "TX_CURR", "OVC_SERV")
			replace fy2017apr = fy2017apr_p
			drop fy2017apr_p
			recode fy2017apr (0 = .)	
		
		
** TX_NET_NEW **

	*duplicate TX_CURR rows & rename as NET_NEW
		expand 2 if indicator== "TX_CURR", gen(new) //create duplicate of TX_CURR
			replace indicator= "TX_NET_NEW" if new==1 //rename duplicate TX_NET_NEW
			drop new
	*create copy periods to replace "." w/ 0 for generating net new (if . using in calc --> answer == .)
		foreach x in fy2015q2 fy2015q4 fy2016q2 fy2016q4 fy2017q1 fy2017q2 fy2017q3 fy2017q4 fy2017_targets{
			clonevar `x'_cc = `x'
			recode `x'_cc (. = 0) 
			}
			*end
	*create net new variables (tx_curr must be reporting in both pds)
		gen fy2015q4_nn = fy2015q4_cc-fy2015q2_cc
			replace fy2015q4_nn = . if (fy2015q4==. & fy2015q2==.)
		gen fy2016q2_nn = fy2016q2_cc-fy2015q4_cc
			replace fy2016q2_nn = . if (fy2016q2==. & fy2015q4==.)
		gen fy2016q4_nn = fy2016q4_cc-fy2016q2_cc
			replace fy2016q4_nn = . if (fy2016q4==. & fy2016q2==.)
		egen fy2016apr_nn = rowtotal(fy2016q2_nn fy2016q4_nn)
		gen fy2017q1_nn = fy2017q1_cc-fy2016q4_cc
			replace fy2017q1_nn = . if (fy2017q1==. & fy2016q4==.)
		gen fy2017q2_nn = fy2017q2_cc-fy2017q1_cc
			replace fy2017q2_nn = . if (fy2017q2==. & fy2017q1==.)
		gen fy2017q3_nn = fy2017q3_cc-fy2017q2_cc
			replace fy2017q3_nn = . if (fy2017q3==. & fy2017q2==.)	
		gen fy2017q4_nn = fy2017q4_cc-fy2017q3_cc
			replace fy2017q4_nn = . if (fy2017q4==. & fy2017q3==.)	
		gen fy2017_targets_nn = fy2017_targets_cc - fy2016q4_cc
			replace fy2017_targets_nn = . if fy2017_targets==. & fy2016q4==.
		egen fy2017apr_nn = rowtotal(fy2017q1_nn fy2017q2_nn fy2017q3_nn fy2017q4_nn)
		drop *_cc
		
	*replace raw period values with generated net_new values
		foreach x in fy2015q4 fy2016q2 fy2016q4 fy2016apr fy2017q1 fy2017q2 fy2017q3 fy2017q4 fy2017apr fy2017_targets{
			replace `x' = `x'_nn if indicator=="TX_NET_NEW"
			drop `x'_nn
			}
			*end
	*remove tx net new values for fy15
		foreach pd in fy2015q2 fy2015q3 fy2015apr {
			replace `pd' = . if indicator=="TX_NET_NEW"
			}
			*end
	*save before Linkage adjustment
		save "$output/nearfinaldata.dta", replace
		
** Linkage **
		
	*linkage = TX_NEW/HTS_TST_POS
		keep if inlist(indicator, "HTS_TST_POS", "TX_NEW")
		drop avg_gr
	*reshape long to allow dataset to become a timeseries & transform time variable to date format
		egen id = group(operatingunit primepartner fundingagency mechanismid ///
			implementingmechanismname indicator)
		reshape long fy, i(id) j(qtr, string)
		drop id
		
	*recode 0s to missing
		recode fy (0 = .)
		
	*reshape for calculation
		reshape wide fy, i(qtr operatingunit primepartner fundingagency mechanismid implementingmechanismname) j(indicator, string)
	
	*calc linkage
		gen fyLINKAGE = round(fyTX_NEW/fyHTS_TST_POS, .001)
	
	*reshape back to long & only keep linkage data
		reshape long
		keep if indicator=="LINKAGE" & fy!=.
		
	*reshape wide to append to original dataset	
		reshape wide fy, i(operatingunit primepartner fundingagency mechanismid implementingmechanismname indicator) j(qtr, string)
	
	*save
		replace indicator = "LINKAGE (HTS to TX)"
		save "$output/lnkgdata.dta", replace
		
** FINAL CLEANUP & EXPORT			
	* reopen 
		use "$output/nearfinaldata.dta", clear
		append using "$output/lnkgdata.dta"
		
	*delete extrainous vars/obs
		local vars operatingunit ///
			fundingagency primepartner mechanismid implementingmechanismname ///
			indicator fy2016_targets fy2016q1 fy2016q2 fy2016q2 fy2016q3 ///
			fy2016q4 fy2016apr fy2017_targets fy2017q1 fy2017q2 fy2017q3 ///
			fy2017q4 fy2017apr fy2017cum avg_gr
		keep `vars'
		order `vars'
		
	*only keep USAID partners 
		keep if fundingagency=="USAID"	
		
	*order indicators
		preserve
		clear
		input int ind2 str36 indicator
			1 "HTS_TST"
			2 "HTS_TST_POS"
			3 "TX_NEW"
			4 "LINKAGE (HTS to TX)"
			5 "TX_CURR"
			6 "TX_NET_NEW"
			7 "PMTCT_STAT"
		end
		tempfile temp_ind
		save "`temp_ind'"
		restore
	*merge order back in
		merge m:1 indicator using "`temp_ind'", nogen noreport
		
	/*label new indicator variable and replace old string
		labmask ind2, values(indicator)
		drop indicator
		rename ind2 indicator
		order indicator, after(implementingmechanismname) */
		
	*sort by mech
		sort operatingunit mechanismid ind2
		drop ind2
		
	*export
		export delimited using "$excel/progressq3", nolabel replace dataf
		
	*remove intermediate dataset
		foreach x in extradata nearfinaldata lnkgdata {
			rm "$output/`x'.dta"
			}
			*end
