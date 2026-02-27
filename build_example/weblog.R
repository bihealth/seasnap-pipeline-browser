suppressPackageStartupMessages(library(httpuv))

read_index <- function() {
  if (!file.exists("index.html")) {
    return(charToRaw("<html><body><h1>Initializing...</h1></body></html>"))
  }

  size <- file.info("index.html")$size
  con <- file("index.html", open = "rb")
  on.exit(close(con), add = TRUE)
  readBin(con, what = "raw", n = size)
}

app <- list(
  call = function(req) {
    list(
      status = 200L,
      headers = list(
        "Content-Type" = "text/html; charset=utf-8",
        "Cache-Control" = "no-store"
      ),
      body = read_index()
    )
  }
)

server <- startServer("0.0.0.0", 8080L, app)
on.exit(stopServer(server), add = TRUE)

while (TRUE) {
  service(1000L)
}
