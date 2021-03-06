#' Overlap of two circular distributions
#'
#' This function converts the input vectors to circular objects, calculates empirical densities,
#' and then calculates their overlap.
#'
#' The user must specify the bandwidth for the KDE as well as some other options for the circular
#' conversion.
#'
#' @export
circular_overlap <- function(a, b, circular_units, circular_template, norm = TRUE, bw, n = NULL) {

  # clean input
  a <- as.numeric(na.omit(a))
  b <- as.numeric(na.omit(b))

  # convert input to circular
  acirc <- circular::circular(a, units = circular_units, template = circular_template)
  bcirc <- circular::circular(a, units = circular_units, template = circular_template)

  # generate kernel densities
  # add option to use user-defined n
  # Must specify bandwidth
  if (is.null(n)) n <- 512 # Default value if not given
  da <- circular::density.circular(a, bw=bw, n=n)
  db <- circular::density.circular(b, bw=bw, n=n)
  d <- data.frame(x=da$x, a=da$y, b=db$y)

  # If not normalized, multiply each density entry by the length of each vector
  if (!norm) {
    d$a <- d$a * length(a)
    d$b <- d$b * length(b)
  }

  # calculate intersection densities
  d$w <- pmin(d$a, d$b)

  # integrate areas under curves
  integral_a <- sfsmisc::integrate.xy(d$x, d$a)
  integral_b <- sfsmisc::integrate.xy(d$x, d$b)
  total <- integral_a + integral_b
  intersection <- sfsmisc::integrate.xy(d$x, d$w)

  # compute overlap coefficient
  overlap <- 2 * intersection / total
  overlap_a <- intersection / integral_a
  overlap_b <- intersection / integral_b

  return(c(overlap = overlap, overlap_a = overlap_a, overlap_b = overlap_b))

}

#' Overlap of two 24-hour distributions
#'
#' This manually calculates the density by just taking the proportion of each hour.
#' Simple but effective.
#'
#' @export
circular_overlap_24hour <- function(a, b, norm = TRUE) {
  calc_weight <- function(x) { # a vector of hours
    tab <- table(factor(x,  levels=as.character(0:23)),
                 useNA="ifany")

    dimnames(tab) <- NULL
    if (norm) {
      weights <- tab / sum(tab)
    } else {
      weights <- tab
    }
    mat <- cbind( weights=weights, points=0:23 )
    mat
  }

  A <- calc_weight(a)
  B <- calc_weight(b)

  d <- data.frame(x = A[,'points'], a = A[,'weights'], b = B[,'weights'])

  # calculate intersection densities
  d$w <- pmin(d$a, d$b)

  # integrate areas under curves
  total <- sfsmisc::integrate.xy(d$x, d$a) + sfsmisc::integrate.xy(d$x, d$b)
  intersection <- sfsmisc::integrate.xy(d$x, d$w)

  # compute overlap coefficient
  overlap <- 2 * intersection / total
  overlap_a <- intersection / sfsmisc::integrate.xy(d$x, d$a)
  overlap_b <- intersection / sfsmisc::integrate.xy(d$x, d$b)

  return(c(overlap = overlap, overlap_a = overlap_a, overlap_b = overlap_b))

}

#' Community-level weighted median overlap using circular distributions
#'
#' Defaults to use 24-hour clock as units.
#' Uses manual calculation of density.
#'
#' @export
community_overlap_circular <- function(traits, sp, norm = TRUE, randomize_weights = FALSE) {
  sp <- as.character(sp)
  dat <- data.frame(traits=traits, sp=sp, stringsAsFactors = FALSE)
  dat <- dat[complete.cases(dat), ]
  abunds <- table(dat$sp)
  abunds <- abunds[abunds>1]
  dat <- dat[dat$sp %in% names(abunds), ]
  traitlist <- split(dat$traits, dat$sp)
  nspp <- length(traitlist)

  if (nspp < 2) return(NA)

  overlaps <- numeric(0)
  abund_pairs <- numeric(0)

  for (sp_a in 1:(nspp-1)) {
    for (sp_b in (sp_a+1):nspp) {
      o <- circular_overlap_24hour(a = traitlist[[sp_a]], b = traitlist[[sp_b]], norm = norm)
      overlaps <- c(overlaps, o[1])
      harmonic_mean <- 2/(1/abunds[sp_a] + 1/abunds[sp_b])
      abund_pairs <- c(abund_pairs, harmonic_mean)
    }
  }

  if (randomize_weights) abund_pairs <- sample(abund_pairs)

  matrixStats::weightedMedian(x = overlaps, w = abund_pairs)

}
