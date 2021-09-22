## Based on Bioconductor image, with R 4.1
FROM bioconductor/bioconductor_docker:latest

##install necessary libraries
RUN apt-get update && DEBIAN_FRONTEND=noninteractive  apt-get -qq install libxml2-dev wget libcurl4-openssl-dev libssl-dev 
RUN R -e "install.packages(c('shinyjs', 'curl', 'tmod', 'colorDF', 'lubridate', 'plotly', 'DT', 'cowplot', 'bslib', 'thematic', \
                          'ggrepel', 'shinydashboard', 'shinyBS', 'shinycssloaders', 'RJSONIO'))"
RUN R -e "BiocManager::install('DESeq2')"

EXPOSE 8080

#copy the current folder into the path of the app
COPY . /usr/local/src/app

#set working directory to the app
WORKDIR /usr/local/src/app

RUN R -e "install.packages('Rseasnap_0.2.9.tar.gz')"

#set the unix commands to run the app
CMD ["/bin/bash", "app_run.sh" ]
