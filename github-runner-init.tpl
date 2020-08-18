#!/bin/bash
yum update -y
yum install docker -y
yum install git -y
yum install jq -y 
sudo usermod -a -G docker ec2-user
sudo systemctl start docker
sudo systemctl enable docker
export RUNNER_ALLOW_RUNASROOT=true
mkdir actions-runner && cd actions-runner
curl -O -L https://github.com/actions/runner/releases/download/v2.272.0/actions-runner-linux-x64-2.272.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.272.0.tar.gz
sudo chown ec2-user -R /actions-runner
./config.sh --url https://github.com/srijanone/github-chowkidar --token ${ACTION_TOKEN} --labels ec2 --replace --name "my-runner-$(hostname)" --work _work
sudo ./svc.sh install
sudo ./svc.sh start
sudo chown ec2-user -R /actions-runner
