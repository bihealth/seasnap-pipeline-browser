library(shiny)
library(Rseasnap)
library(bioshmods)
library(seaPiper)
library(RJSONIO)
library(curl)
library(shinyBS)
options(spinner.type=6)
options(spinner.color="#47336F")

# Log a formatted message to stdout and the temporary HTML log file.
# Keeps startup progress visible while data is being prepared.
info <- function(...) {
  txt <- sprintf(...)
  message(txt)
  txt <- sprintf("[%s] %s\n", Sys.time(), txt)
  cat(txt, file="logs/index.html", append=TRUE)
}

# Merge multiple seaPiperData objects into one combined object.
# Ensures list-like sections are concatenated and class is preserved.
merge_seapiper_data <- function(data_objects) {
  data_objects <- Filter(Negate(is.null), data_objects)
  stopifnot(length(data_objects) > 0)

  if(length(data_objects) == 1) {
    return(data_objects[[1]])
  }

  # Concatenate named list sections across data objects.
  # Stops when duplicate dataset IDs would collide in merged output.
  merge_named_sections <- function(values, section_name) {
    merged_values <- do.call(c, values)
    dataset_ids <- names(merged_values)
    if(!is.null(dataset_ids) && anyDuplicated(dataset_ids)) {
      duplicated_ids <- unique(dataset_ids[duplicated(dataset_ids)])
      stop(
        sprintf(
          "Duplicate dataset IDs found in merged `%s`: %s",
          section_name,
          paste(duplicated_ids, collapse=", ")
        )
      )
    }
    merged_values
  }

  keys <- unique(unlist(lapply(data_objects, names)))
  merged <- setNames(vector("list", length(keys)), keys)

  for(key in keys) {
    values <- lapply(data_objects, function(.) .[[key]])
    values <- Filter(Negate(is.null), values)

    if(length(values) == 0) {
      merged[[key]] <- NULL
    } else if(all(vapply(values, is.list, logical(1)))) {
      merged[[key]] <- merge_named_sections(values, key)
    } else {
      merged[[key]] <- values[[1]]
    }
  }

  class(merged) <- "seaPiperData"
  merged
}

# Validate and normalize one dataset entry from the datasets JSON array.
# Enforces required fields and allowed format values.
validate_dataset_entry <- function(ds, index) {
  if(!is.list(ds)) {
    if(is.atomic(ds) && !is.null(names(ds)) && length(ds) > 0) {
      ds <- as.list(ds)
    } else {
      stop(sprintf("Dataset entry #%d must be a JSON object", index))
    }
  }

  required_fields <- c("name", "archive", "config")
  missing_fields <- required_fields[vapply(required_fields, function(field) {
    value <- ds[[field]]
    !(is.character(value) && length(value) == 1 && nzchar(trimws(value)))
  }, logical(1))]

  if(length(missing_fields) > 0) {
    stop(sprintf(
      "Dataset entry #%d is missing required field(s): %s",
      index,
      paste(missing_fields, collapse=", ")
    ))
  }

  ds[["name"]] <- trimws(ds[["name"]])
  ds[["archive"]] <- trimws(ds[["archive"]])
  ds[["config"]] <- trimws(ds[["config"]])

  format <- ds[["format"]]
  if(is.null(format) || (is.character(format) && length(format) == 1 && trimws(format) == "")) {
    format <- "rseasnap"
  }
  if(!(is.character(format) && length(format) == 1)) {
    stop(sprintf("Dataset `%s`: `format` must be a string", ds[["name"]]))
  }

  format <- tolower(trimws(format))
  if(!(format %in% c("rseasnap", "custom"))) {
    stop(sprintf(
      "Dataset `%s`: invalid `format` `%s` (allowed: rseasnap, custom)",
      ds[["name"]],
      format
    ))
  }
  ds[["format"]] <- format
  ds
}

