#!/bin/bash

ROOT=/root

if [[ -n "$INPUT_DEBUG" ]]; then
    echo "================================================"
    echo "Version: v$(cat VERSION)"
    echo "INPUT_REMOTE_BRANCH: $INPUT_REMOTE_BRANCH"
    echo "INPUT_REPOSITORY: $INPUT_REPOSITORY"
    echo "INPUT_SSH_PASSWORD: $INPUT_SSH_PASSWORD"
    echo "INPUT_SSH_PUBLIC_KEY: $INPUT_SSH_PUBLIC_KEY"
    echo "INPUT_SSH_PRIVATE_KEY: "
    echo "$INPUT_SSH_PRIVATE_KEY"
    echo "================================================"
fi

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
if [[ -n "$INPUT_DEBUG" ]]; then
    echo "Setting SSHPASS"
fi
export SSHPASS="$INPUT_SSH_PASSWORD"
echo "Setting SSHPASS: $SSHPASS"

# Create .ssh directory
if [[ ! -d "$ROOT/.ssh" ]]; then
    if [[ -n "$INPUT_DEBUG" ]]; then
        echo "creating $ROOT/.ssh"
    fi
    mkdir -p "$ROOT/.ssh"
fi

# Create known hosts.
if [[ ! -f "$ROOT/.ssh/known_hosts" ]]; then
    if [[ -n "$INPUT_DEBUG" ]]; then
        echo "creating $ROOT/.ssh/known_hosts"
    fi
    touch "$ROOT/.ssh/known_hosts"
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
    echo "KNOWN_HOSTS FILE:"
    echo $(cat "$ROOT/.ssh/known_hosts")
fi

# SSH files.
if [[ -n "$INPUT_DEBUG" ]]; then
    echo "creating ssh key files"
fi
printenv INPUT_SSH_PRIVATE_KEY > "$ROOT/.ssh/id_rsa_sg"
# echo "$INPUT_SSH_PRIVATE_KEY" | tr -d '\r' > "$ROOT/.ssh/id_rsa_sg"
chmod 600 "$ROOT/.ssh/id_rsa_sg"
if [[ -n "$INPUT_DEBUG" ]]; then
    echo $(cat "$ROOT/.ssh/id_rsa_sg")
fi

printenv INPUT_SSH_PUBLIC_KEY > "$ROOT/.ssh/id_rsa_sg.pub"
chmod 600 "$ROOT/.ssh/id_rsa_sg.pub"
if [[ -n "$INPUT_DEBUG" ]]; then
    echo $(cat "$ROOT/.ssh/id_rsa_sg.pub")
fi

# Createe SSH config
if [[ ! -f "$ROOT/.ssh/config" ]]; then
    if [[ -n "$INPUT_DEBUG" ]]; then
        echo "creating .ssh/config"
    fi
    touch "$ROOT/.ssh/config"
    echo "Host $URL_HOST
  HostName $URL_HOST" >> "$ROOT/.ssh/config"
    if [[ -f "$ROOT/.ssh/known_hosts" ]]; then
        echo "  IdentityFile $ROOT/.ssh/id_rsa_sg" >> "$ROOT/.ssh/config"
    fi
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

if [[ -n "$INPUT_DEBUG" ]]; then
    echo "starting ssh agent; adding key"
fi
ssh-agent -a "$SSH_AUTH_SOCK" > /dev/null
echo "$INPUT_SSH_PRIVATE_KEY" | ssh-add -

if [[ -n "$INPUT_DEBUG" ]]; then
    echo "updating git config"
fi
export GIT_SSH_COMMAND="sshpass -p \"$INPUT_SSH_PASSWORD\" ssh -o UserKnownHostsFile=$ROOT/.ssh/known_hosts"
git config core.sshCommand "$GIT_SSH_COMMAND"
git config --global ssh.variant ssh


if [[ -n "$INPUT_DEBUG" ]]; then
    echo "git config"
    git --no-pager config -l

    echo "git status"
    git status
    git show-ref
fi

if [[ -n "$INPUT_DEBUG" ]]; then
    echo "adding remote upstream repo"
fi
git remote add upstream "$INPUT_REPOSITORY"
git fetch --all

if [[ -n "$INPUT_DEBUG" ]]; then
    echo "getting the current branch"
fi
current_branch=$(echo ${GITHUB_REF#refs/heads/})

if [[ -n "$INPUT_REMOTE_BRANCH" ]]; then
    branch="$INPUT_REMOTE_BRANCH"
else
    branch="$current_branch"
fi
if [[ -n "$INPUT_DEBUG" ]]; then
    echo "pushing current branch ($current_branch) to $branch"
    # GIT_SSH_VARIANT="sshpass -e ssh"
    # GIT_TRACE=true
    # GIT_CURL_VERBOSE=true
    # GIT_SSH_COMMAND="sshpass -e ssh -vvv -o UserKnownHostsFile=$ROOT/.ssh/known_hosts"
    # GIT_TRACE_PACK_ACCESS=true 
    # GIT_TRACE_PACKET=true 
    # GIT_TRACE_PACKFILE=true 
    # GIT_TRACE_PERFORMANCE=true 
    # GIT_TRACE_SETUP=true 
    # GIT_TRACE_SHALLOW=true
fi

git push -f upstream "HEAD:$branch"

exit
