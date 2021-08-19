# Developing apps for Kiosc / SODAR

To develop an app for visualisation of the data from SODAR via KIOSC, you
need the following elements:

1) an app that does something – e.g. a shiny app
2) a docker image (containing the app) uploaded to the CUBI github page
3) a way for the image container to access the
[SODAR](https://sodar.bihealth.org) data (using anonymous
tickets / tokens)
4) a configuration in [KIOSC](https://kiosc.bihealth.org) which actually stores the site-specific URLs
and tokens

In the following, I will describe the creation of the pipeline browser app.
We start by creating a build directory for the docker images (called
`build`).


## The pipeline browser shiny app

The results of a sea-snap pipeline can be easily visualised using the
`pipeline_browser()` function from the `Rseasnap` package. This function
defines the UI and the server of a shiny app and returns a shiny object,
which is what we need for our app. The following code starts the app:


```
library(Rseasnap)
pip <- load_de_pipeline("DE_config.yaml")
pipeline_browser(pip)
```

This will be the contents of the `app.R`, with one modification. Sometimes
it is convenient to have different names for the pipeline config file, so
we might want to specify it as a run parameter for the container image.
These parameters are passed on to apps within the container via
environmental variables, and we can look them up from within R:

```
library(Rseasnap)

config_file <- Sys.getenv("DE_CONFIG")
if(config_file == "") {
  config_file <- "DE_config.yaml"
}

pip <- load_de_pipeline(config_file)
pipeline_browser(pip)
```

This defines our shiny app, but the function actually calling the app is
stored in another file, `build/app_run.R`:

```
require(shiny)
runApp("app.R", launch.browser = FALSE, port = 8080, host = "0.0.0.0")
```

It is convenient to separate launching the app and the app itself. The
above code tells shiny not to launch a browser (which would not work in a container)
and specifies that the app should listen to port 8080 on localhost.
However, having the app in a separate file allows us to launch the app from
outside of the container to check that it is working.

If you look into the `build/` directory, you will see that `app.R` is
actually a symbolic link to `build/pipeline_browser.R`. This is because I
was using another shiny app, stored in `build/check_vars.R` which shows
(from within R) which environmental variables have been defined. By
switching the symbolic link between the two files I could debug the
issues with the pipeline when run from Kiosc.

## Shell startup script

Before we launch the app using `app_run.R`, we need to pull the data from
SODAR. This happens not when the docker image is build, but later, when the
docker container is started (that way the image does not contain any
private data and at each start the newest version of the pipeline is
downloaded). The startup shell scripts contains the commands to download
the data (as a .tar.gz file), unpack it, and launch the shiny app.

Here is the file `build/app_run.sh`. This is the file that the docker
container will actually run.

```
echo Launching

echo Downloading data from SODAR
echo .. Executing wget https://anonymous:IRODS_TOKEN@${DAVRODS_SERVER}${IRODS_PATH}/${IRODS_FILE}
wget --quiet -O archive.tar.gz https://anonymous:${IRODS_TOKEN}@${DAVRODS_SERVER}${IRODS_PATH}/${IRODS_FILE}

echo unpacking archive:
echo .. Executing tar xzf archive.tar.gz
tar xzf archive.tar.gz

echo running the R script
Rscript app_run.R
```

OK, so you see that there is here a number of environmental variables that
need to come from outside of the container which specify how to get at the
tar.gz file we need to unpack for the app to run. (The file has been
created with `tar hczf DE_pipeline.tar.gz DE_config.yaml DE/` and uploaded
to a landing zone on SODAR).

Now that we have the app, the R script to run the app and the shell script
that downloads the data and calls the R script to run the app, we need to
put it all in the docker image.


## Creating the docker image

The docker image must contain all the software required to run our app and
also to access the data on SODAR. As the base for my image, I used the
bioconductor image containing a recent version of Bioconductor (because we
need DESeq2, and DESeq2 needs Bioconductor) and of R (4.1). Below are the
lines of the [Dockerfile](build/Dockerfile) explained:

```
## Based on Bioconductor image, with R 4.1
FROM bioconductor/bioconductor_docker:latest
```

The line above states that we base our image on the latest
`bioconductor_docker` image. This already includes a lot of software which
we need, but we need to get some more:

```
##install necessary libraries
RUN apt-get update && DEBIAN_FRONTEND=noninteractive  apt-get -qq install libxml2-dev wget libcurl4-openssl-dev libssl-dev 
RUN R -e "install.packages(c('shinyjs', 'tmod', 'colorDF', 'lubridate', 'plotly', 'DT', 'cowplot', 'bslib', 'thematic', 'ggrepel'))"
RUN R -e "BiocManager::install('DESeq2')"
```

First, we need to get the Ubuntu packages that are necessary to download
the data (like `wget`) and to compile the additional packages that we need
to install in R (second line above). Note that we set the `DEBIAN_FRONTENT`
variable to `noninteractive` and answer every question with "yes" (`-qq`
option). Finally, we install `DESeq2` because
the pipeline browser needs it.

Below we define the port to expose by the docker container. It must be the
same port as specified in `app_run.R` above:

```
EXPOSE 8080
```

Next, we set up the work environment for the app. We copy all files which
are in the `build` directory (including the Rseasnap package):

```
#copy the current folder into the path of the app
COPY . /usr/local/src/app

#set working directory to the app
WORKDIR /usr/local/src/app
```

We also need to install Rseasnap. Since Rseasnap is not on CRAN, we cannot
use `install.packages(Rseasnap)` like we did above. We *could* install it from git
using `devtools`, but that would require us to install the devtools package
and its dependencies, which would greatly increase the size of our image.
It is more efficient to simply include the little .tar.gz file in the image
and install Rseasnap from it:

```
RUN R -e "install.packages('Rseasnap_0.1.8.tar.gz')"
```

Finally, the last element of the Dockerfile is the command to execute when
the docker image starts. This is our shell script from above, run by
`/bin/bash`:

```
#set the unix commands to run the app
CMD ["/bin/bash", "app_run.sh" ]
```

(We do not use `ENTRYPOINT` here, because that way the command can be
overriden by a Kiosc parameter, but we could).

## Building and testing the image

First, build the docker image with

```
docker build -t ghcr.io/bihealth/pipeline-browser:v5 build
```

Yeah, it's confusing: the first `build` is the build command of docker and
the second `build` is the name of the directory containing the
`Dockerfile`. (You can also enter the `build` directory and run 
`docker build -t ghcr.io/bihealth/pipeline-browser:v5.`).

Note that at this point we already define the name of the image and its
location. It will store the docker image on github container repository
(`ghcr.io`), bihealth account.

It takes a lot of time to build it for the first time: docker needs to pull
the bioconductor image, install all the requirements etc. However, when you
later modify individual files, usually only a small fraction of that needs
to be repeated (thanks to the docker cache mechanism and docker layers).

Once the image is build, you can run it with 

```
docker run -P ghcr.io/bihealth/pipeline-browser:v5
```

(`-d` option is for detached mode, `-P` is for exposing the ports).

This will not work, however, because the scripts we created require
parameters stored as environmental variables. Here is the output:

```
Launching
Downloading data from SODAR
.. Executing wget https://anonymous:IRODS_TOKEN@/
unpacking archive:
.. Executing tar xzf archive.tar.gz

gzip: stdin: unexpected end of file
tar: Child returned status 1
tar: Error is not recoverable: exiting now
running the R script
Loading required package: shiny
Warning in file(file, "rt", encoding = fileEncoding) :
  cannot open file 'DE_config.yaml': No such file or directory
Error in file(file, "rt", encoding = fileEncoding) :
  cannot open the connection
Calls: <Anonymous> ... ..stacktraceon.. -> load_de_pipeline -> read_yaml -> file
Execution halted
```

To actually test our pipeline, we need to first go to SODAR and HPC and
configure our access to the file. Once we have that (see the
[README.md](README.md) file for details), we can define the environmental
variables in the docker run command to make our pipeline actually work:


```
docker run -e DE_CONFIG="DE_config.yaml" \
           -e IRODS_PATH="/sodarZone/projects/1e/1e526322-50b8-47dd-a419-759d03d19a0b/landing_zones/weinerj@CHARITE/seasnap_test_data/monocytes/20210812_165144" \
           -e IRODS_FILE="DE_pipeline.tar.gz"\
           -e DAVRODS_SERVER="davrods-anonymous.sodar.cubi.bihealth.org"\
           -e IRODS_TOKEN="XXXX"\
           -e TITLE="Example title"\
           -P ghcr.io/bihealth/pipeline-browser:v5
```

(Use the actual token / ticket instead of the "XXXX" above).

Note that the davrods server is not the same as the one used when clicked on the
WebDAV links in SODAR – it is specifically for serving the data anonymously
with the help of tokens (tickets as they are called in the IRODS lingo).

Also note that presently only landing zones and your home directories can
be exposed from SODAR. Therefore, the file must be either in your home or in an LZ.

This now takes several minutes, because the container needs to download
the file from SODAR and unpack it before launching the app. At the end we
have output that looks like this:

```
Launching
Downloading data from SODAR
.. Executing wget https://anonymous:IRODS_TOKEN@davrods-anonymous.sodar.cubi.bihealth.org/sodarZone/projects/1e/1e526322-50b8-47dd-a419-759d03d19a0b/landing_zones/weinerj@CHARITE/seasnap_test_data/monocytes/20210812_165144/DE_pipeline.tar.gz
unpacking archive:
.. Executing tar xzf archive.tar.gz
running the R script
Loading required package: shiny
preparing...
 * Loading Annotation (consider using the annot option to speed this up)
 * Loading contrasts (consider using the cntr option to speed this up)
[...boring stuff about packages being loaded...]
 * Loading tmod results (consider using the tmod_res option to speed this up)
 * Loading tmod_dbs (consider using the tmod_rdbses option to speed this up)

Listening on http://0.0.0.0:8080
```

The last line is a lie – well, not a lie really, because within the
container the app really listens to port 8080 (just like we specified).
However, the container port 8080 is mapped to another port on the host
machine. We can check it by running `docker ps`:

```
CONTAINER ID   IMAGE                                  COMMAND                  CREATED         STATUS         PORTS                                                                                      NAMES
c7a7ae127197   ghcr.io/bihealth/pipeline-browser:v5   "/bin/bash app_run.sh"   4 minutes ago   Up 4 minutes   0.0.0.0:49190->8080/tcp, :::49190->8080/tcp, 0.0.0.0:49189->8787/tcp, :::49189->8787/tcp   silly_newton
```

If you open now the URL `0.0.0.0:49190` in your browser, you should get to
see the app. Hurra! The image works.


## Uploading images to github

This requires a few preparation steps. First, one needs to create a
*github* token for your local docker installation to be able to access
`ghcr.io/bihealth` and upload images there. Then you need to login in
docker using your username and the token.

To generate the token, go to `github.com`, go to personal settings, then to
"developer settings", click on the "personal access tokens" and "generate
new token". Select "write packages" and "delete packages" from the token
scopes which define what the app that has the token is allowed to do.

Next, login locally with docker to github by doing 

```
docker login ghcr.io
```

Use your github username and, as password, your newly created token. 


Next, upload the image to github by simply writing

```
docker push ghcr.io/bihealth/pipeline-browser:v5
```

One last thing we need to do is to make this image publicly available,
because Kiosc cannot login to github. Go to `github.com/bihealth`, click on
"packages", click on "pipeline-browser", click on "Package settings" on the
right and go to the "Danger zone" at the bottom of the page. Click on
"Change visibility" and follow the instructions to make the package
publicly visible.

Note that since the package is publicly visible, you should not put *any*
private data in the image, including SODAR links and (especially) tokens.

We are done now. All that is left is to configure Kiosc – see the
[README.md](README.md) file for that.

