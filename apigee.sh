#!/bin/bash

### We need to handle INT so that we can reset echo
trap doBreak INT

function doBreak() {
  echo "Caught Interrupt .. resetting shell echo" >&2
  stty echo
}

### Da functions yo!
function doHelp() {
  echo "Incorrect arguments specified" >&2
  echo "$0 -u user@host.com -o someOrg" >&2
  exit 1
}

dir=.

### Get the options bit done
while getopts "o:u:d:h" arg; do
  options_found=1
  case $arg in
    o)
      org=$OPTARG
    ;;
    d)
      dir=$OPTARG
    ;;
    u)
      username=$OPTARG
    ;;
    h)
      help=true
    ;;
    *)
      doHelp
    ;;
  esac
done

if [ -z "${org}" ] || [ -z "${username}" ] || [ -n "${help}" ]
then
  doHelp
fi

### Basic args are there .. let's get our password
echo "Enter your password and press enter: "
stty -echo
read pass
stty echo

function listEnvs() {
  $CURL -s -H "Accept: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/e" | tr -d '[]",''"'
}

function listProducts() {
  $CURL -s -H "Accept: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/apiproducts" | tr -d '[]",''"'
}

function listApps() {
  $CURL -s -H "Accept: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/apps" | tr -d '[]",''"'
}

function listDevelopers() {
  $CURL -s -H "Accept: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/developers" | tr -d '[]",''"'
}

function listKVMs() {
  env=$1
  $CURL -s -H "Accept: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/e/$env/keyvaluemaps" | tr -d '[]",''"'
}

function listTS() {
  env=$1
  $CURL -s -H "Accept: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/e/$env/targetservers" | tr -d '[]",''"'
}

APIGEE_BASE=https://api.enterprise.apigee.com/v1/o
CURL=$(which curl)
#CURL_OPTS=-q -H "Accept: application/json" -u ${username}:${pass}


### Set up our output dir
ODIR=${dir}/${org}
mkdir -p $ODIR
$CURL -s -H "Accept: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}" -o ${ODIR}/org.json

### Basics for environments
for env in $(listEnvs)
do
  EDIR=${dir}/${org}/e/$env
  mkdir -p $EDIR
  $CURL -s -H "Accept: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/e/$env" -o ${EDIR}/env.json

  ### Now do kvms per environment
  mkdir -p $EDIR/keyvaluemaps
  # now do a kvm
  for kvm in $(listKVMs $env)
  do
    $CURL -s -H "Accept: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/e/$env/keyvaluemaps/$kvm" -o ${EDIR}/keyvaluemaps/$kvm.json
  done

  ### Now do targetservers per environment
  mkdir -p $EDIR/targetservers
  # now do a ts
  for ts in $(listTS $env)
  do
    $CURL -s -H "Accept: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/e/$env/targetservers/$ts" -o ${EDIR}/targetservers/$ts.json
  done
done

### Let's do apiproducts
mkdir -p $ODIR/apiproducts
for product in $(listProducts)
do
  $CURL -s -H "Accept: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/apiproducts/$product" -o ${ODIR}/apiproducts/$product.json
done

### Let's do developers
mkdir -p $ODIR/developers
for developer in $(listDevelopers)
do
  $CURL -s -H "Accept: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/developers/$developer" -o ${ODIR}/developers/$developer.json
done

### Let's do apps
mkdir -p $ODIR/apps
for app in $(listApps)
do
  $CURL -s -H "Accept: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/apps/$app" -o ${ODIR}/apps/$app.json
done
