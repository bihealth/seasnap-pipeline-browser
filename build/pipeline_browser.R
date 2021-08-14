library(Rseasnap)

config_file <- Sys.getenv("DE_CONFIG")
if(config_file == "") {
  config_file <- "DE_config.yaml"
}

pip <- load_de_pipeline(config_file)
pipeline_browser(pip)
