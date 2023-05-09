#!/bin/bash

# versoin 0.1.0

# Command line parameters
# cloud provider: -p
# geographic:     -g
# endpoint file:  -c 
# help:           -h

# coming enhancement
#   - Make -p and -g command line parameter optional. CSP info can be found with CSP metadata service. 
      # - AWS: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-identity-documents.html
      # - Azure: https://learn.microsoft.com/en-us/azure/virtual-machines/instance-metadata-service?tabs=linux
      # - GCP: https://cloud.google.com/compute/docs/metadata/overview
# - Make -c command line parameter optional. When not provided, pull from github.

export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export NC='\033[0m' # No Color
export NORMAL=$NC
#############################################################
# Function: check_https_url
# Description : Check HTTPS url with the returned HttpStatus code
#############################################################
check_https_url()
{
	StatusCode=$(curl $1 --insecure --connect-timeout 4 -s -o /dev/null -w "%{http_code}")
	if [ "$StatusCode" -ge 200 ] && [ "$StatusCode" -le 404 ];
	then
      printf "| %-60s | %-30s |\n" "${1}" "${GREEN} REACHABLE ${NORMAL}"
	else
	    printf "| %-60s | %-30s |\n" "${1}" "${RED} NOT-REACHABLE ${NORMAL}"
        overallstatus=1
	fi
}
#############################################################
# Function: check_nonhttp
# Description : Check TCP successful connection
#############################################################
check_nonhttp()
{
  #Usage  nc -v -w 2 https://test.v2.ccm.eu-1.cdp.cloudera.com 443
	check=`nc -v -w 2 $1 $2 | grep succeeded | wc -l`
	if [ $check -eq 1 ];then
	  printf "| %-60s | %-30s |\n" "${1}" "${GREEN} REACHABLE ${NORMAL}"
  else
    printf "| %-60s | %-30s |\n" "${1}" "${RED} NOT-REACHABLE ${NORMAL}"
    overallstatus=1;
  fi;
}
#############################################################
# Function: output functions
#############################################################
function log(){
    local msg=$1
    local title=$2
    echo -e "[ $(date) ] [${title}]: ${msg}"
}

function state() {
    local msg=$1
    local flag=$2


    if [ "$flag" -eq 0 ]; then
        echo -e "[ $(date) ] [${GREEN} PASS ${NC}] $msg" >$(tty)
    elif [ "$flag" -eq 2 ]; then
        echo -e "[ $(date) ] [${YELLOW} WARN ${NC}] $msg" >$(tty)
    else
        echo -e "[ $(date) ] [${RED} FAIL ${NC}] $msg" >$(tty)
    fi
}

#Running https CHECKS

export overallstatus=0
while getopts ":p:g:c:h" opt_name
do
    case $opt_name in
        p)  export CSP=$(echo $OPTARG|tr "[A-Z]" "[a-z]")
            if [[ "aws azure gcp" =~ "$CSP" ]]; then
              log "Cloud Privider is $OPTARG" "INFO"
            else 
              log "Cloud provider must be one of aws, azure, and gcp" "FATAL"
              exit 2
            fi
            ;;
        g)  export CDPcontrolplaneregion=$(echo $OPTARG|tr "[a-z]" "[A-Z]")
            if [[ "US EU AP" =~ "$CDPcontrolplaneregion" ]]; then
              log "Geographic selection is $OPTARG" "INFO"
            else
              log "CDP Control plane region must be one of US, AP, EU." "FATAL"
              exit 2
            fi
            ;;
        c)  export nw_endpoints=$OPTARG
            if [ -e $nw_endpoints ]; then
              log "Using config file $nw_endpoints " "INFO"
            else
              log "Config file $nw_endpoints doesn't exist. " "FATAL"
              exit 2
            fi
            ;;
        h) echo "$0 -p <Cloud Provider: aws|azure|gcp> -g <Geographic: us|eu|ap> -c <path to config file> [ -h ]"
            ;;
        :) LOG "$OPTARG Option need a argument" "FATAL"
           exit 1
            ;;
    esac
done

if [ -z "$CSP" ]; then
    log "Missing Cloud provider infomation, please use -p commandline option to specify the Cloud provider. " "FATAL"
    exit 2
fi

if [ -z "$CDPcontrolplaneregion" ]; then
    log "Missing CDP controplane region infomation, please use -g commandline option to specify the controplane location. " "FATAL"
    exit 2
fi

if [ -z "$nw_endpoints" ]; then
    log "Missing location for config file, please use -c commandline option to specify the config file. " "FATAL"
    exit 2
fi

log "CHECKING HTTPS ENDPOINTS" "INFO"

echo "| ================================================================================== |"
printf "| %-60s | %-10s | \n" "Endpoint URL" "Validation Result  "
echo "| ================================================================================== |"

# Checking general global endpoints
for url in `cat $nw_endpoints|jq '.general.global[]'|tr -d '"'`
do
  check_https_url $url
done

# checking regional endpoints
for url in `cat $nw_endpoints|jq ".general.${CDPcontrolplaneregion}[]"|tr -d '"'`
do 
  check_https_url $url
done

# checking CSP endpoints
for url in `cat $nw_endpoints|jq ".${CSP}[]"|tr -d '"'`
do 
  check_https_url $url
done

echo "| ================================================================================== |"

state "Network validation status" $overallstatus

## Check Final Status of Network Validation and Report to Error File.
if [ "$overallstatus" -eq 1 ]; then
  message="${RED} Some Network Endpoints are UNREACHABLE. Recommended Actions to solve it:\n "
  message+="${GREEN} Please be sure all CDP AWS Outbound Endpoints are reachable. Check your Security Groups, NACLs & Firewalls. ${NC} \n "
  message+="${GREEN} Refer https://docs.cloudera.com/cdp-public-cloud/cloud/requirements-aws/topics/mc-outbound_access_requirements.html for details ${NC}\n "
  printf "${message}"
fi
