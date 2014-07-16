#!/bin/bash
#
# This script is invoked each time data has been accepted by the repository.
# It then updates, creates or deletes the working copy of the respective
# branches on dev.mdpi.lab.
#
# ssh configuration
SSH=ssh
SSH_PARAMS="mdpi@localhost"

# curl
CURL=curl

# location and names of the script that we use on hg.mdpi.intra for action
SCRIPTS_DIR="/var/www/git/scripts"
CREATE_WC_CMD="create_wc.sh"
DELETE_WC_CMD="delete_wc.sh"
JENKINS_URL="http://jenkins.mdpi.dev/jenkins/git/notifyCommit?url="

#
# *_wc
#
# All three functions update, create or delete the working copy of the
# specified branch. They all expect the name of the branch as their first
# parameter.
#
# @param    $1  name of the directory on hg.mdpi.intra
# @param    $2  project name
#
function update_wc() {
    echo "Updating branch $2 for $1"
    ${SSH} "${SSH_PARAMS}" "cd ${WCS_DIR}/${2} && git pull origin ${2}" &
    sleep 2
    ${SSH} "${SSH_PARAMS}" "cd ${WCS_DIR}/${2} && /usr/local/php5.5/bin/composer install" &

    #echo "trigger a jenkins build: ${JENKINS_URL}${GIT_URL}"
    #${CURL} "${JENKINS_URL}${GIT_URL}"
    #echo "Add unit test queue..."
    #$SCRIPTS_DIR/add_unittest.sh "${WCS_DIR}/${2}" > /dev/null
}
function create_wc() {
    echo "Creating branch $2 for $1"
    ${SSH} "${SSH_PARAMS}" "${SCRIPTS_DIR}/${CREATE_WC_CMD}" "${1}" "${2}" &
}
function delete_wc() {
    echo "Deleting branch $2 for $1"
    ${SSH} "${SSH_PARAMS}" "${SCRIPTS_DIR}/${DELETE_WC_CMD}" "${1}" "${2}" &
}

while read oval nval ref; do
    branch=$(basename "${ref}")
    echo "${oval} ${nval} ${ref}" | git-commit-notifier "${GIT_DIR}/hooks/git-notifier-config.yml"

    if expr "${oval}" : "0*$" >/dev/null; then
        create_wc "${PROJECT_NAME}" "${branch}"
    elif expr "${nval}" : "0*$" > /dev/null; then
        delete_wc "${PROJECT_NAME}" "${branch}"
    else
        update_wc "${PROJECT_NAME}" "${branch}"
    fi
done

#!/bin/bash
#
# This script creates a working copy for the specified branch in our
# development environment on dev.mdpi.lab.
#
# This script creates a directory named after the branch, checks out the
# branch and all its submodules and updates each of them. It then initiliazes
# the working copy. After this is finished, this script creates a link, so
# that we can access this working copy by using our web server.
#
#
HELP="Usage: $(basename $0) project_name branch_name"

if [ "$#" != "2" ]; then
    echo "${HELP}"
    exit 1
elif [ "$1" = "--help" -o "$1" = "-h" ]; then
    echo "${HELP}"
    exit 0
fi

branch="$2"

GIT="/usr/local/bin/git"
REPO="git@localhost:/home/git/projects/$1.git"
PROJECT_DIR="/var/www/git/branches/$1"
SCRIPTS_DIR="/var/www/git/scripts"

[ ! -d $PROJECT_DIR ] && mkdir -p $PROJECT_DIR

set -e
trap "${SCRIPTS_DIR}/delete_wc.sh ${branch}" ERR

cd "${PROJECT_DIR}"
test -e "${branch}" && echo "${branch} already exists" && exit 1

echo $GIT clone --depth 1 "${REPO}" "${branch}"
$GIT clone --depth 1 -b "${branch}" "${REPO}" "${branch}" >/dev/null

cd "${branch}"

echo "update composer"
/usr/local/php5.5/bin/composer install

echo "Done"
