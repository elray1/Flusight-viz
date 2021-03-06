# create json files with truth in them
# files are named as data/truth_<target_var>_<location>_<as_of>.json, where
# target_var is "case", "death", or "hosp",
# location is an identifier for a location, and
# as_of is a date in YYYY-MM-DD format indicating the data version date.
# A single json file has data in the format of a list of (date, value) pairs:
# [
#    {date: "YYYY-MM-DD", value: 0},
#    ...,
#    {date: "YYYY-MM-DD", value: 1}
# ]

library(tidyverse)
library(jsonlite)

# flag to indicate whether we want to regenerate truth json files for all
# past weeks, or only for the present week. There are two options:
# - FALSE will regenerate all truth files for past weeks. This should only be
# necessary if a change is made to the formatting of the files, or we need to
# add in results for an older model that updated past forecasts
# - TRUE will generate truth files only for the latest week. This will
# be the appropriate option most of the time

#' Obtain influenza signal at daily or weekly scale
#'
#' @param pathogen the pathogen we want data for, either flu or covid
#' @param as_of Date or string in format "YYYY-MM-DD" specifying the date which
#'   the data was available on or before. If `NULL`, the default returns the
#'   most recent available data.
#' @param locations optional list of FIPS or location abbreviations. Defaults to
#'   the US, the 50 states, DC, PR, and VI.
#' @param temporal_resolution "daily" or "weekly"
#' @param source either "covidcast" or "HealthData". HealthData only supports
#' `as_of` being `NULL` or the current date.
#' @param na.rm boolean indicating whether NA values should be dropped when
#'   aggregating state-level values and calculating weekly totals. Defaults to
#'   `FALSE`
#'
#' @return data frame of incidence with columns date, location,
#'   location_name, value
load_hosp_data <- function(pathogen = c("flu", "covid"),
                           as_of = NULL,
                           locations = "*",
                           temporal_resolution = "daily",
                           source = "HealthData",
                           na.rm = FALSE) {
  library(dplyr)
  library(readr)
  library(tidyverse)

  # load location data
  location_data <- readr::read_csv(file = "https://raw.githubusercontent.com/cdcepi/Flusight-forecast-data/master/data-locations/locations.csv",
                                   show_col_types = FALSE) %>%
    dplyr::mutate(geo_value = tolower(abbreviation)) %>%
    dplyr::select(-c("population", "abbreviation"))

  # validate function arguments
  if (!(source %in% c("covidcast", "HealthData"))) {
    stop("`source` must be either covidcast or HealthData")
  } else if (source == "HealthData" && !is.null(as_of)) {
    if (as_of != Sys.Date()) {
      stop("`as_of` must be either `NULL` or the current date if source is HealthData")
    }

  }

  valid_locations <- unique(c(
    "*",
    location_data$geo_value,
    tolower(location_data$location)
  ))
  locations <-
    match.arg(tolower(locations), valid_locations, several.ok = TRUE)
  temporal_resolution <- match.arg(temporal_resolution,
                                   c("daily", "weekly"),
                                   several.ok = FALSE)

  pathogen <- match.arg(pathogen)

  if (!is.logical(na.rm)) {
    stop("`na.rm` must be a logical value")
  }

  # get geo_value based on fips if fips are provided
  if (any(grepl("\\d", locations))) {
    locations <-
      location_data$geo_value[location_data$location %in% locations]
  } else {
    locations <- tolower(locations)
  }
  # if US is included, fetch all states
  if ("us" %in% locations) {
    locations_to_fetch <- "*"
  } else {
    locations_to_fetch <- locations
  }


  # pull daily state data
  if (source == "covidcast") {

    ## this chunk retrieves data from covidcast

    signal <- ifelse(pathogen=="flu", "confirmed_admissions_influenza_1d", "confirmed_admissions_covid_1d")

    state_dat <- covidcast::covidcast_signal(
      as_of = as_of,
      geo_values = locations_to_fetch,
      data_source = "hhs",
      signal = signal,
      geo_type = "state"
    ) %>%
      dplyr::mutate(
        epiyear = lubridate::epiyear(time_value),
        epiweek = lubridate::epiweek(time_value)
      ) %>%
      dplyr::select(geo_value, epiyear, epiweek, time_value, value) %>%
      dplyr::rename(date = time_value)

  } else {

    ## this chunk retrieves data from HeatlhData

    temp <- httr::GET(
      "https://healthdata.gov/resource/qqte-vkut.json",
      config = httr::config(ssl_verifypeer = FALSE)
    ) %>%
      as.character() %>%
      jsonlite::fromJSON()
    csv_path <- tail(temp$archive_link$url, 1)
    data <- readr::read_csv(csv_path)

    ## value returned depends on which pathogen was specified
    if(pathogen == "flu") {
      state_dat <- data %>%
      dplyr::transmute(
        geo_value = tolower(state),
        date = date - 1,
        epiyear = lubridate::epiyear(date),
        epiweek = lubridate::epiweek(date),
        value = previous_day_admission_influenza_confirmed
      ) %>%
      dplyr::arrange(geo_value, date)
    } else {
      state_dat <- data %>%
        dplyr::transmute(
          geo_value = tolower(state),
          date = date - 1,
          epiyear = lubridate::epiyear(date),
          epiweek = lubridate::epiweek(date),
          value = previous_day_admission_adult_covid_confirmed + previous_day_admission_pediatric_covid_confirmed
        ) %>%
        dplyr::arrange(geo_value, date)
    }
  }


  # creating US and bind to state-level data if US is specified or locations
  if (locations_to_fetch == "*") {
    us_dat <- state_dat %>%
      dplyr::group_by(epiyear, epiweek, date) %>%
      dplyr::summarize(value = sum(value, na.rm = na.rm), .groups = "drop") %>%
      dplyr::mutate(geo_value = "us") %>%
      dplyr::ungroup() %>%
      dplyr::select(geo_value, epiyear, epiweek, date, value)
    # bind to daily data
    if (locations != "*") {
      dat <- rbind(us_dat, state_dat) %>%
        dplyr::filter(geo_value %in% locations)
    } else {
      dat <- rbind(us_dat, state_dat)
    }
  } else {
    dat <- state_dat
  }

  # weekly aggregation
  if (temporal_resolution != "daily") {
    dat <- dat %>%
      dplyr::group_by(epiyear, epiweek, geo_value) %>%
      dplyr::summarize(
        date = max(date),
        num_days = n(),
        value = sum(value, na.rm = na.rm),
        .groups = "drop"
      ) %>%
      dplyr::filter(num_days == 7L) %>%
      dplyr::ungroup() %>%
      dplyr::select(-"num_days")
  }
  final_data <- dat %>%
    dplyr::left_join(location_data, by = "geo_value") %>%
    dplyr::select(date, location, location_name, value) %>%
    # drop data for locations retrieved from covidcast,
    # but not included in forecasting exercise -- mainly American Samoa
    dplyr::filter(!is.na(location))

  return(final_data)
}


