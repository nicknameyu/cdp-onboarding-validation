#!/bin/bash

# versoin 0.1.1
# Command line parameters
# cloud provider: -p   aws, azure, gcp
# geographic:     -g   us, eu, ap
# help:           -h

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
  "https://api.us-west-1.cdp.cloudera.com"
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
  "https://storage.googleapis.com"
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
            ;;
        c)  export nw_endpoints=$OPTARG
            if [ -e $nw_endpoints ]; then
              log "Using config file $nw_endpoints " "INFO"
            else
              log "Config file $nw_endpoints doesn't exist. " "FATAL"
              exit 2
            fi
            ;;
        h) echo "$0 [-p <Cloud Provider: aws|azure|gcp>] [-g <Geographic: us|eu|ap>] [ -h ]"
            ;;
        :) LOG "$OPTARG Option need a argument" "FATAL"
           exit 1
            ;;
    esac
done

if [ -z "$CSP" ]; then
    log "Missing CSP info. Checking Meta data service for CSP. " "INFO"
    curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" 2>/dev/null|grep -i azure > /dev/null
    if [ $? -eq 0 ]; then
      log "Azure environment found." "INFO"
      CSP='azure'
    fi
    TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null`
    curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document 2>/dev/null|grep instanceId >/dev/null
    if [ $? -eq 0 ]; then
      log "AWS environment found." "INFO"
      CSP='aws'
    fi
    curl "http://metadata.google.internal/computeMetadata/v1/instance/image" -H "Metadata-Flavor: Google" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      log "GCP environment found." "INFO"
      CSP='gcp'
    fi
    if [ -z "$CSP" ]; then
      log "Missing Cloud provider infomation, and cannot identify CSP with meta data, please use -p commandline option to specify the Cloud provider. " "FATAL"
      exit 2
    fi
fi
if [ "$CSP" = "aws" ]; then
  csp_endpoints=${aws_endpoints[@]}
  eu_regions=("af-south-1" "eu-central-1" "eu-central-2" "eu-north-1" "eu-south-1" "eu-south-2" "eu-west-1" "eu-west-2" "eu-west-3" "me-central-1" "me-south-1")
  ap_regions=("ap-east-1" "ap-northeast-1" "ap-northeast-2" "ap-northeast-3" "ap-south-1" "ap-south-2" "ap-southeast-1" "ap-southeast-2" "ap-southeast-3" "ap-southeast-4" "cn-north-1" "cn-northwest-1")
  us_regions=("sa-east-1" "us-east-1" "us-east-2" "us-gov-east-1" "us-gov-west-1" "us-west-1" "us-west-2" "ca-central-1")
  TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null`
  metadata=`curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/dynamic/instance-identity/document 2>/dev/null`
elif [ "$CSP" = "azure" ]; then
  csp_endpoints=${azure_endpoints[@]}
  ap_regions=("eastasia" "southeastasia" "japanwest" "japaneast" "australiaeast" "australiasoutheast" "southindia" "centralindia" "westindia" "koreacentral" "koreasouth")
  us_regions=("centralus" "eastus" "eastus2" "westus" "northcentralus" "southcentralus" "northeurope" "westeurope" "brazilsouth" "canadacentral" "canadaeast" "westcentralus" "westus2")
  eu_regions=("uksouth" "ukwest" "francecentral" "francesouth" "australiacentral" "australiacentral2" "uaecentral" "uaenorth" "southafricanorth" "southafricawest")
  metadata=`curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01"`
else
  csp_endpoints=${gcp_endpoints[@]}
  ap_regions=("asia-south1" "asia-south2" "asia-east1" "asia-east2" "asia-northeast1" "asia-northeast2" "asia-northeast3" "asia-southeast1" "australia-southeast1" "australia-southeast2")
  eu_regions=("europe-central2" "europe-north2" "europe-southwest1" "europe-west1" "europe-west2" "europe-west3" "europe-west4" "europe-west4" "europe-west6" "europe-west8" "europe-west9")
  us_regions=("northamerica-northeast1" "northamerica-northeast2" "southamerica-east1" "us-central1" "us-east1" "us-east4" "us-west1" "us-west1" "us-west2" "us-west3" "us-west4" "us-west-1")
  metadata=`curl "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google" 2>/dev/null`
fi

if [ -z "$CDPcontrolplaneregion" ]; then
  log "Missing CDP controplane region infomation, using metadata default as the region mapping" "INFO"
  if [ -z $CDPcontrolplaneregion ]; then
      for location in ${us_regions[@]}
      do
        echo $metadata|grep $location >/dev/null
        if [ $? -eq 0 ]; then
          log "Found region $location, using US as the CDP control plane region" "INFO"
          CDPcontrolplaneregion="US"
          break
        fi
      done
  fi
  if [ -z $CDPcontrolplaneregion ]; then
      for location in ${eu_regions[@]}
      do
        echo $metadata|grep $location >/dev/null
        if [ $? -eq 0 ]; then
          log "Found region $location, using EU as the CDP control plane region" "INFO"
          CDPcontrolplaneregion="EU"
          break
        fi
      done
  fi
  if [ -z $CDPcontrolplaneregion ]; then
      for location in ${ap_regions[@]}
      do
        echo $metadata|grep $location >/dev/null
        if [ $? -eq 0 ]; then
          log "Found region $location, using AP as the CDP control plane region" "INFO"
          CDPcontrolplaneregion="AP"
          break
        fi
      done
  fi
  if [ -z $CDPcontrolplaneregion ]; then
    log "Missing CDP controplane region infomation, and cannot identify region with metadata. Please use -g commandline option to specify the controplane location. " "FATAL"
    exit 2
  fi
fi
if [ "$CDPcontrolplaneregion" = "US" ]; then
  regional_endpoints=${us_endpoints[@]}
elif [ "$CDPcontrolplaneregion" = "EU" ]; then
  regional_endpoints=${eu_endpoints[@]}
else
  regional_endpoints=${ap_endpoints[@]}
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
