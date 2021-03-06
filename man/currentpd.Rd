% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/currentperiod.R
\name{currentpd}
\alias{currentpd}
\title{Extract lastest period of dataset}
\usage{
currentpd(df, pd_type = "full")
}
\arguments{
\item{df}{dataset to use to find latest period}

\item{pd_type}{what is returned? (a) full, eg fy2018q1; (b)year, eg 2018; (c) or quarter, eg 1}
}
\description{
Extract lastest period of dataset
}
\examples{
\dontrun{
currentpd(df_mer)
currrentpd(df_mer, "quarter") }

}
