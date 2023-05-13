#!/bin/bash

# versoin 0.1.1

# Command line parameters
# cloud provider: -p
# geographic:     -g
# help:           -h

# coming enhancement
#   - Make -p and -g command line parameter optional. CSP info can be found with CSP metadata service. 
      # - AWS: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-identity-documents.html
      # - Azure: https://learn.microsoft.com/en-us/azure/virtual-machines/instance-metadata-service?tabs=linux
      # - GCP: https://cloud.google.com/compute/docs/metadata/overview

################ ENDPOINTS ################
global_endpoints=(
  "https://raw.githubusercontent.com"
  "https://github.com"
  "https://s3.amazonaws.com"
  "https://test.s3.amazonaws.com"
  "https://archive.cloudera.com"
  "https://api.us-west-1.cdp.cloudera.com"
  "https://container.repository.cloudera.com"
  "https://docker.repository.cloudera.com"
  "https://container.repo.cloudera.com"
  "https://auth.docker.io"
  "https://cloudera-docker-dev.jfrog.io"
  "https://docker-images-prod.s3.amazonaws.com"
  "https://gcr.io"
  "https://k8s.gcr.io"
  "https://quay-registry.s3.amazonaws.com"
  "https://quay.io"
  "https://quayio-production-s3.s3.amazonaws.com"
  "https://docker.io"
  "https://production.cloudflare.docker.com"
  "https://storage.googleapis.com"
  "https://consoleauth.us-west-1.core.altus.cloudera.com"
  "https://consoleauth.altus.cloudera.com"
  "https://pypi.org"
)

us_endpoints=(
  "https://test.v2.ccm.us-west-1.cdp.cloudera.com"
  "https://dbusapi.us-west-1.sigma.altus.cloudera.com"
  "http://api.us-west-1.cdp.cloudera.com"
  "https://test.s3.us-west-2.amazonaws.com"
)
eu_endpoints=(
  "https://test.v2.ccm.eu-1.cdp.cloudera.com"
  "https://api.eu-1.cdp.cloudera.com"
  "https://test.s3.eu-west-1.amazonaws.com"
)
ap_endpoints=(
  "https://test.v2.ccm.ap-1.cdp.cloudera.com"
  "https://api.ap-1.cdp.cloudera.com"
  "https://test.s3.ap-southeast-1.amazonaws.com"
)
aws_endpoints=("https://sts.amazonaws.com")
azure_endpoints=("https://management.azure.com")
gcp_endpoints=(
  "https://storage.googleapis.com",
  "https://iamcredentials.googleapis.com"
)
################ End Endpoints ##############


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
      printf "| %-60s | ${GREEN}%-19s${NORMAL} |\n" "${1}" " REACHABLE "
	else
	    printf "| %-60s | ${RED}%-19s${NORMAL} |\n" "${1}" " NOT-REACHABLE "
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
	  printf "| %-60s | ${GREEN}%-19s${NORMAL} |\n" "${1}" " REACHABLE "
  else
    printf "| %-60s | ${RED}%-19s${NORMAL} |\n" "${1}" " NOT-REACHABLE "
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
            if [ "$CDPcontrolplaneregion" = "US" ]; then
              regional_endpoints=$us_endpoints
            elif [ "$CDPcontrolplaneregion" = "EU" ]; then
              regional_endpoints=$eu_endpoints
            else
              regional_endpoints=$ap_endpoints
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
if [ "$CSP" = "aws" ]; then
  csp_endpoints=$aws_endpoints
elif [ "$CSP" = "azure" ]; then
  csp_endpoints=$azure_endpoints
else
  csp_endpoints=$gcp_endpoints
fi

if [ -z "$CDPcontrolplaneregion" ]; then
    log "Missing CDP controplane region infomation, please use -g commandline option to specify the controplane location. " "FATAL"
    exit 2
fi

log "CHECKING HTTPS ENDPOINTS" "INFO"

echo "| ================================================================================== |"
printf "| %-60s | %-19s | \n" "Endpoint URL" "Validation Result  "
echo "| ================================================================================== |"

# Checking general global endpoints
for url in ${global_endpoints[@]}
do
  check_https_url $url
done

# checking regional endpoints
for url in ${regional_endpoints[@]}
do 
  check_https_url $url
done

# checking CSP endpoints
for url in ${csp_endpoints[@]}
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
