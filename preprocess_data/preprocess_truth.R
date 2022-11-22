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
library(covidData)

# flag to indicate whether we want to regenerate truth json files for all
# past weeks, or only for the present week. There are two options:
# - FALSE will regenerate all truth files for past weeks. This should only be
# necessary if a change is made to the formatting of the files, or we need to
# add in results for an older model that updated past forecasts
# - TRUE will generate truth files only for the latest week. This will
# be the appropriate option most of the time
# generate_latest_only <- FALSE
generate_latest_only <- TRUE

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

locations_df <- readr::read_csv(
    file = "https://raw.githubusercontent.com/cdcepi/Flusight-forecast-data/master/data-locations/locations.csv",
    show_col_types = FALSE) %>%
    dplyr::select(value = location, text = location_name)
locations_json <- locations_df %>%
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
        data <- covidData::load_data(
            as_of = as.Date(as_of) + 2, # get data as of Monday
            temporal_resolution = "weekly",
            spatial_resolution = c("state", "national"),
            source = "healthdata",
            measure = "flu hospitalizations")
        
        for (location in unique(locations_df$value)) {
            location_data <- data %>%
                dplyr::filter(
                    location == UQ(location),
                    date >= data_start_date) %>%
                dplyr::arrange(date) %>%
                dplyr::select(date = date, y = inc) %>%
                as.list() %>%
                jsonlite::toJSON()

            writeLines(
                location_data,
                paste0("static/data/truth/", target_var, "_", location, "_", as_of,  ".json")
            )
        }
    }
}
