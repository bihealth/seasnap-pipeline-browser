# Pipeline browser for sea-snap

This docker image contains the pipeline browser for the sea-snap pipeline.
To use it, do the following:


 1. Contact Matthias or Mikko to link your SODAR project to a KIOSC
    project.

 2. On SODAR, create a landing zone (LZ) for the data. Record the IRODS path to
    the LZ. For the example pipeline data in sea-snap, this is 

        
        /sodarZone/projects/1e/1e526322-50b8-47dd-a419-759d03d19a0b/landing_zones/weinerj@CHARITE/seasnap_test_data/monocytes/20210812_165144
        


 3. On the HPC, create a `.tar.gz` file containing the pipeline including
    the yaml config file. If you used default settings, this amounts to
    running

         
         tar hczf DE_pipeline.tar.gz DE_config.yaml DE
         

 4. Copy the `.tar.gz` file to the LZ, for example with

         
         iinit
         iput DE_pipeline.tar.gz /sodarZone/projects/1e/1e526322-50b8-47dd-a419-759d03d19a0b/landing_zones/weinerj@CHARITE/seasnap_test_data/monocytes/20210812_165144
         

 5. Create a ticket (token) for anonymous access to the IRODS LZ:

         
         iticket create read /sodarZone/projects/1e/1e526322-50b8-47dd-a419-759d03d19a0b/landing_zones/weinerj@CHARITE/seasnap_test_data/monocytes/20210812_165144
         

 6. On the corresponding KIOSC site (the link is e.g. in SODAR under "This
    project on other sites", or simply go to kiosc.bihealth.org) create a
    new container ("Containers" -> "Create container"). Steps below
    describe how you should fill out the "Create container" form.


 7. Under "repository", enter `ghcr.io/bihealth/pipeline_browser`. Under
    "Tag", enter `v5` (current version of the container). Under `Container
    port`, enter `8080` (the port at which container exposes the pipeline
    browser). **Note**: it happened to me more than once that I have
    inadvertently changed the port number by using the laptop touchpad.
    This results in a "server error", so please make sure that the port
    number is correct!

 8. Now you need to configure the variables under "Environment". This entry
    is in JSON format and *must* include the information for the container
    how to access your data. Here is a template. The actual tocken from the
    `iticket` step above was replaced here by `XXX`, but you need to enter
    the real token of course.

         
         {
           "IRODS_PATH":"/sodarZone/projects/1e/1e526322-50b8-47dd-a419-759d03d19a0b/landing_zones/weinerj@CHARITE/seasnap_test_data/monocytes/20210812_165144",
           "DAVRODS_SERVER":"davrods-anonymous.sodar.cubi.bihealth.org",
           "IRODS_FILE":"DE_pipeline.tar.gz",
           "IRODS_TOKEN":"XXX",
           "DE_CONFIG":"DE_config.yaml",
           "TITLE":"Sea-snap example project"
         }
         
 9. Enter `IRODS_TOKEN` under "Environment secret keys" such that the token cannot
    be viewed by other users of the Kiosc site. When you edit the container
    again, the actual value of the token will be shown as `<masked>`

 10. Click on "Create", and the start the container. Presto! Go grab a
     coffee, because starting the container will take a few minutes. Had
     your coffee? The container should now be available. Or not, and in
     such a case, contact me and we will figure out what went wrong.
