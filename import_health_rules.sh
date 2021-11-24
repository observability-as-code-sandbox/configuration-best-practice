#!/bin/bash
###
### to run:
### ./import_health_rules.sh https://account-name.saas.appdynamics.com KongApp
### ./import_health_rules.sh https://account-name.saas.appdynamics.com


# 1. INPUT PARAMETERS
_controller_url="${1}" # https://account-name.saas.appdynamics.com # http://on-prem-controller.appdynamics.com:8090
#_token="${2}" # provide in ".local.token" file

_application_name=${2} # not mandatory (unless importing application health rules)
_proxy_details=${3} # not mandatory

# to overwrite or not existing health rules
_health_rules_overwrite=false

### Modules: TRUE / FALSE
_include_app=false
_include_sim=true

_include_cluster_agent=false
_include_jvm=false

_include_database=false
_include_infrastructure=true

_include_custom=true

# In our demo saas controllers server id is 3 and database id is 1, however, this can vary based on controller
# navigate to servers/databases view and check appication_id query parameter in browser URL
_server_app_id=711
_db_app_id=711


### 2. Validate input parameters
### token
if ([ -z "${_token// }" ]); then
	_token=$(cat ".local.token")
fi

if [ -z "${_token// }" ]; then
    echo "INPUT|ERROR|Token value cannot be empty '${_token}'"
    exit 1
fi

# create auth header
_auth_header="Authorization:Bearer ${_token}"

### application
if [ -z "${_application_name// }" ]; then
    echo "INPUT|WARN|Application name is empty '${_application_name}'"
fi

### controller
_controller_host="$(echo $_controller_url | sed -e 's|^[^/]*//||' -e 's|/.*$||' -e 's|:.*$||')"
_controller_protocol="$(echo $_controller_url | grep :// | sed -e's,^\(.*://\).*,\1,g' | sed 's/.\{3\}$//' | tr '[:upper:]' '[:lower:]')"

# if host url does not contain protocol set https by default
if [ -z "${_controller_protocol}" ]; then
	_controller_protocol="https"
fi

_controller_url="$_controller_protocol://$_controller_host/controller"

echo "INPUT|INFO|Connecting to controller: '$_controller_url'"

# timeout after 10s
controllerReponse=$(curl -s -H "${_auth_header}" ${_controller_url}/rest/applications ${_proxy_details} --connect-timeout 10)

if [ "$controllerReponse" = "" ]; then
    echo "INPUT|ERROR|Unable to connect to controller: '"$_controller_url"'. Aborting..."
    exit 1
fi


# init HR templates
serverVizHealthRuleFile="./health_rules/ServerVisibility/*.json"
applicationHealthRule="./health_rules/Application/*.json"
clusterAgentHealthRule="./health_rules/ClusterAgent/*.json"
jvmHealthRule="./health_rules/JVM/*.json"
databaseHealthRule="./health_rules/Database/*.json"
infrastructureHealthRule="./health_rules/Infrastructure/*.json"

customHealthRule="./health_rules/Custom/*.json"


function func_get_application_id() {
    local _controller_url=${1} # hostname + /controller
    local _auth_header=${2}

    local _application_name=${3}
    local _proxy_details=${4} 

    # Get all applications
    allApplications=$(curl -s -H "${_auth_header}" ${_controller_url}/rest/applications?output=JSON ${_proxy_details})
    
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
    allHealthRules=$(curl -s -H "${_auth_header}" ${_controller_url}/alerting/rest/v1/applications/${appId}/health-rules ${_proxy_details})

    for f in $folderPath; do 
        echo "Processing $f health rule template"
        # get health rule name from json file
        healthRuleName=$(jq -r  '.name' <$f)
        # use it to get health rule id (if exists)
        healthRuleId=$(jq --arg hrName "$healthRuleName" '.[] | select(.name == $hrName) | .id' <<<$allHealthRules)

        # create new if health rule id does not exist
        if [ "${healthRuleId}" == "" ]; then
            httpCode=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "${_auth_header}" ${_controller_url}/alerting/rest/v1/applications/${appId}/health-rules --header "Content-Type: application/json" --data "@${f}" ${_proxy_details})
            echo "HTTP code $httpCode"
        # overwrite existing health rule only if flag is true
        elif [ "${_health_rules_overwrite}" = true ]; then
            httpCode=$(curl -s -o /dev/null -w "%{http_code}" -X PUT -H "${_auth_header}" ${_controller_url}/alerting/rest/v1/applications/${appId}/health-rules/${healthRuleId} --header "Content-Type: application/json" --data "@${f}" ${_proxy_details})
            echo "HTTP code $httpCode"
        fi

    done
}

# get app id
echo "Getting app id... '${_application_name}'"
appId=$(func_get_application_id "${_controller_url}" "${_auth_header}" "${_application_name}" "${_proxy_details}" )

echo "Application id is: ${appId}"

# 4. EXECUTE 

# Applicationhealth rules
if [ "${_include_app}" = true ]; then
    # Application health rules
    echo -e "\nCreating '${_application_name}' Health Rules..."

    func_import_health_rules $appId "${applicationHealthRule}"
fi

# Server Visibility health rules
if [ "${_include_sim}" = true ]; then
    echo -e "\nCreating Server Visibility '${_application_name}' Health Rules.."

    func_import_health_rules $appId "${serverVizHealthRuleFile}"
fi

# Cluster Agent health rules
if [ "${_include_cluster_agent}" = true ]; then
    echo -e "\nCreating Cluster Agent Health Rules.."

    func_import_health_rules "${_server_app_id}" "${clusterAgentHealthRule}"
fi

# Server/MA health rules
if [ "${_include_infrastructure}" = true ]; then
    echo -e "\nCreating Infrastructure Visibility Health Rules.."

    func_import_health_rules $"${_server_app_id}" "${infrastructureHealthRule}"
fi

# JVM health rules
if [ "${_include_jvm}" = true ]; then
    echo -e "\nCreating JVM '${_application_name}' Health Rules.."

    func_import_health_rules $appId "${jvmHealthRule}"
fi

# Database health rules
if [ "${_include_database}" = true ]; then
    echo -e "\nCreating Database Health Rules.."

    func_import_health_rules "$_db_app_id" "${databaseHealthRule}"
fi

# Custom health rules
if [ "${_include_custom}" = true ]; then
    echo -e "\nCreating Custom Health Rules.."

    func_import_health_rules "$appId" "${customHealthRule}"
fi






