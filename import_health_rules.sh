#!/bin/bash

# 1. INPUT PARAMETERS
_controller_url="<controller-url>/controller"   # hostname + /controller
_user_credentials="<credentials>" # ${username}:${password}
_application_name="<application-name>" #Producktion
_proxy_details=
_health_rules_overwrite=true
_include_sim=true

function func_get_application_id() {
    local _controller_url=${1} # hostname + /controller
    local _user_credentials=${2} # ${username}:${password}

    local _application_name=${3}
    local _proxy_details=${4} 

    # Get all applications
    allApplications=$(curl -s --user ${_user_credentials} ${_controller_url}/rest/applications?output=JSON ${_proxy_details})

    # Select by name
    applicationObject=$(jq --arg appName "$_application_name" '.[] | select(.name == $appName)' <<<$allApplications)

    if [ "$applicationObject" = "" ]; then
        exit 1
    fi

    appId=$(jq '.id' <<<$applicationObject)

    echo "${appId}"
}

function func_import_health_rules(){
    local appId=$1
    local folderPath=$2

     # get all current health rules for application
    allHealthRules=$(curl -s --user ${_user_credentials} ${_controller_url}/alerting/rest/v1/applications/${appId}/health-rules ${_proxy_details})

    for f in $folderPath; do 
        echo "Processing $f health rule template"
        # get health rule name from json file
        healthRuleName=$(jq -r  '.name' <$f)
        # use it to get health rule id (if exists)
        healthRuleId=$(jq --arg hrName "$healthRuleName" '.[] | select(.name == $hrName) | .id' <<<$allHealthRules)

        # create new if health rule id does not exist
        if [ "${healthRuleId}" == "" ]; then
            httpCode=$(curl -s -o /dev/null -w "%{http_code}" -X POST --user ${_user_credentials} ${_controller_url}/alerting/rest/v1/applications/${appId}/health-rules --header "Content-Type: application/json" --data "@${f}" ${_proxy_details})
            echo "HTTP code $httpCode"
        # overwrite existing health rule only if flag is true
        elif [ "${_health_rules_overwrite}" = true ]; then
            httpCode=$(curl -s -o /dev/null -w "%{http_code}" -X PUT --user ${_user_credentials} ${_controller_url}/alerting/rest/v1/applications/${appId}/health-rules/${healthRuleId} --header "Content-Type: application/json" --data "@${f}" ${_proxy_details})
            echo "HTTP code $httpCode"
        fi

    done
}

#init HR templates
serverVizHealthRuleFile="./health_rules/ServerVisibility/*.json"
applicationHealthRule="./health_rules/Application/*.json"

# get app id
echo "Getting app id..."
appId=$(func_get_application_id ${_controller_url} ${_user_credentials} ${_application_name} ${_proxy_details} )
echo "Application id is: ${appId}"

# 4. EXECUTE 

# Server Visibility health rules
if [ "${_include_sim}" = true ]; then
    echo "Creating Server Visibility Health Rules.."

    func_import_health_rules $appId "${serverVizHealthRuleFile}"
fi

# Application health rules
echo "Creating ${_application_name} Health Rules..."

func_import_health_rules $appId "${applicationHealthRule}"





