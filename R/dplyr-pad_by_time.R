#' Insert time series rows with regularly spaced timestamps
#'
#' The easiest way to fill in missing timestamps or convert to a more
#' granular period (e.g. quarter to month). Wraps the `padr::pad()` function
#' for padding tibbles.
#'
#' @param .data A tibble with a time-based column.
#' @param .date_var A column containing date or date-time values to pad
#' @param .by Either "auto", a time-based frequency like "year", "month", "day", "hour", etc,
#'  or a time expression like "5 min", or "7 days". See Details.
#' @param .pad_value Fills in padded values. Default is `NA`.
#' @param .fill_na_direction Users can provide an `NA` fill strategy using `tidyr::fill()`.
#'  Possible values: `'none'`, `'down'`, `'up'`, `'downup'`, `'updown'`. Default: `'none'`
#' @param .start_date Specifies the start of the padded series.
#'  If NULL it will use the lowest value of the input variable.
#' @param .end_date  Specifies the end of the padded series.
#'  If NULL it will use the highest value of the input variable.
#'
#' @details
#'
#' __Padding Missing Observations__
#'
#' The most common use case for `pad_by_time()` is to add rows where timestamps
#' are missing. This could be from sales data that have missing values on weekends and holidays.
#' Or it could be high frequency data where observations are irregularly spaced and should be
#' reset to a regular frequency.
#'
#' __Going from Low to High Frequency__
#'
#' The second use case is going from a low frequency (e.g. day) to high frequency (e.g. hour).
#' This is possible by supplying a higher frequency to `pad_by_time()`.
#'
#' __Interval, .by__
#'
#' Padding can be applied in the following ways:
#' - `.by = "auto"` - `pad_by_time()` will detect the time-stamp frequency and apply padding.
#' - The eight intervals in are: year, quarter, month, week, day, hour, min, and sec.
#' - Intervals like 5 minutes, 6 hours, 10 days are possible.
#'
#' __Pad Value, .pad_value__
#'
#' A pad value can be supplied that fills in missing numeric data. Note that this is only applied to numeric columns.
#'
#' __Fill NA Direction, .fill_na_directions__
#'
#' Uses `tidyr::fill()` to fill missing observations using a fill strategy.
#'
#' @seealso
#'
#' Imputation:
#' - [ts_impute_vec()] - Impute missing values for time series.
#'
#' Time-Based dplyr functions:
#'
#' - [summarise_by_time()] - Easily summarise using a date column.
#' - [mutate_by_time()] - Simplifies applying mutations by time windows.
#' - [pad_by_time()] - Insert time series rows with regularly spaced timestamps
#' - [filter_by_time()] - Quickly filter using date ranges.
#' - [filter_period()] - Apply filtering expressions inside periods (windows)
#' - [slice_period()] - Apply slice inside periods (windows)
#' - [condense_period()] - Convert to a different periodicity
#' - [between_time()] - Range detection for date or date-time sequences.
#' - [slidify()] - Turn any function into a sliding (rolling) function
#'
#' @references
#' - This function wraps the `padr::pad()` function developed by Edwin Thoen.
#'
#' @examples
#' library(tidyverse)
#' library(tidyquant)
#' library(timetk)
#'
#' # Create a quarterly series with 1 missing value
#' missing_data_tbl <- tibble(
#'     date = tk_make_timeseries("2014-01-01", "2015-01-01", by = "quarter"),
#'     value = 1:5
#' ) %>%
#'     slice(-4) # Lose the 4th quarter on purpose
#' missing_data_tbl
#'
#'
#' # Detects missing quarter, and pads the missing regularly spaced quarter with NA
#' missing_data_tbl %>% pad_by_time(date, .by = "quarter")
#'
#' # Can specify a shorter period. This fills monthly.
#' missing_data_tbl %>% pad_by_time(date, .by = "month")
#'
#' # Can let pad_by_time() auto-detect date and period
#' missing_data_tbl %>% pad_by_time()
#'
#' # Can specify a .pad_value
#' missing_data_tbl %>% pad_by_time(date, .by = "quarter", .pad_value = 0)
#'
#' # Can then impute missing values
#' missing_data_tbl %>%
#'     pad_by_time(date, .by = "quarter") %>%
#'     mutate(value = ts_impute_vec(value, period = 1))
#'
#' # Can specify a custom .start_date and .end_date
#' missing_data_tbl %>%
#'    pad_by_time(date, .by = "quarter", .start_date = "2013", .end_date = "2015-07-01")
#'
#' # Can specify a tidyr::fill() direction
#' missing_data_tbl %>%
#'    pad_by_time(date, .by = "quarter",
#'                .fill_na_direction = "downup",
#'                .start_date = "2013", .end_date = "2015-07-01")
#'
#' # --- GROUPS ----
#'
#' # Apply standard NA padding to groups
#' FANG %>%
#'     group_by(symbol) %>%
#'     pad_by_time(.by = "day")
#'
#' # Apply constant pad value
#' FANG %>%
#'     group_by(symbol) %>%
#'     pad_by_time(.by = "day", .pad_value = 0)
#'
#' # Apply filled padding to groups
#' FANG %>%
#'     group_by(symbol) %>%
#'     pad_by_time(.by = "day", .fill_na_direction = "down")
#'
#' @name pad_by_time
#' @export
pad_by_time <- function(.data, .date_var, .by = "auto",
                        .pad_value = NA,
                        .fill_na_direction = c("none", "down", "up", "downup", "updown"),
                        .start_date = NULL, .end_date = NULL) {

    if (!tolower(.fill_na_direction[1]) %in% c("none", "down", "up", "downup", "updown")) {
        rlang::abort("'.fill_na_direction' must be one of c('none', 'down', 'up', 'downup', 'updown')")
    }

    if (rlang::quo_is_missing(rlang::enquo(.date_var))) {
        date_var_text <- tk_get_timeseries_variables(.data)[1]
        message(paste0(".date_var is missing. Using: ", date_var_text))
        date_var_expr <- rlang::sym(date_var_text)
    } else {
        date_var_expr <- rlang::enquo(.date_var)
    }

    # Check index exists
    date_var_text <- rlang::quo_name(date_var_expr)
    if (!date_var_text %in% names(.data)) {
        rlang::abort(stringr::str_glue("Attempting to use .date_var = {date_var_text}. Column does not exist in .data. Please specify a date or date-time column."))
    }

    UseMethod("pad_by_time", .data)
}

