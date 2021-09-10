library(shiny)

ui <- basicPage(
               verbatimTextOutput("vars")
              ) 

server <- function(input, output) {
  output$vars <- renderPrint(Sys.getenv())
}

shinyApp(ui = ui, server = server)
