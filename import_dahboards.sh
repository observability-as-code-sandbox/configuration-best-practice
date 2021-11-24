#!/bin/bash

# 1. INPUT PARAMETERS
_controller_url="${1}" # https://account-name.saas.appdynamics.com # http://on-prem-controller.appdynamics.com:8090

#todo: provide _user_credentials in ".local.user_credentials" file

_dashboard_name="${2}" # mandatory (without extension)
_proxy_details="${4}" # not mandatory

# 2. PREPARE

### Validate input parameters
### token
if ([ -z "${_user_credentials// }" ]); then
	_user_credentials=$(cat ".local.user_credentials") # ${username}:${password}
fi

if [ -z "${_user_credentials// }" ]; then
    echo "INPUT|ERROR|Token value cannot be empty '${_token}'"
    exit 1
fi

# create auth header
_auth_header="Authorization:Bearer ${_token}"

### application
if ([[ -z "${_dashboard_name// }" ]]); then
    echo "INPUT|ERROR|dashboard name has to be populated..."
    exit 1
fi

_dash_file="./dashboards/${_dashboard_name}.json" 

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
controllerReponse=$(curl -s --user "${_user_credentials}" ${_controller_url}/rest/applications ${_proxy_details} --connect-timeout 10)

if [ "$controllerReponse" = "" ]; then
    echo "INPUT|ERROR|Unable to connect to controller: '"$_controller_url"'. Aborting..."
    exit 1
fi

_dasboard_API_endpoint="CustomDashboardImportExportServlet"

# 3. UPLOAD
response=$(curl -s -X POST --user "${_user_credentials}" ${_controller_url}/${_dasboard_API_endpoint} -F file=@${_dash_file} ${_proxy_details})

echo "Reponse: ${response:0:15} }"

echo "Done"