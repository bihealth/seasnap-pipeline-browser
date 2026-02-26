suppressPackageStartupMessages(library(shiny))

info <- function(fmt, ...) {
  txt <- sprintf(fmt, ...)
  message(txt)
  line <- sprintf("[%s] %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), txt)
  cat(line, file = "logs/index.html", append = TRUE)
}

get_env_required <- function(name) {
  value <- Sys.getenv(name, unset = "")
  if (!nzchar(value)) {
    stop(sprintf("Missing required environment variable `%s`", name))
  }
  value
}

start_temp_http_server <- function(timeout_sec = 120L, poll_sec = 2L) {
  info("Starting temporary HTTP server")
  status <- system("./weblog.sh", wait = FALSE)
  if (status != 0) {
    stop("Failed to start temporary HTTP server")
  }

  start_time <- Sys.time()
  while (!file.exists("logs/webserver.pid")) {
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    if (elapsed >= timeout_sec) {
      stop(sprintf("Timed out after %d seconds waiting for temporary HTTP server", timeout_sec))
    }
    Sys.sleep(poll_sec)
  }

  pid <- suppressWarnings(as.integer(readLines("logs/webserver.pid", n = 1L, warn = FALSE)))
  if (is.na(pid)) {
    stop("Temporary HTTP server PID file is invalid")
  }

  info("Temporary HTTP server running with PID %d", pid)
  pid
}

stop_temp_http_server <- function(pid) {
  if (is.null(pid) || is.na(pid)) {
    return(invisible(NULL))
  }

  if (system(sprintf("kill -0 %d", pid), ignore.stdout = TRUE, ignore.stderr = TRUE) != 0) {
    return(invisible(NULL))
  }

  info("Stopping temporary web server %d", pid)
  system(sprintf("kill -TERM %d", pid), ignore.stdout = TRUE, ignore.stderr = TRUE)
  Sys.sleep(1)

  if (system(sprintf("kill -0 %d", pid), ignore.stdout = TRUE, ignore.stderr = TRUE) == 0) {
    info("Temporary web server %d did not exit, sending SIGKILL", pid)
    system(sprintf("kill -KILL %d", pid), ignore.stdout = TRUE, ignore.stderr = TRUE)
  }
}

to_relative_paths <- function(paths, root_dir) {
  root <- normalizePath(root_dir, winslash = "/", mustWork = FALSE)
  normalized <- normalizePath(paths, winslash = "/", mustWork = FALSE)
  prefix <- paste0(root, "/")
  starts <- startsWith(normalized, prefix)
  rel <- basename(normalized)
  rel[starts] <- substring(normalized[starts], nchar(prefix) + 1L)
  rel
}

prepare_manifest <- function() {
  irods_path <- get_env_required("IRODS_PATH")
  irods_token <- get_env_required("IRODS_TOKEN")
  davrods_server <- get_env_required("DAVRODS_SERVER")
  irods_file <- get_env_required("IRODS_FILE")

  dir.create("data", showWarnings = FALSE, recursive = TRUE)
  extract_dir <- file.path("data", "extracted")
  if (dir.exists(extract_dir)) {
    unlink(extract_dir, recursive = TRUE, force = TRUE)
  }
  dir.create(extract_dir, recursive = TRUE, showWarnings = FALSE)

  archive_path <- file.path("data", "archive.tar.gz")
  if (file.exists(archive_path)) {
    unlink(archive_path)
  }

  source_url <- sprintf(
    "https://anonymous:%s@%s%s/%s",
    irods_token,
    davrods_server,
    irods_path,
    irods_file
  )
  display_url <- sprintf(
    "https://anonymous:%s@%s%s/%s",
    "XXXXX",
    davrods_server,
    irods_path,
    irods_file
  )

  info("Downloading archive from %s", display_url)
  tryCatch(
    download.file(source_url, destfile = archive_path, mode = "wb", quiet = TRUE, method = "libcurl"),
    error = function(e) {
      stop(sprintf("Archive download failed: %s", conditionMessage(e)))
    }
  )

  archive_size <- as.numeric(file.info(archive_path)$size)
  info("Downloaded archive size: %s bytes", format(archive_size, big.mark = ",", scientific = FALSE))

  info("Extracting archive into %s", extract_dir)
  tryCatch(
    untar(archive_path, exdir = extract_dir),
    error = function(e) {
      stop(sprintf("Archive extraction failed: %s", conditionMessage(e)))
    }
  )

  extracted_paths <- list.files(
    extract_dir,
    recursive = TRUE,
    all.files = TRUE,
    no.. = TRUE,
    full.names = TRUE
  )

  if (length(extracted_paths) == 0L) {
    entries <- data.frame(
      path = character(0),
      bytes = numeric(0),
      is_directory = logical(0),
      stringsAsFactors = FALSE
    )
  } else {
    file_stats <- file.info(extracted_paths)
    entries <- data.frame(
      path = to_relative_paths(extracted_paths, extract_dir),
      bytes = as.numeric(file_stats$size),
      is_directory = dir.exists(extracted_paths),
      stringsAsFactors = FALSE
    )
    entries <- entries[order(entries$path), , drop = FALSE]
  }

  manifest <- list(
    downloaded_at = as.character(Sys.time()),
    source_url = display_url,
    archive_name = irods_file,
    archive_size_bytes = archive_size,
    extracted_dir = normalizePath(extract_dir, winslash = "/", mustWork = FALSE),
    file_count = nrow(entries),
    entries = entries
  )

  saveRDS(manifest, file = file.path("data", "manifest.rds"))
  info("Prepared manifest with %d extracted entries", manifest$file_count)

  manifest
}

build_app <- function(manifest) {
  ui <- fluidPage(
    titlePanel(Sys.getenv("TITLE", unset = "SODAR Shiny Blueprint")),
    tags$p("This minimal app confirms the SODAR archive was downloaded and unpacked at startup."),
    tags$h3("Download Summary"),
    tableOutput("summary"),
    tags$h3("Extracted Entries"),
    tags$p("Showing at most 200 rows for readability."),
    tableOutput("entries")
  )

  server <- function(input, output, session) {
    output$summary <- renderTable({
      data.frame(
        field = c(
          "Downloaded at",
          "Source URL",
          "Archive name",
          "Archive size (bytes)",
          "Extracted entries"
        ),
        value = c(
          manifest$downloaded_at,
          manifest$source_url,
          manifest$archive_name,
          format(manifest$archive_size_bytes, scientific = FALSE, trim = TRUE),
          as.character(manifest$file_count)
        ),
        stringsAsFactors = FALSE
      )
    }, colnames = FALSE, striped = TRUE, bordered = TRUE)

    output$entries <- renderTable({
      if (manifest$file_count == 0L) {
        return(data.frame(note = "No entries found after extraction", stringsAsFactors = FALSE))
      }

      visible <- manifest$entries
      if (nrow(visible) > 200L) {
        visible <- visible[seq_len(200L), , drop = FALSE]
      }
      visible
    }, striped = TRUE, bordered = TRUE)
  }

  shinyApp(ui = ui, server = server)
}

main <- function() {
  dir.create("logs", showWarnings = FALSE, recursive = TRUE)
  cat(
    "<html><head><title>Please wait</title></head><body><h1>Preparing data...</h1><pre>\n\n",
    file = "logs/index.html"
  )

  pid <- NA_integer_
  on.exit(stop_temp_http_server(pid), add = TRUE)

  pid <- start_temp_http_server(timeout_sec = 120L, poll_sec = 2L)
  manifest <- prepare_manifest()

  stop_temp_http_server(pid)
  pid <- NA_integer_

  app <- build_app(manifest)
  runApp(app, launch.browser = FALSE, port = 8080, host = "0.0.0.0")
}

main()