# Start the temporary HTTP server used to expose startup logs.
# Waits for pid file creation and fails after a configurable timeout.
start_temp_http_server <- function(timeout_sec=120L, poll_sec=2L) {
  timeout_sec <- as.integer(timeout_sec)
  poll_sec <- as.integer(poll_sec)
  if(is.na(timeout_sec) || timeout_sec <= 0) {
    stop("`timeout_sec` must be a positive integer")
  }
  if(is.na(poll_sec) || poll_sec <= 0) {
    stop("`poll_sec` must be a positive integer")
  }

  info("Starting temporary HTTP server")
  status <- system("./weblog.sh", wait=FALSE)
  if(status != 0) {
    stop("Failed to start temporary HTTP server")
  }

  start_time <- Sys.time()
  while(!file.exists("logs/webserver.pid")) {
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units="secs"))
    if(elapsed >= timeout_sec) {
      stop(sprintf("Timed out after %d seconds waiting for temporary HTTP server", timeout_sec))
    }
    info("waiting for the HTTP server to initialize")
    Sys.sleep(poll_sec)
  }

  pid <- suppressWarnings(as.integer(read.table("logs/webserver.pid")[[1]][1]))
  if(is.na(pid)) {
    stop("Temporary HTTP server PID file is invalid")
  }

  info("Temporary HTTP server running with PID %d", pid)
  pid
}

# Stop the temporary HTTP server process if it is still running.
# Tries TERM first, then escalates to KILL when needed.
stop_temp_http_server <- function(pid) {
  if(is.null(pid) || is.na(pid)) {
    return(invisible(NULL))
  }

  if(system(sprintf("kill -0 %d", pid), ignore.stdout=TRUE, ignore.stderr=TRUE) != 0) {
    return(invisible(NULL))
  }

  info("Stopping temporary web server %d", pid)
  system(sprintf("kill -TERM %d", pid), ignore.stdout=TRUE, ignore.stderr=TRUE)
  Sys.sleep(1)

  if(system(sprintf("kill -0 %d", pid), ignore.stdout=TRUE, ignore.stderr=TRUE) == 0) {
    info("Temporary web server %d did not exit, sending SIGKILL", pid)
    system(sprintf("kill -KILL %d", pid), ignore.stdout=TRUE, ignore.stderr=TRUE)
  }
}