#' @export
pad_by_time.default <- function(.data, .date_var, .by = "auto",
                                .pad_value = NA, .fill_na_direction = c("none", "down", "up", "downup", "updown"),
                                .start_date = NULL, .end_date = NULL) {
    rlang::abort("Sorry, no method for class, ", class(.data)[1])
}

#' @export
pad_by_time.data.frame <- function(.data, .date_var, .by = "auto",
                                   .pad_value = NA, .fill_na_direction = c("none", "down", "up", "downup", "updown"),
                                   .start_date = NULL, .end_date = NULL) {
    padder(.data = .data,
           .date_var          = !! enquo(.date_var),
           .by                = .by,
           .pad_value         = .pad_value,
           .fill_na_direction = .fill_na_direction,
           .start_date        = .start_date,
           .end_date          = .end_date)
}

#' @export
pad_by_time.grouped_df <- function(.data, .date_var, .by = "auto",
                                   .pad_value = NA,
                                   .fill_na_direction = c("none", "down", "up", "downup", "updown"),
                                   .start_date = NULL, .end_date = NULL) {

    group_names   <- dplyr::group_vars(.data)
    date_var_expr <- rlang::enquo(.date_var)

    if (rlang::quo_is_missing(rlang::enquo(.date_var))) {
        date_var_expr <- rlang::sym(tk_get_timeseries_variables(.data)[1])
    }

    padder(
        .data = .data,
        .date_var          = !! enquo(.date_var),
        .by                = .by,
        .pad_value         = .pad_value,
        .fill_na_direction = .fill_na_direction,
        .start_date        = .start_date,
        .end_date          = .end_date,

        .group             = group_names

    )


    # .data %>%
    #     tidyr::nest() %>%
    #     dplyr::mutate(nested.col = purrr::map(
    #         .x         = data,
    #         .f         = function(df) padder(
    #             .data              = df,
    #             .date_var          = !! date_var_expr,
    #             .by                = .by,
    #             .pad_value         = .pad_value,
    #             .fill_na_direction = .fill_na_direction,
    #             .start_date        = .start_date,
    #             .end_date          = .end_date
    #         )
    #     )) %>%
    #     dplyr::select(-data) %>%
    #     tidyr::unnest(cols = nested.col) %>%
    #     dplyr::group_by_at(.vars = group_names)
}


