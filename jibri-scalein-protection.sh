#!/bin/bash
REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
INSTANCE_ID=$(curl --silent http://169.254.169.254/latest/meta-data/instance-id)
ASG_NAME=$(aws autoscaling describe-auto-scaling-instances --instance-ids $INSTANCE_ID --region $REGION | jq -r '.[] | .[] | .AutoScalingGroupName')

HEALTH_DATA=$(curl --silent "http://localhost:2222/jibri/api/v1.0/health")
BUSY_STATUS=$(echo $HEALTH_DATA | jq '.status.busyStatus')
BUSY_STATUS=${BUSY_STATUS:="NULL"}
HEALTH_STATUS=$(echo $HEALTH_DATA | jq '.status.health.healthStatus')
HEALTH_STATUS=${HEALTH_STATUS:="NULL"}

if [ $BUSY_STATUS == '"IDLE"' ]; then
    aws cloudwatch put-metric-data --metric-name 'jibri:available' --namespace Jitsi --value 1 --timestamp $(date +%FT%T%:z) --region $REGION
else
    aws cloudwatch put-metric-data --metric-name 'jibri:available' --namespace Jitsi --value 0 --timestamp $(date +%FT%T%:z) --region $REGION
fi

if [ $BUSY_STATUS == '"BUSY"' ]; then
    aws autoscaling set-instance-protection --instance-ids $INSTANCE_ID --auto-scaling-group-name "$ASG_NAME" --protected-from-scale-in --region $REGION
else
    aws autoscaling set-instance-protection --instance-ids $INSTANCE_ID --auto-scaling-group-name "$ASG_NAME" --no-protected-from-scale-in --region $REGION
fi


if [ $HEALTH_STATUS == '"UNHEALTHY"' ]; then
    aws autoscaling set-instance-health --instance-id $INSTANCE_ID --health-status Unhealthy --should-respect-grace-period --region $REGION
fi