library(shiny)
library(Rseasnap)
library(bioshmods)
library(seaPiper)
library(RJSONIO)
library(curl)
library(shinyBS)
options(spinner.type=6)
options(spinner.color="#47336F")

info <- function(...) {
  txt <- sprintf(...)
  message(txt)
  txt <- sprintf("[%s] %s\n", Sys.time(), txt)
  cat(txt, file="logs/index.html", append=TRUE)
}

merge_seapiper_data <- function(data_objects) {
  data_objects <- Filter(Negate(is.null), data_objects)
  stopifnot(length(data_objects) > 0)

  if(length(data_objects) == 1) {
    return(data_objects[[1]])
  }

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

dir.create("logs/")
cat("<html><head><title>Please wait</title></head>
     <body><h1>Please wait, initializing....</h1><pre>\n\n", file="logs/index.html")

info("Starting temporary HTTP server")
system("./weblog.sh", wait=FALSE)

while(!file.exists("logs/webserver.pid")) {
  info("waiting for the HTTP server to initialize")
  Sys.sleep(5)
}


pid <- read.table("logs/webserver.pid")[[1]]
info("Temporary HTTP server running with PID %d", pid)

title <- Sys.getenv("TITLE")
if(title == "") {
  title <- "Pipeline browser"
}

datasets <- Sys.getenv("datasets")
stopifnot(datasets != "")

## for whatever reason the JSON is broken
datasets <- gsub("'", '"', datasets)
datasets <- sprintf('{ "datasets": %s }', datasets)
datasets <- fromJSON(datasets)[[1]]
stopifnot(is.list(datasets))
stopifnot(length(datasets) > 0)

names(datasets) <- sapply(datasets, function(.) .[["name"]])
datasets <- lapply(datasets, function(.) {
  format <- .[["format"]]
  if(is.null(format) || format == "") {
    format <- "rseasnap"
  }
  format <- tolower(trimws(format))
  stopifnot(format %in% c("rseasnap", "custom"))
  .[["format"]] <- format
  .
})
for(i in datasets) {
  info("Dataset: %s (format=%s)", i[["name"]], i[["format"]])
}

irods_path     <- Sys.getenv("IRODS_PATH")
irods_token    <- Sys.getenv("IRODS_TOKEN")
davrods_server <- Sys.getenv("DAVRODS_SERVER")
stopifnot(all(c(irods_path != "", irods_token != "", davrods_server != "")))

info("Downloading data")
for(ds in datasets) {
  info("Downloading data set %s", ds[["name"]])
  .dsdir <- paste0("archive_", ds[["name"]])
  info(sprintf("Creating directory '%s'", .dsdir))
  dir.create(.dsdir)
  
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
                  ds[["archive"]]
                  )
  .arch_file <- file.path(.dsdir, ds[["archive"]])
  curl_download(.url, .arch_file, quiet=TRUE)
  info("opening archive:\n      cd '%s' ; tar xzf '%s'", .dsdir, ds[["archive"]])
  system(sprintf("cd '%s' ; tar xzf '%s'", .dsdir, ds[["archive"]]))

}

info("Creating seaPiper data objects")
rseasnap_pips <- list()
custom_data <- list()
for(ds in datasets) {
  .conf_file <- file.path(
    paste0("archive_", ds[["name"]]),
    ds[["config"]]
  )

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
  data_parts[[length(data_parts) + 1]] <- seapiperdata_from_rseasnap(rseasnap_pips)
}
if(length(custom_data) > 0) {
  data_parts <- c(data_parts, custom_data)
}
data <- merge_seapiper_data(data_parts)

info("Killing temporary web server %s", pid)
system(sprintf("kill -9 %d", pid))
Sys.sleep(3)
message("Launching app")
debug_panel <- Sys.getenv("DEBUG_PANEL")
if(debug_panel == "") {
  debug_panel <- FALSE
} else {
  debug_panel <- TRUE
}
app <- seapiper(data, title=title, debug_panel=debug_panel)
runApp(app, launch.browser = FALSE, port = 8080, host = "0.0.0.0") #runs shiny app in port 8080 localhost