# UTILS ----

parse_date_by <- function(.date, .by, idx) {
    if (!is.null(.date)) {
        if (is.null(.by)) {
            if (inherits(idx, "POSIXct")) {
                parse_datetime2(.date, tz = lubridate::tz(idx))
            } else {
                parse_date2(.date)
            }
        } else if (stringr::str_detect(.by, "(hour)|(min)|(sec)")) {
            parse_datetime2(.date, tz = lubridate::tz(idx))
        } else {
            parse_date2(.date)
        }
    }
}

padder <- function(.data, .date_var, .by = "auto", .pad_value = NA, .fill_na_direction = "none",
                   .start_date = NULL, .end_date = NULL,
                   .group = NULL, .stop_padding_if = 10e6) {

    date_var_expr <- rlang::enquo(.date_var)
    date_text     <- rlang::as_label(date_var_expr)

    .fill_na_direction <- tolower(.fill_na_direction[1])

    if (rlang::quo_is_missing(date_var_expr)) {
        date_var_expr <- rlang::sym(tk_get_timeseries_variables(.data)[1])
    }

    idx <- .data %>% dplyr::pull(!! date_var_expr)

    # Convert .by to NULL
    if (.by == "auto") .by <- NULL

    # Convert Start Date
    .start_date <- parse_date_by(.start_date, .by, idx)

    # Convert End Date
    .end_date <- parse_date_by(.end_date, .by, idx)

    # Apply the padding
    ret <- .data %>%
        dplyr::mutate(check_row_exists = 1) %>%
        padr::pad(
            by          = rlang::quo_name(date_var_expr),
            interval    = .by,
            start_val   = .start_date,
            end_val     = .end_date,
            group       = .group,
            break_above = .stop_padding_if
        )

    # Replace fill values
    if (!is.na(.pad_value)) {
        # ret[is.na(ret)] <- .pad_value

        # ret <- ret %>%
        #     dplyr::mutate_at(
        #         .vars = dplyr::vars(-(!! date_var_expr), -check_row_exists),
        #         .f = function(x) {
        #             ifelse(is.na(ret$check_row_exists), .pad_value, x)
        #         }
        #     )

        # group_names <- dplyr::group_vars(ret)
        # ret[is.na(ret[['check_row_exists']]), setdiff(names(ret), c(group_names, date_var_expr))] <- 0

        numeric_cols <- names(ret)[ret %>% purrr::map(is.numeric) %>% unlist()]
        ret[is.na(ret[['check_row_exists']]), numeric_cols] <- .pad_value

    }

    # Drop check_row_exists column
    ret <- ret %>%
        dplyr::select(-check_row_exists)

    # Fill NA
    if (.fill_na_direction != "none") {
        ret <- ret %>%
            tidyr::fill(dplyr::everything(), .direction = .fill_na_direction)
    }

    return(ret)

}
