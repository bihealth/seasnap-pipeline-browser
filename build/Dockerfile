## Build: docker build --build-arg VERSION=0.1.0 -t ghcr.io/bihealth/seapiper:0.1.0 build
## Based on Bioconductor image, with R 4.1
FROM bioconductor/bioconductor_docker:latest

##install necessary libraries
RUN apt-get update && DEBIAN_FRONTEND=noninteractive  apt-get -qq install libxml2-dev wget libcurl4-openssl-dev libssl-dev 
RUN R -e "install.packages(c('markdown', 'shinyjs', 'curl', 'colorDF', 'lubridate', 'plotly', 'DT', 'cowplot', 'bslib', 'thematic', \
                          'ggrepel', 'shinydashboard', 'shinyBS', 'shinycssloaders', 'RJSONIO', 'waiter', 'remotes'))"
RUN R -e "BiocManager::install('DESeq2')"

EXPOSE 8080

#copy the current folder into the path of the app
COPY . /usr/local/src/app

#set working directory to the app
WORKDIR /usr/local/src/app

#RUN R -e "install.packages('Rseasnap_0.2.10.tar.gz')"
#RUN R -e "install.packages('bioshmods_0.0.0.9000.tar.gz')"
#RUN R -e "install.packages('seaPiper_0.0.0.9000.tar.gz')"

## change ARG VERSION on command line to enforce reinstalling the seapiper et co
## docker build --build-arg VERSION=0.1.1 ...
ARG VERSION=0.5.2
RUN R -e "remotes::install_github( 'january3/tmod', upgrade='never');remotes::install_github( 'bihealth/Rseasnap', upgrade='never');remotes::install_github('bihealth/bioshmods@memoptimisation', upgrade='never');remotes::install_github('bihealth/seaPiper', upgrade='never')"

#set the unix commands to run the app
CMD ["/usr/local/bin/Rscript", "app.R" ]
