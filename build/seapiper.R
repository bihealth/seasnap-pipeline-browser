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
for(i in datasets) {
  info("Dataset: %s", i[["name"]])
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

info("Creating pipeline objects")
#Sys.sleep(1000000)

pips <- lapply(datasets, function(.) {
                 .conf_file <- file.path(
                                         paste0("archive_", .[["name"]]),
                                         .[["config"]])
                 info(sprintf("Loading workflow config file %s", .conf_file))
                 load_de_pipeline(.conf_file)
                  })

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
app <- seapiper(pips, title=title, debug_panel=debug_panel)
runApp(app, launch.browser = FALSE, port = 8080, host = "0.0.0.0") #runs shiny app in port 8080 localhost

