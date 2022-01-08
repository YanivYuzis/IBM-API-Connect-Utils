# IBM API Connect SubfFlow

## Description
Utility for wrapping an assembly as an icon (User Defined Policy - UDP).
Very useful for reuse API login (like subflow).

The script pull API from drafts (APIM develope section) and generate dedicated policy based on API content:
- info block will be used for policy info
- assembly block will be used as policy logic.
- x-udp will be used for policy properties and valid runtimes (GW type, API type)

## Prerequisites
- [yq](https://github.com/mikefarah/yq) - YAML processor via CLI
- [apic](https://www.ibm.com/docs/en/api-connect/10.0.1.x?topic=configuration-installing-toolkit) - API Management via CLI

## Files
| File | Description |
| ------ | ------ |
| ./Scrips/create-udp.sh | Create UDP by name and version |
| ./Scrips/delete-udp.sh | Delete UDP by name and version |
| ./APis/subflow-udp_1.0.0.yaml | Sample API to wrrap as UDP |
| ./APis/test-subflow-udp_1.0.0.yaml | Sample API to test the new UDP |

## Prepare the sample
```
Edit connection info in [./Scripts/delete-udp.sh] and [./Scripts/create-udp.sh]
- ORG="???"
- CATALOG="???"
- CMC_ENDPOINT="???"
- MGMT_ENDPOINT="???"
Import [./APis/subflow-udp_1.0.0.yaml] into drafts (publish not needed)
Execute [./Scripts/create-udp.sh]
Import [./APis/test-subflow-udp_1.0.0.yaml] into drafts
Publish and test the API (debug message expected in API GW)
```
## Notes
- ./udp folder will be created with temp files during process.
- UPD name and version are hard coded in the scripts.
