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
  echo "$0 -u user@host.com -o someOrg -c <import|export> [-d /path/to/dir] [-b http://url.of.mgmserver]" >&2
  exit 1
}

dir=.

baseuri=https://api.enterprise.apigee.com/v1/o
### Get the options bit done
while getopts "c:b:o:u:d:h" arg; do
  options_found=1
  case $arg in
    c)
      cmd=$OPTARG
    ;;
    b)
      baseuri=$OPTARG
    ;;
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

if [ -z "${org}" ] || [ -z "${username}" ] || [ -n "${help}" ] || [ -c "${cmd}" ]
then
  doHelp
fi

### Basic args are there .. let's get our password
echo "Enter your password and press enter: "
stty -echo
read pass
stty echo

APIGEE_BASE=${baseuri}

function listProxies() {
  $CURL -s -H "Accept: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/apis" | tr -d '[]",''"'
}

function getLatestProxyRevision() {
  proxy=$1
  $CURL -s -H "Accept: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/apis/${proxy}/revisions" | tr -d '[]",''"' | rev | awk '{print $1}'
}

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

CURL=$(which curl)
#CURL_OPTS=-q -H "Accept: application/json" -u ${username}:${pass}




function exportDaStuff() {
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

  ### Now we'll handle the proxies themselves
  mkdir -p $ODIR/apiproxies
  for proxy in $(listProxies)
  do
    echo "Working on proxy: $proxy...."
    therev=$(getLatestProxyRevision $proxy)
    $CURL -s -H "Accept: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/apis/${proxy}/revisions/${therev}?format=bundle" -o ${ODIR}/apiproxies/${proxy}.zip
  done
}

function importDaStuff() {
  IDIR=${dir}/${org}
  ###  For import we go in reverse. We start with the proxies and import them
  for fname in $(ls ${IDIR}/apiproxies/*.zip)
  do
    echo "Working on proxy: $proxy...."
    proxy=$(basename $fname | sed -e 's/.zip//')
    $CURL -s -X POST -u "${username}:${pass}" -F "file=@${fname}" "${APIGEE_BASE}/${org}/apis?action=import&name=${proxy}"
  done
  
  ### Basics for environments
  for env in $(ls ${IDIR}/e)
  do
    EDIR=${dir}/${org}/e/$env
    $CURL -s -X POST -H "Content-type: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/e/$env" -d @${EDIR}/env.json

    ### Now do kvms per environment
    # now do a kvm
    ALLKVM=$(listKVMs $env)
    for kvm in $(ls $EDIR/keyvaluemaps | sed -e 's/.json//')
    do
      echo $ALLKVM | fgrep $kvm >/dev/null
      if [ $? -eq 0 ]
      then 
        $CURL -s -X PUT -H "Content-type: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/e/$env/keyvaluemaps/${kvm}" -d @${EDIR}/keyvaluemaps/$kvm.json
      else 
        $CURL -s -X POST -H "Content-type: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/e/$env/keyvaluemaps" -d @${EDIR}/keyvaluemaps/$kvm.json
      fi
    done

    ### Now do targetservers per environment
    # now do a ts
    ALLTS=$(listTS $env)
    for ts in $(ls ${EDIR}/targetservers | sed -e 's/.json//')
    do
      VERB=POST
      echo $ALLTS | fgrep $ts >/dev/null
      if [ $? -eq 0 ]
      then
        $CURL -s -X PUT -H "Content-type: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/e/$env/targetservers/${ts}" -d @${EDIR}/targetservers/$ts.json
      else
        $CURL -s -X POST -H "Content-type: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/e/$env/targetservers" -d @${EDIR}/targetservers/$ts.json
      fi
    done
  done

  ### Let's do apiproducts
  ALLPRODUCTS=$(listProducts)
  for product in $(ls $IDIR/apiproducts | sed -e 's/.json//')
  do
    echo $ALLPRODUCTS | fgrep $product >/dev/null
    if [ $? -eq 0 ]
    then
      $CURL -s -X PUT -H "Content-type: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/apiproducts/$product" -d @${IDIR}/apiproducts/$product.json
    else
      $CURL -s -X POST -H "Content-type: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/apiproducts" -d @${IDIR}/apiproducts/$product.json
    fi
  done

  ### Let's do developers
  ALLDEVELOPERS=$(listDevelopers)
  for developer in $(ls $IDIR/developers | sed -e 's/.json//')
  do
    echo $ALLDEVELOPERS | fgrep $developer >/dev/null
    if [ $? -eq 0 ]
    then
      $CURL -s -X PUT -H "Content-type: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/developers/$developer" -d @${IDIR}/developers/$developer.json
    else
      $CURL -s -X POST -H "Content-type: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/developers" -d @${IDIR}/developers/$developer.json
  fi
  done

  ### Let's do apps
  ALLAPPS=$(listApps)
  for app in $(ls $IDIR/apps | sed -e 's/.json//')
  do
    echo $ALLAPPS | fgrep $app >/dev/null
    if [ $? -eq 0 ]
    then
      $CURL -s -X PUT -H "Content-type: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/apps/$app" -d @${IDIR}/apps/$app.json
    else
      $CURL -s -X POST -H "Content-type: application/json" -u ${username}:${pass} "${APIGEE_BASE}/${org}/apps" -d @${IDIR}/apps/$app.json
    fi
  done
}

if [ "$cmd" = "import" ]
then
  importDaStuff
else
  exportDaStuff
fi
