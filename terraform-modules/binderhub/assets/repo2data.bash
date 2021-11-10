#!/bin/bash

# repo parameters
IFS='/'; BINDER_PARAMS=(${BINDER_REF_URL}); unset IFS;
PROVIDER_NAME=${BINDER_PARAMS[-5]}
USER_NAME=${BINDER_PARAMS[-4]}
REPO_NAME=${BINDER_PARAMS[-3]}
COMMIT_REF=${BINDER_PARAMS[-1]}
# paths
DATA_REQ_PATH="/home/jovyan/binder/data_requirement.json"
DATA_PATH="/mnt/data"

# checking if repo2data is necessary
echo "Checking if repo2data will be done..."
if [ -f "${DATA_REQ_PATH}" ]; then
  echo -e "\t ${DATA_REQ_PATH} exists."
  # creating repo2data log file
  PROJECT_NAME=$(python3 -c "import sys, json; print(json.load(open(\"binder/data_requirement.json\", \"r\"))['projectName'])")
  REPO2DATA_LOGDIR="${DATA_PATH}/${PROJECT_NAME}"
  REPO2DATA_LOG="${REPO2DATA_LOGDIR}/repo2data.log"
  # command call
  mkdir -p ${REPO2DATA_LOGDIR}
  cd /mnt
  repo2data --server -r ${DATA_REQ_PATH} 2>&1 | tee ${REPO2DATA_LOG}
  cd ${HOME}
else
  echo -e "\t ${DATA_REQ} not found."
  echo "Skipping repo2data."
fi