#!/bin/bash
echo ECS_CLUSTER=${cluster_name} >> /etc/ecs/ecs.config

curl -o /tmp/agent.rpm \
    https://s3.${region}.amazonaws.com/amazoncloudwatch-agent-${region}/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm

rpm -U /tmp/agent.rpm
rm /tmp/agent.rpm
