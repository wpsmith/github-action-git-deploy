  
FROM debian:9.7-slim

LABEL "com.github.actions.name"="GitHub Action for Git Deployment"
LABEL "com.github.actions.description"="An action to deploy your repository to a a site via git."
LABEL "com.github.actions.icon"="chevrons-right"
LABEL "com.github.actions.color"="blue"

LABEL "repository"="http://github.com/wpsmith/github-action-git-deploy"
LABEL "maintainer"="Travis Smith <t@wpsmith.net>"

RUN apt-get update && apt-get install -y git

ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
