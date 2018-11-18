# Apigeesh
This is a simple script that uses nothing other than curl to export a number of known artifacts from a given org.
Today this will export the following:
* org specifics
* environments
* kvms
* targetservers
* apiproducts
* developers
* apps

## Execution
You simply run the script like so:
```sh
./apigee.sh -u user@host.com -o someOrg -c <import|export> [-d /path/to/dir] [-b http://url.of.mgmserver]
```

Use the export command to export and the import for importing
