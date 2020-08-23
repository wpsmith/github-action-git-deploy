# Git Deploy Github Action

This action deploys a specified/current branch to a remote git repository.

## Inputs

### `repository`

**Required** The SSH url of the target repository.

### `ssh_key`

**Required** The SSH key used to push to the registry. The SSH key is
configured with the local git config, enabling this action to run
authenticated git commands.

Follow [these](https://developer.github.com/v3/guides/managing-deploy-keys/#deploy-keys)
instructions to create and integrate a deploy key with the target repo.

### `ssh_known_hosts`

The known hosts to run SSH commands against. By default, `github.com` is used
as the known host.

### `name`

**Required** A name for the git user create the git commit.

### `email`

**Required** An email for the git user creating the git commit.

## Example Usage

```yaml
name: Deploy git repo to another git repo
uses: wpsmith/github-action-git-deploy@v0.1
with:
  repository: ${{ secrets.MY_OTHER_REPO_SSH_URI }}
  ssh_key: ${{ secrets.MY_SSH_KEY }}
  name: ${{ secrets.MY_NAME }}
  email: ${{ secrets.MY_EMAIL }}
```