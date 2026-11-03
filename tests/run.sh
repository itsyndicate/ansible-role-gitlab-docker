#!/usr/bin/env bash
# Runs the role against an Ubuntu 24.04 container twice:
# the first run must succeed, the second must report changed=0.
# Needs Docker, ansible-core 2.18+ and the community.docker collection.
set -euo pipefail
cd "$(dirname "$0")"

NAME=gitlab-role-test
SSH_PORT=${SSH_PORT:-2202}
HTTP_PORT=${HTTP_PORT:-8080}
GIT_SSH_PORT=${GIT_SSH_PORT:-2201}

mkdir -p .work/roles
ln -sfn ../../.. .work/roles/gitlab
[ -f .work/id_test ] || ssh-keygen -t ed25519 -N '' -q -f .work/id_test

docker build -q -t "$NAME" -f Dockerfile.target .
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker volume create "$NAME-docker" >/dev/null
docker volume create "$NAME-containerd" >/dev/null
docker run -d --name "$NAME" --privileged --cgroupns=host \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw -v "$NAME-docker:/var/lib/docker" -v "$NAME-containerd:/var/lib/containerd" \
  --tmpfs /run --tmpfs /run/lock \
  -p "$GIT_SSH_PORT:22" -p "$SSH_PORT:7799" -p "$HTTP_PORT:80" "$NAME" >/dev/null
sleep 5

SSH=(ssh -i .work/id_test -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)

# Move the host's SSH from 22 to 7799 (Ubuntu 24.04, socket activation),
# then log in again on the new port.
"${SSH[@]}" -p "$GIT_SSH_PORT" deploy@127.0.0.1 \
  'sudo ufw allow 7799/tcp && sudo sed -i "s/^#\?Port .*/Port 7799/" /etc/ssh/sshd_config && sudo sshd -t && sudo systemctl daemon-reload && sudo systemctl restart ssh.socket'
"${SSH[@]}" -p "$SSH_PORT" deploy@127.0.0.1 true

cat > .work/hosts <<HOSTS
[gitlab]
gitlab.test ansible_host=127.0.0.1 ansible_port=$SSH_PORT ansible_user=deploy ansible_ssh_private_key_file=.work/id_test ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
HOSTS

ansible-playbook deploy-gitlab.yml
ansible-playbook deploy-gitlab.yml | tee .work/second-run.log
grep -Eq 'changed=0 .*failed=0' .work/second-run.log
curl -fsS -o /dev/null -w 'sign-in page: HTTP %{http_code}\n' -H 'Host: gitlab.test' "http://127.0.0.1:$HTTP_PORT/users/sign_in"
echo "OK. Clean up: docker rm -f $NAME && docker volume rm $NAME-docker $NAME-containerd"
