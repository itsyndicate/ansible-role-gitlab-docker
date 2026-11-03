# ansible-role-gitlab-docker

Ansible role that installs Docker Engine on Ubuntu and runs GitLab CE in a container with Docker Compose.

It follows the official docs:

- Docker Engine from Docker's apt repository: https://docs.docker.com/engine/install/ubuntu/
- GitLab in Docker Compose: https://docs.gitlab.com/install/docker/installation/

Step-by-step guide: https://itsyndicate.org/blog/install-and-configure-gitlab-server-inside-docker/

## What it does

1. Installs Docker Engine and the Compose plugin from `download.docker.com`.
2. Writes `/srv/gitlab/compose.yml` with the `gitlab/gitlab-ce` image, `GITLAB_OMNIBUS_CONFIG`, volumes and ports.
3. Starts GitLab with `community.docker.docker_compose_v2` and waits until GitLab answers on its readiness endpoint `/-/readiness`.

With an `https://` external URL, GitLab gets and renews a Let's Encrypt certificate on its own. A second run changes nothing unless you change a variable.

## Requirements

- Control machine: `ansible-core` 2.18 or newer and the `community.docker` collection.
- Target: Ubuntu 22.04 or 24.04 LTS with a user that has `sudo`. GitLab recommends 8 vCPU and 16 GB of RAM; 8 GB is the minimum for a small team.
- DNS records for GitLab (and the registry, if you use it) pointing to the server.
- Ports 80 and 443 open to the internet if you want Let's Encrypt.
- Port 22 free for GitLab SSH, or set `gitlab_ssh_port` to something else (for example `2424`).

## Install

```yaml
# requirements.yml
roles:
  - name: gitlab
    src: https://github.com/itsyndicate/ansible-role-gitlab-docker.git
    scm: git
    version: main

collections:
  - name: community.docker
    version: ">=4.0.0"
```

```shell
ansible-galaxy install -r requirements.yml
```

## Example playbook

```yaml
- name: Deploy GitLab in Docker
  hosts: gitlab
  become: true
  roles:
    - gitlab
```

A complete example (inventory, host_vars) is in [`examples/`](examples/).

## Variables

| Variable | Default | Description |
|---|---|---|
| `gitlab_hostname` | `gitlab.example.com` | Hostname of the instance |
| `gitlab_external_url` | `https://{{ gitlab_hostname }}` | `external_url` in `gitlab.rb`. `https://` turns on Let's Encrypt |
| `gitlab_registry_external_url` | `""` | Container registry URL, for example `https://registry.example.com` |
| `gitlab_version` | `19.5.3-ce.0` | Image tag. Pin it and upgrade on purpose |
| `gitlab_image` | `gitlab/gitlab-ce:{{ gitlab_version }}` | Full image name |
| `gitlab_home` | `/srv/gitlab` | Host directory for config, logs and data |
| `gitlab_http_port` / `gitlab_https_port` | `80` / `443` | Host ports for the web UI |
| `gitlab_ssh_port` | `22` | Host port for Git over SSH. Also written to `gitlab_shell_ssh_port` |
| `gitlab_time_zone` | `UTC` | `gitlab_rails['time_zone']` |
| `gitlab_letsencrypt_contact_email` | `""` | Gets certificate expiry warnings |
| `gitlab_email_from`, `gitlab_email_display_name`, `gitlab_email_reply_to` | `""` | Outgoing email headers |
| `gitlab_extra_config` | `""` | Extra `gitlab.rb` lines, for example SMTP |
| `gitlab_shm_size` | `256m` | Shared memory for the container |
| `gitlab_install_docker` | `true` | Set to `false` if Docker is already installed |
| `gitlab_wait_ready` | `true` | Wait until GitLab answers on `/-/readiness` |

## First sign-in

The username is `root`. The generated password is in the container:

```shell
sudo docker exec gitlab grep 'Password:' /etc/gitlab/initial_root_password
```

The file is deleted on the first container restart after 24 hours. Change the password right after you sign in.

## Upgrading GitLab

Change `gitlab_version` and run the playbook again. Follow GitLab's upgrade path and don't skip required stops: https://docs.gitlab.com/update/upgrade_paths/

## Testing

`tests/run.sh` builds an Ubuntu 24.04 container with systemd and SSH, runs the role against it twice and checks that the second run reports no changes. It needs Docker with about 6 GB of free memory.

## License

MIT
