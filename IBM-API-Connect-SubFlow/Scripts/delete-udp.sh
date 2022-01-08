#!/bin/bash
set -e

SOURCE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ORG="demp"
CATALOG="sandbox"
CMC_ENDPOINT="cmc.172-16-115-22.nip.io:443"
MGMT_ENDPOINT="mgmt.172-16-115-22.nip.io:443"
UDP_NAME="subflow-udp"
UDP_VERSION="1.0.0"

#${SOURCE_PATH}/apic --accept-license --live-help client-creds:set ${SOURCE_PATH}/credentials.json 2>&1 > /dev/null
${SOURCE_PATH}/apic --accept-license --live-help client-creds:clear 2>&1 > /dev/null

ID_PR_LIST=$(${SOURCE_PATH}/apic identity-providers:list --scope provider --server ${CMC_ENDPOINT})
ID_PR_NUM=$(echo "${ID_PR_LIST}" | wc -l | xargs)
if [[ "$ID_PR_NUM" -ge 2 ]]; then
  echo Choose provider realm [1..$ID_PR_NUM]: ...
  echo "${ID_PR_LIST}" | nl -w2

  read -p 'Selection: ' SELECTION
  PROVIDER_REALM=$(echo "${ID_PR_LIST}" | sed -n ${SELECTION}p)
else
  PROVIDER_REALM=$(echo "${ID_PR_LIST}" | awk '{print $1}')
fi

./apic login --server ${MGMT_ENDPOINT} --realm provider/${PROVIDER_REALM}

echo -- Loop over all gateway services in ${CATALOG} ...
GATEWAY_SERVICES=$(${SOURCE_PATH}/apic configured-gateway-services:list --scope catalog --server ${MGMT_ENDPOINT} --org ${ORG} --catalog ${CATALOG} 2>/dev/null | awk '{print $1}')

if [ ! -z $GATEWAY_SERVICES ]; then
	echo "${GATEWAY_SERVICES}" | while read GATEWAY_SERVICE; do
		echo ---- Remove udp from ${CATALOG} ...
		./apic policies:delete --scope catalog --server ${MGMT_ENDPOINT} --org ${ORG} --catalog ${CATALOG} --configured-gateway-service ${GATEWAY_SERVICE} ${UDP_NAME}:${UDP_VERSION} 2>&1 > /dev/null || true
		sleep 1
	done
else
	echo ---- No gateway services available for ${CATALOG} ...
fi
echo -- End loop over all gateway services in ${CATALOG} ...