# Main startup flow: parse environment variables, fetch/extract datasets.
# Launches seaPiper and keeps temporary server cleanup reliable.
main <- function() {
  dir.create("logs/", showWarnings=FALSE)
  cat("<html><head><title>Please wait</title></head>
       <body><h1>Please wait, initializing....</h1><pre>\n\n", file="logs/index.html")

  pid <- NA_integer_
  on.exit(stop_temp_http_server(pid), add=TRUE)
  pid <- start_temp_http_server(timeout_sec=120L, poll_sec=2L)
  info("Package versions: tmod=%s; Rseasnap=%s; bioshmods=%s; seaPiper=%s", as.character(utils::packageVersion("tmod")), as.character(utils::packageVersion("Rseasnap")), as.character(utils::packageVersion("bioshmods")), as.character(utils::packageVersion("seaPiper")))
  info("Image: %s:%s", Sys.getenv("SEAPIPER_IMAGE_NAME", unset="unknown-image"), Sys.getenv("SEAPIPER_IMAGE_VERSION", unset="unknown-version"))

  title <- Sys.getenv("TITLE")
  if(title == "") {
    title <- "Pipeline browser"
  }

  datasets <- Sys.getenv("datasets")
  if(datasets == "") {
    stop("Missing required environment variable `datasets`")
  }

  ## for whatever reason the JSON is broken
  datasets <- gsub("'", '"', datasets)
  datasets <- sprintf('{ "datasets": %s }', datasets)
  datasets <- tryCatch(
    fromJSON(datasets, simplify=FALSE)[["datasets"]],
    error=function(e) {
      stop(sprintf("Failed to parse `datasets` JSON: %s", conditionMessage(e)))
    }
  )

  if(!is.list(datasets) || length(datasets) == 0) {
    stop("`datasets` must be a non-empty JSON array of dataset objects")
  }

  datasets <- lapply(seq_along(datasets), function(i) {
    validate_dataset_entry(datasets[[i]], i)
  })

  dataset_names <- vapply(datasets, function(ds) ds[["name"]], character(1))
  if(anyDuplicated(dataset_names)) {
    duplicated_names <- unique(dataset_names[duplicated(dataset_names)])
    stop(sprintf(
      "Duplicate dataset names in `datasets`: %s",
      paste(duplicated_names, collapse=", ")
    ))
  }
  names(datasets) <- dataset_names

  for(i in datasets) {
    info("Dataset: %s (format=%s)", i[["name"]], i[["format"]])
  }

  irods_path <- Sys.getenv("IRODS_PATH")
  irods_token <- Sys.getenv("IRODS_TOKEN")
  davrods_server <- Sys.getenv("DAVRODS_SERVER")
  missing_env <- c()
  if(irods_path == "") { missing_env <- c(missing_env, "IRODS_PATH") }
  if(irods_token == "") { missing_env <- c(missing_env, "IRODS_TOKEN") }
  if(davrods_server == "") { missing_env <- c(missing_env, "DAVRODS_SERVER") }
  if(length(missing_env) > 0) {
    stop(sprintf(
      "Missing required environment variable(s): %s",
      paste(missing_env, collapse=", ")
    ))
  }

  info("Downloading data")
  for(ds in datasets) {
    info("Downloading data set %s", ds[["name"]])
    .dsdir <- paste0("archive_", ds[["name"]])
    info(sprintf("Creating directory '%s'", .dsdir))
    dir.create(.dsdir, showWarnings=FALSE)

    .url <- sprintf("https://anonymous:%s@%s%s/%s",
                    irods_token,
                    davrods_server,
                    irods_path,
                    ds[["archive"]])
    info("Downloading tar file from\n
      https://anonymous:%s@%s%s/%s",
                    "XXXXX",
                    davrods_server,
                    irods_path,
                    ds[["archive"]])
    .arch_file <- file.path(.dsdir, ds[["archive"]])
    tryCatch(
      curl_download(.url, .arch_file, quiet=TRUE),
      error=function(e) {
        stop(sprintf(
          "Failed to download archive for dataset `%s`: %s",
          ds[["name"]],
          conditionMessage(e)
        ))
      }
    )
    info("opening archive:\n      cd '%s' ; tar xzf '%s'", .dsdir, ds[["archive"]])
    status <- system(sprintf("cd '%s' ; tar xzf '%s'", .dsdir, ds[["archive"]]))
    if(status != 0) {
      stop(sprintf(
        "Failed to extract archive `%s` for dataset `%s`",
        ds[["archive"]],
        ds[["name"]]
      ))
    }
  }

  info("Creating seaPiper data objects")
  rseasnap_pips <- list()
  custom_data <- list()
  for(ds in datasets) {
    .conf_file <- file.path(
      paste0("archive_", ds[["name"]]),
      ds[["config"]]
    )
    if(!file.exists(.conf_file)) {
      stop(sprintf(
        "Config file not found for dataset `%s`: %s",
        ds[["name"]],
        .conf_file
      ))
    }

    if(ds[["format"]] == "rseasnap") {
      info(sprintf("Loading workflow config file %s", .conf_file))
      rseasnap_pips[[ds[["name"]]]] <- load_de_pipeline(.conf_file)
    } else {
      info(sprintf("Loading custom data YAML file %s", .conf_file))
      custom_data[[ds[["name"]]]] <- seapiperdata_from_yaml(.conf_file)
    }
  }

  data_parts <- list()
  if(length(rseasnap_pips) > 0) {
    data_parts[[length(data_parts) + 1]] <- seapiperdata_from_rseasnap(rseasnap_pips, sample_id = "label")
  }
  if(length(custom_data) > 0) {
    data_parts <- c(data_parts, custom_data)
  }
  data <- merge_seapiper_data(data_parts)

  stop_temp_http_server(pid)
  pid <- NA_integer_

  message("Launching app")
  debug_panel <- Sys.getenv("DEBUG_PANEL")
  if(debug_panel == "") {
    debug_panel <- FALSE
  } else {
    debug_panel <- TRUE
  }
  app <- seapiper(data, title=title, debug_panel=debug_panel)
  runApp(app, launch.browser = FALSE, port = 8080, host = "0.0.0.0") #runs shiny app in port 8080 localhost
}

main()
