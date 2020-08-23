#!/bin/bash

ROOT=./root

echo "INPUT_EMAIL: $INPUT_EMAIL"
echo "INPUT_NAME: $INPUT_NAME"
echo "INPUT_REPOSITORY: $INPUT_REPOSITORY"
echo "INPUT_SSH_PASSWORD: $INPUT_SSH_PASSWORD"
echo "INPUT_SSH_PUBLIC_KEY: $INPUT_SSH_PUBLIC_KEY"
echo "INPUT_SSH_PRIVATE_KEY: $INPUT_SSH_PRIVATE_KEY"
echo "================================================"


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
    if [[ -n "$INPUT_DEBUG" ]]; then
        echo "creating $ROOT/.ssh"
    fi
    mkdir -p "$ROOT/.ssh"
fi

if [[ ! -f "$ROOT/.ssh/known_hosts" ]]; then
    if [[ -n "$INPUT_DEBUG" ]]; then
        echo "creating $ROOT/.ssh/known_hosts"
    fi
    touch "$ROOT/.ssh/known_hosts"
fi

if [[ ! -f "$ROOT/.ssh/config" ]]; then
    if [[ -n "$INPUT_DEBUG" ]]; then
        echo "creating .ssh/config"
    fi
    touch "$ROOT/.ssh/config"
    echo "Host $URL_HOST
  HostName $URL_HOST
  IdentityFile $ROOT/.ssh/id_rsa_sg" >> "$ROOT/.ssh/config"
    if [ -n "$URL_PORT" ]; then
        echo "  Port $URL_PORT" >> "$ROOT/.ssh/config"
    fi
    if [ -n "$URL_USER" ]; then
        echo "  User $URL_USER" >> "$ROOT/.ssh/config"
    fi

    if [[ -n "$INPUT_DEBUG" ]]; then
        echo $(cat "$ROOT/.ssh/config")
    fi

    chmod 600 "$ROOT/.ssh/config"
fi

if [[ -n "$URL_HOST" ]]; then
    if [[ -n "$INPUT_DEBUG" ]]; then
        echo "adding git host to known_hosts"
    fi
    if [[ -n "$URL_PORT" ]]; then
        ssh-keyscan -t rsa -p "$URL_PORT" "$URL_HOST" >> "$ROOT/.ssh/known_hosts"
    else
        ssh-keyscan -t rsa "$URL_HOST" >> "$ROOT/.ssh/known_hosts"
    fi
fi

if [[ -z "$INPUT_SSH_KNOWN_HOSTS" ]]; then
    if [[ -n "$INPUT_DEBUG" ]]; then
        echo "adding github.com to known_hosts"
    fi
    ssh-keyscan -t rsa github.com >> "$ROOT/.ssh/known_hosts"
else
    if [[ -n "$INPUT_DEBUG" ]]; then
        echo "adding user defined known_hosts"
    fi
    echo "$INPUT_SSH_KNOWN_HOSTS" >> "$ROOT/.ssh/known_hosts"
fi

if [[ -n "$INPUT_DEBUG" ]]; then
    echo "adding ssh key"
fi

printenv INPUT_SSH_PRIVATE_KEY > "$ROOT/.ssh/id_rsa_sg"
# echo "$INPUT_SSH_PRIVATE_KEY" | tr -d '\r' > "$ROOT/.ssh/id_rsa_sg"
chmod 600 "$ROOT/.ssh/id_rsa_sg"
printenv INPUT_SSH_PUBLIC_KEY > "$ROOT/.ssh/id_rsa_sg.pub"
chmod 600 "$ROOT/.ssh/id_rsa_sg.pub"

# TO BE REMOVED
echo $(cat "$ROOT/.ssh/id_rsa_sg")
echo "Host github.com
  HostName github.com
  IdentityFile $ROOT/.ssh/id_rsa_sg" >> "$ROOT/.ssh/config"


if [[ -n "$INPUT_DEBUG" ]]; then
    echo "starting ssh agent"
fi
ssh-agent -a "$SSH_AUTH_SOCK" > /dev/null
ssh-add "$ROOT/.ssh/id_rsa_sg"
echo "$INPUT_SSH_PASSWORD"

git clone git@github.com:wpsmith/setantabooks.com.git app
cd app
exit
# END TO BE REMOVED

if [[ -n "$INPUT_DEBUG" ]]; then
    echo "updating git config"
fi
export SSHPASS="$INPUT_SSH_PASSWORD"
if [[ -n "$INPUT_DEBUG" ]]; then
    git config core.sshCommand "sshpass -e ssh -vvv -o UserKnownHostsFile=$ROOT/.ssh/known_hosts"
else
    git config core.sshCommand "sshpass -e ssh -o UserKnownHostsFile=$ROOT/.ssh/known_hosts"
fi
git config --global user.name "$INPUT_NAME"
git config --global user.email "$INPUT_EMAIL"
# git config --global ssh.variant ssh

if [[ -n "$INPUT_DEBUG" ]]; then
    echo "adding remote repo"
fi
git remote add upstream "$INPUT_REPOSITORY"

branch=$(echo ${GITHUB_REF#refs/heads/})
if [[ -n "$INPUT_DEBUG" ]]; then
    echo "pushing branch: $branch"
    GIT_SSH_VARIANT="sshpass -e ssh" \
    # GIT_TRACE=true \
    # GIT_CURL_VERBOSE=true \
    GIT_SSH_COMMAND="sshpass -e ssh -vvv -o UserKnownHostsFile=$ROOT/.ssh/known_hosts" \
    # GIT_TRACE_PACK_ACCESS=true \
    # GIT_TRACE_PACKET=true \
    # GIT_TRACE_PACKFILE=true \
    # GIT_TRACE_PERFORMANCE=true \
    # GIT_TRACE_SETUP=t/rue \
    # GIT_TRACE_SHALLOW=true \
    git push -fu upstream "$branch"
else
    git push -fu upstream "$branch"
fi

exit
