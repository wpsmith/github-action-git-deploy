FROM alpine:3.10

RUN apk add --no-cache openssh git bash sshpass expect coreutils

COPY entrypoint.sh /entrypoint.sh

ENV SSH_AUTH_SOCK /tmp/ssh_agent.sock

ENTRYPOINT ["/bin/bash", "-c", "/entrypoint.sh"]
