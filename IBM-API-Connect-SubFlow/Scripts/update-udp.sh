#!/bin/bash
set -e

SOURCE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ORG="demo"
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

WORK_PATH="${SOURCE_PATH}/udp"
UDP_API_FILE="${WORK_PATH}/${UDP_NAME}_${UDP_VERSION}-api.yaml"
UDP_DEF_FILE="${WORK_PATH}/${UDP_NAME}_${UDP_VERSION}-def.yaml"
UDP_ZIP_FILE="${WORK_PATH}/${UDP_NAME}_${UDP_VERSION}.zip"

echo -- Get api used for udp from drafts ...
${SOURCE_PATH}/apic draft-apis:get --server ${MGMT_ENDPOINT} --org ${ORG} ${UDP_NAME}:${UDP_VERSION} --output - > ${UDP_API_FILE}

echo -- Create udp yaml ...
mkdir -p "${WORK_PATH}"
yq eval -n '.policy = "1.0.0"' > ${UDP_DEF_FILE}
yq eval '.info.name = "'"${UDP_NAME}"'"' ${UDP_DEF_FILE} --inplace
yq eval '.info.version = "'"${UDP_VERSION}"'"' ${UDP_DEF_FILE} --inplace
yq eval-all 'select(fileIndex == 0).info.title = select(fileIndex == 1).info.title | select(fileIndex == 0)' ${UDP_DEF_FILE} ${UDP_API_FILE} --inplace
yq eval-all 'select(fileIndex == 0).info.description = select(fileIndex == 1).info.description | select(fileIndex == 0)' ${UDP_DEF_FILE} ${UDP_API_FILE} --inplace
yq eval-all 'select(fileIndex == 0).info.contact = select(fileIndex == 1).info.contact | select(fileIndex == 0)' ${UDP_DEF_FILE} ${UDP_API_FILE} --inplace
yq eval-all 'select(fileIndex == 0).attach = select(fileIndex == 1).x-udp.attach | select(fileIndex == 0)' ${UDP_DEF_FILE} ${UDP_API_FILE} --inplace
yq eval-all 'select(fileIndex == 0).gateways = select(fileIndex == 1).x-udp.gateways | select(fileIndex == 0)' ${UDP_DEF_FILE} ${UDP_API_FILE} --inplace
yq eval-all 'select(fileIndex == 0).properties = select(fileIndex == 1).x-udp.properties | select(fileIndex == 0)' ${UDP_DEF_FILE} ${UDP_API_FILE} --inplace

echo -- Add assembly from api used for udp to udp yaml ...
yq eval-all 'select(fileIndex == 0).assembly = select(fileIndex == 1).x-ibm-configuration.assembly | select(fileIndex == 0)' ${UDP_DEF_FILE} ${UDP_API_FILE} --inplace

cd "${WORK_PATH}"
zip -qq --junk-paths - "${UDP_DEF_FILE}" > "${UDP_ZIP_FILE}"
cd - 2>&1 > /dev/null

echo -- Loop over all gateway services in ${CATALOG} ...
GATEWAY_SERVICES=$(${SOURCE_PATH}/apic configured-gateway-services:list --scope catalog --server ${MGMT_ENDPOINT} --org ${ORG} --catalog ${CATALOG} 2>/dev/null | awk '{print $1}')

if [ ! -z $GATEWAY_SERVICES ]; then
	echo "${GATEWAY_SERVICES}" | while read GATEWAY_SERVICE; do
		echo ---- Check if udp exist in ${CATALOG} ...
		NEED_TO_CREATE=false
		${SOURCE_PATH}/apic policies:get --scope catalog --server ${MGMT_ENDPOINT} --org ${ORG} --catalog ${CATALOG} --configured-gateway-service ${GATEWAY_SERVICE} ${UDP_NAME}:${UDP_VERSION} --output - > /dev/null 2>&1 || NEED_TO_CREATE=true

		if [ "${NEED_TO_CREATE}" = false ]; then
			echo ---- Update udp in ${CATALOG} ...
			${SOURCE_PATH}/apic policies:update --scope catalog --server ${MGMT_ENDPOINT} --org ${ORG} --catalog ${CATALOG} --configured-gateway-service ${GATEWAY_SERVICE} ${UDP_NAME}:${UDP_VERSION} ${UDP_ZIP_FILE} 2>&1 > /dev/null
		else
			echo ---- Create udp in ${CATALOG} ...
			${SOURCE_PATH}/apic policies:create --scope catalog --server ${MGMT_ENDPOINT} --org ${ORG} --catalog ${CATALOG} --configured-gateway-service ${GATEWAY_SERVICE} ${UDP_ZIP_FILE} 2>&1 > /dev/null
		fi
		sleep 1
	done
else
	echo ---- No gateway services available for ${CATALOG} ...
fi
echo -- End loop over all gateway services in ${CATALOG} ...
