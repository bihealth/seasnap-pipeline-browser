library(Rseasnap)

config_file <- Sys.getenv("DE_CONFIG")
if(config_file == "") {
  config_file <- "DE_config.yaml"
}

title <- Sys.getenv("TITLE")
if(title == "") {
  title <- "Pipeline browser"
}

message("Pre-loading data")
pip <- load_de_pipeline(config_file)
annot <- get_annot(pip)
tmod_dbs <- get_tmod_dbs(pip)
cntr <- get_contrasts(pip)
tmod_res <- get_tmod_res(pip)

message("Launching app")
pipeline_browser(pip, title=title, annot=annot,
      tmod_dbs=tmod_dbs, tmod_res=tmod_res, 
      cntr=cntr
      )
