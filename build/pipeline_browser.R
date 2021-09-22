library(Rseasnap)
library(RJSONIO)
library(curl)
library(shinyBS)
options(spinner.type=6)
options(spinner.color="#47336F")


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
for(i in datasets) {
  message(str(i))
  message(i[["name"]])
}

irods_path     <- Sys.getenv("IRODS_PATH")
irods_token    <- Sys.getenv("IRODS_TOKEN")
davrods_server <- Sys.getenv("DAVRODS_SERVER")
stopifnot(all(c(irods_path != "", irods_token != "", davrods_server != "")))

message("Downloading data")
for(ds in datasets) {
  message(ds)
  .dsdir <- paste0("archive_", ds[["name"]])
  message(sprintf("Creating directory '%s'", .dsdir))
  dir.create(.dsdir)
  
  .url <- sprintf("https://anonymous:%s@%s%s/%s",
                  irods_token,
                  davrods_server,
                  irods_path,
                  ds[["archive"]])
  message(sprintf("Downloading tar file from %s", 
    sprintf("https://anonymous:%s@%s%s/%s",
                  "XXXXX",
                  davrods_server,
                  irods_path,
                  ds[["archive"]])
                  ))
  .arch_file <- file.path(.dsdir, ds[["archive"]])
  curl_download(.url, .arch_file, quiet=TRUE)
  message(sprintf("opening archive:\ncd '%s' ; tar xzf '%s'", .dsdir, ds[["archive"]]))
  system(sprintf("cd '%s' ; tar xzf '%s'", .dsdir, ds[["archive"]]))

}

message("Creating pipeline objects")
#Sys.sleep(1000000)

pips <- lapply(datasets, function(.) {
                 .conf_file <- file.path(
                                         paste0("archive_", .[["name"]]),
                                         .[["config"]])
                 message(sprintf("Loading workflow config file %s", .conf_file))
                 load_de_pipeline(.conf_file)
                  })

message("Launching app")
pipeline_browser(pips, title=title)
