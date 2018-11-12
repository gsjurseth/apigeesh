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
./apigee.sh -u user@foo.com -o myorg -d foo
```

This will export everything in to a directory structure named: `foo`. The script will prompt you for user password.
