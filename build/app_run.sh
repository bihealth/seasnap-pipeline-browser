echo Launching

#echo Downloading data from SODAR
#echo .. Executing wget https://anonymous:IRODS_TOKEN@${DAVRODS_SERVER}${IRODS_PATH}/${IRODS_FILE}
#wget --quiet -O archive.tar.gz https://anonymous:${IRODS_TOKEN}@${DAVRODS_SERVER}${IRODS_PATH}/${IRODS_FILE}

#echo unpacking archive:
#echo .. Executing tar xzf archive.tar.gz
#tar xzf archive.tar.gz
#rm archive.tar.gz

echo running the R script
Rscript app_run.R
