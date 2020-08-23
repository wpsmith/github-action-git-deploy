#!/bin/bash

ROOT=/root

parse_url() {
    local url=""
    URL_PROTO="$(echo $1 | grep :// | sed -e's,^\(.*://\).*,\1,g')"
    # remove the protocol
    url="$(echo ${1/$URL_PROTO/})"
    # extract the user (if any)
    URL_USERPASS="$(echo $url | grep @ | cut -d@ -f1)"
    URL_PASS="$(echo $URL_USERPASS | grep : | cut -d: -f2)"
    if [ -n "$URL_PASS" ]; then
        URL_USER="$(echo $URL_USERPASS | grep : | cut -d: -f1)"
    else
        URL_USER=$URL_USERPASS
    fi

    # extract the host
    URL_HOST="$(echo ${url/$URL_USER@/} | cut -d/ -f1)"
    # by request - try to extract the port
    URL_PORT="$(echo $URL_HOST | sed -e 's,^.*:,:,g' -e 's,.*:\([0-9]*\).*,\1,g' -e 's,[^0-9],,g')"
    if [ -n "$URL_PORT" ]; then
        URL_HOST="$(echo $URL_HOST | grep : | cut -d: -f1)"
    fi
    # extract the path (if any)
    URL_PATH="$(echo $url | grep / | cut -d/ -f2-)"
}

parse_url "$INPUT_REPOSITORY"

if [[ ! -d "$ROOT/.ssh" ]]; then
    echo "$ROOT/.ssh does not exist, creating it"
    mkdir -p "$ROOT/.ssh"
fi

if [[ ! -f "$ROOT/.ssh/known_hosts" ]]; then
    echo "$ROOT/.ssh/known_hosts does not exist, creating it"
    touch "$ROOT/.ssh/known_hosts"
fi

if [[ -z "$URL_HOST" ]]; then
    echo "adding git host to known_hosts"
    ssh-keyscan -t rsa "$URL_HOST" > "$ROOT/.ssh/known_hosts"
fi
if [[ -z "$INPUT_SSH_KNOWN_HOSTS" ]]; then
    echo "adding github.com to known_hosts"
    ssh-keyscan -t rsa github.com > "$ROOT/.ssh/known_hosts"
else
    echo "adding user defined known_hosts"
    echo "$INPUT_SSH_KNOWN_HOSTS" > "$ROOT/.ssh/known_hosts"
fi

echo "adding ssh key"
echo "$INPUT_SSH_KEY" | tr -d '\r' > "$ROOT/.ssh/id_rsa_sg"
ssh-agent -a "$SSH_AUTH_SOCK" > /dev/null
cat "$ROOT/.ssh/id_rsa_sg" | ssh-add -

echo "updating git config"
git config core.sshCommand "sshpass -p $INPUT_SSH_PASSWORD ssh -i $ROOT/.ssh/id_rsa_sg -o UserKnownHostsFile=$ROOT/.ssh/known_hosts"
git config --global user.name "$INPUT_NAME"
git config --global user.email "$INPUT_EMAIL"

echo "adding remote repo"
git remote add upstream "$INPUT_REPOSITORY"

branch=$(echo ${GITHUB_REF#refs/heads/})
echo "pushing branch: $branch"
git push -fu upstream "$branch"

exit
