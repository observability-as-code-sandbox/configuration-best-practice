#!/bin/bash

# 1. INPUT PARAMETERS
_controller_url="${1}" # https://account-name.saas.appdynamics.com # http://on-prem-controller.appdynamics.com:8090
# provide token in ".local.token" file

# one of the two has to be specified:
_application_name="${2}" # not mandatory (for applciations provide applciation name)
_application_id="${3}" # not mandatory (for servers/databases provide server/database applciation id)

_proxy_details="${4}" # not mandatory

# 2. PREPARE
dt=$(date '+%Y-%m-%d_%H-%M-%S')
destination_dir="./exported/"

### Validate input parameters
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
if ([[ -z "${_application_name// }" ]] && [ -z "${_application_id// }" ]); then
    echo "INPUT|ERROR|Application name and id are empty; One of the values has to be populated..."
    exit 1
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

# 3. FUNCTIONS
function func_get_application_id() {
    local _controller_url="${1}" # hostname + /controller
    local _auth_header="${2}"

    local _application_name="${3}"
    local _proxy_details="${4}"

    # Get all applications
    allApplications=$(curl -s -H "${_auth_header}" "${_controller_url}/rest/applications?output=JSON" ${_proxy_details})
    # Select by name
    applicationObject=$(jq --arg appName "$_application_name" '.[] | select(.name == $appName)' <<<$allApplications)
    if [ "$applicationObject" = "" ]; then
        exit 1
    fi

    appId=$(jq '.id' <<<$applicationObject)

    echo "${appId}"
}

# 4. EXPORT
# get app id
echo "Getting app id..."
if [ "${_application_id}" = "" ]; then
    appId=$(func_get_application_id "${_controller_url}" "${_auth_header}" "${_application_name}" "${_proxy_details}" )
else 
    appId="${_application_id}"
    _application_name=$"$appId"
fi

echo "Application id is: ${appId}"

# get all current health rules for application
allHealthRules=$(curl -s -H "${_auth_header}" ${_controller_url}/alerting/rest/v1/applications/${appId}/health-rules ${_proxy_details})

# Save
echo "Save to file..."
destination_file="${_application_name}.json"
output=${destination_dir}/${destination_file}
touch ${output}

echo "$allHealthRules" > "${output}"

files_dir="${destination_dir}/${_application_name}"
mkdir "${files_dir}"

jq -c '.[]' "${output}" | while read i; do
    #echo $i
    hrId=$(jq  '.id' <<<$i)
    
    hrDest="${files_dir}/${hrId}.json"

    hrName=$(jq  '.name' <<<$i)
    #echo $hrName | tr -d '"'

    #echo "curl -s -H '${_auth_header}' ${_controller_url}/alerting/rest/v1/applications/${appId}/health-rules/$hrId"
    hrObject=$(curl -s -H "${_auth_header}" ${_controller_url}/alerting/rest/v1/applications/${appId}/health-rules/$hrId ${_proxy_details})
    
    echo $hrObject > "${hrDest}"

done

echo "Done"