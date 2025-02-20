#!/usr/bin/env bash

set -eux

# Description:
#   Runs the feature tests in dynamic jenkins worker
# Usage:
#  ./feature_tests.sh

CI_DIR="$(dirname "$(readlink -f "${0}")")"

export IMAGE_OS="${IMAGE_OS:-ubuntu}"
export REPO_ORG="${REPO_ORG:-metal3-io}"
export REPO_NAME="${REPO_NAME:-metal3-dev-env}"
export UPDATED_REPO="${UPDATED_REPO:-https://github.com/${REPO_ORG}/${REPO_NAME}.git}"
export UPDATED_BRANCH="${UPDATED_BRANCH:-main}"
export CAPI_VERSION="${CAPI_VERSION:-v1beta1}"
export CAPM3_VERSION="${CAPM3_VERSION:-v1beta1}"
export CAPM3RELEASEBRANCH="${CAPM3RELEASEBRANCH:-main}"
export BMORELEASEBRANCH="${BMORELEASEBRANCH:-main}"
export NUM_NODES="${NUM_NODES:-4}"
export TESTS_FOR="${TESTS_FOR:-e2e_tests}"
export TARGET_NODE_MEMORY="${TARGET_NODE_MEMORY:-4096}"
export GINKGO_FOCUS="${GINKGO_FOCUS:-}"
export GINKGO_SKIP="${GINKGO_SKIP:-}"
export KUBECTL_SHA256="${KUBECTL_SHA256:-}"
export KEEP_TEST_ENV="${KEEP_TEST_ENV:-false}"

# shellcheck disable=SC1091
source "${CI_DIR}/integration_test_env.sh"

# Only set these variables if they actually have values.
# If the variable is unset or empty (""), do nothing.

if [[ "${CAPM3_VERSION}" == "v1alpha5" ]]; then
    export KUBERNETES_VERSION="v1.23.8"
    export KUBECTL_SHA256="${KUBECTL_SHA256:-4685bfcf732260f72fce58379e812e091557ef1dfc1bc8084226c7891dd6028f}"
fi

if [[ "${GINKGO_SKIP}" == "null" ]]; then
    unset GINKGO_SKIP
fi

if [[ "${KUBECTL_SHA256}" == "null" ]]; then
    unset KUBECTL_SHA256
fi

# Since we take care of the repo tested here (to merge the PR), do not update
# the repo in metal3-dev-env 03_launch_mgmt_cluster.sh
export FORCE_REPO_UPDATE=false

if [[ "${IMAGE_OS}" == "ubuntu" ]]; then
    #Must match with run_fetch_logs.sh
    export CONTAINER_RUNTIME="docker"
    export EPHEMERAL_CLUSTER="kind"
else
    export EPHEMERAL_CLUSTER="minikube"
fi

# Clone the source repository
git clone "https://github.com/${REPO_ORG}/${REPO_NAME}.git" tested_repo
cd tested_repo
git checkout "${REPO_BRANCH}"
# If the target and source repos and branches are identical, don't try to merge
if [[ "${UPDATED_REPO}" != *"${REPO_ORG}/${REPO_NAME}"* ]] ||
    [[ "${UPDATED_BRANCH}" != "${REPO_BRANCH}" ]]; then
    git config user.email "test@test.test"
    git config user.name "Test"
    git remote add test "${UPDATED_REPO}"
    git fetch test
    # Merging the PR with the target branch
    git merge "${UPDATED_BRANCH}" || exit
fi
cd ../

if [[ "${REPO_NAME}" == "metal3-dev-env" ]] ||
    [[ "${REPO_NAME}" == "cluster-api-provider-metal3" ]] \
    ; then
    # If we are testing e2e from capm3,
    # it will already be cloned to tested_repo
    pushd tested_repo
else
    # if the test is e2e clone capm3 and run the test from there
    git clone "${CAPM3REPO}" metal3
    pushd metal3
    git checkout "${CAPM3BRANCH}"
fi

echo "Running the tests"

make test-e2e
