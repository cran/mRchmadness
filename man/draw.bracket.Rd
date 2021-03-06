% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/draw.bracket.R
\name{draw.bracket}
\alias{draw.bracket}
\title{Plot bracket to device}
\usage{
draw.bracket(bracket.empty, bracket.filled = NULL, league = c("men",
  "women"))
}
\arguments{
\item{bracket.empty}{a length-64 character vector giving the field of 64
teams in the tournament, in order of initial overall seeding}

\item{bracket.filled}{an optional length-63 character vector encoding
tournament results (matching output from simulate.bracket)}

\item{league}{which league: "men" (default) or "women".
Used for converting team IDs into team names}
}
\description{
Plot bracket to device
}
\examples{
  prob.matrix = bradley.terry(games = games.men.2017)
  outcome = sim.bracket(bracket.empty = bracket.men.2017,
    prob.matrix = prob.matrix)
  draw.bracket(bracket.empty = bracket.men.2017, bracket.filled = outcome)
}
\author{
sspowers
}