#' Retrieving flu data
#'
#' @param as_of Date or string in format "YYYY-MM-DD" specifying the date which
#'   the data was available on or before. If `NULL`, the default returns the
#'   most recent available data.
#' @param locations optional list of FIPS or location abbreviations. Defaults to
#'   the US, the 50 states, DC, PR, and VI.
#' @param temporal_resolution "daily" or "weekly"
#' @param source either "covidcast" or "HealthData". HealthData only supports
#' `as_of` being `NULL` or the current date.
#' @param na.rm boolean indicating whether NA values should be dropped when
#'   aggregating state-level values and calculating weekly totals. Defaults to
#'   `FALSE`
#'
#' @return data frame of flu incidence with columns date, location,
#'   location_name, value
load_flu_hosp_data <- function(as_of = NULL,
                               locations = "*",
                               temporal_resolution = "daily",
                               source = "HealthData",
                               na.rm = FALSE) {
  load_hosp_data(pathogen = "flu",
                 as_of = as_of,
                 locations = locations,
                 temporal_resolution = temporal_resolution,
                 source = source,
                 na.rm = na.rm)


}


generate_latest_only <- FALSE
# generate_latest_only <- TRUE

last_as_of <- lubridate::floor_date(Sys.Date(), unit = "week", week_start = 6)

available_as_ofs <- purrr::map(
    c("hosp"),
    function(target_var) {
        first_as_of <- as.Date("2022-01-08")
        as_ofs <- seq.Date(from = first_as_of, to = last_as_of, by = 7)
        return(as_ofs)
    }
)
names(available_as_ofs) <- c("hosp")
available_as_ofs_json <- jsonlite::toJSON(available_as_ofs)
writeLines(
    available_as_ofs_json,
    paste0("static/data/available_as_ofs.json")
)

locations_json <- readr::read_csv(
    file = "https://raw.githubusercontent.com/cdcepi/Flusight-forecast-data/master/data-locations/locations.csv",
    show_col_types = FALSE) %>%
    dplyr::select(value = location, text = location_name) %>%
    jsonlite::toJSON()
writeLines(
    locations_json,
    paste0("assets/locations.json")
)


for (target_var in c("hosp")) {
    as_ofs <- available_as_ofs[[target_var]]
    if (generate_latest_only) {
        as_ofs <- max(as_ofs)
    }
    data_start_date <- as.Date("2021-12-01")
    for (as_of in as.character(as_ofs)) {
        data <- load_flu_hosp_data(
            as_of = as.Date(as_of) + 3, # get data as of tuesday because of covidcast latency
            locations = "*",
            temporal_resolution = "weekly",
            source = "covidcast",
            na.rm = FALSE)
        
        for (location in unique(data$location)) {
            location_data <- data %>%
                dplyr::filter(
                    location == UQ(location),
                    date >= data_start_date) %>%
                dplyr::arrange(date) %>%
                dplyr::select(date = date, y = value) %>%
                as.list() %>%
                jsonlite::toJSON()

            writeLines(
                location_data,
                paste0("static/data/truth/", target_var, "_", location, "_", as_of,  ".json")
            )
        }
    }
}
