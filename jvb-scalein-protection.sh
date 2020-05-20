#!/bin/bash
REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
RUNNING_CONFERENCES=$(curl --silent "http://localhost:8080/colibri/stats"| jq '.conferences - .conference_sizes[0]')
RUNNING_CONFERENCES=${RUNNING_CONFERENCES:=-1}
INSTANCE_ID=$(curl --silent http://169.254.169.254/latest/meta-data/instance-id)
ASG_NAME=$(aws autoscaling describe-auto-scaling-instances --instance-ids $INSTANCE_ID --region $REGION | jq -r '.[] | .[] | .AutoScalingGroupName')

aws cloudwatch put-metric-data --metric-name 'jvb:running_conferences' --namespace Jitsi --value $RUNNING_CONFERENCES --dimensions InstanceId=$INSTANCE_ID --timestamp $(date +%FT%T%:z) --region $REGION

if (( $RUNNING_CONFERENCES > 0 )); then
    logger "$INSTANCE_ID in region $REGION is part of ASG $ASG_NAME and has currently $RUNNING_CONFERENCES conferences running and can be terminated - deactivating protection"
    aws autoscaling set-instance-protection --instance-ids $INSTANCE_ID --auto-scaling-group-name "$ASG_NAME" --protected-from-scale-in --region $REGION
else
    logger "$INSTANCE_ID in region $REGION is part of ASG $ASG_NAME and has currently $RUNNING_CONFERENCES conferences running and can not be terminated - activating protection"
    aws autoscaling set-instance-protection --instance-ids $INSTANCE_ID --auto-scaling-group-name "$ASG_NAME" --no-protected-from-scale-in --region $REGION
fi