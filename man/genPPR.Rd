% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/genPPR.R
\name{genPPR}
\alias{genPPR}
\title{Generate PPR export data file}
\usage{
genPPR(datapathfv, output_global = TRUE, output_ctry_all = TRUE,
  df_return = FALSE, output_subset_type = NULL, ...)
}
\arguments{
\item{datapathfv}{what is the file path to the ICPI MER Structured dataset? eg "~/ICPI/Data"}

\item{output_global}{export full dataset? logical, default = TRUE}

\item{output_ctry_all}{export each country? logicial, default = TRUE}

\item{df_return}{return a dataframe in R session, default = FALSE}

\item{output_subset_type}{select only subset, either "ou" or "mechid"}

\item{...}{add list of countries or mechanisms for `output_subset_type`, eg "18841", "14421"}
}
\description{
Purpose: generate output for Excel monitoring dashboard
NOTES
  - Data source: ICPI_MER_Structured_Dataset_PSNU_IM  [ICPI Data Store]
  - Need current COP Matrix report (renaming to official names)
  - Report aggregates DSD and TA
  - Report looks at only Totals and MCAD
}
\examples{
\dontrun{
#export global file
  genPPR("~/ICPI/Data", output_ctry_all = FALSE)
#view global file
  df_ppr <- genPPR("~/ICPI/Data", output_global = FALSE, output_ctry_all = FALSE)
#export global and country specific files to populate PPR
  genPPR("~/ICPI/Data")
#export just Malawi and Kenya
  genPPR("~/ICPI/Data", output_global = FALSE, output_ctry_all = FALSE, output_subset_type = "ou", "Kenya", "Malawi")
#export two mechanims
  genPPR("~/ICPI/Data", output_global = FALSE, output_ctry_all = FALSE, output_subset_type = "mechid", "18234", "18544") }

}
