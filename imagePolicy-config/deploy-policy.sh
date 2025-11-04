#!/bin/bash

set -e

echo "Deploying ImagePolicy for demo-imagepolicies namespace..."

# Ensure the namespace exists
if ! oc get namespace demo-imagepolicies &>/dev/null; then
    echo "Creating namespace demo-imagepolicies..."
    oc create namespace demo-imagepolicies
else
    echo "Namespace demo-imagepolicies already exists."
fi

# Apply the ImagePolicy
echo "Applying ImagePolicy..."
oc apply -f imagepolicy.yaml

echo ""
echo "ImagePolicy deployed successfully!"
echo ""
echo "To verify the policy:"
echo "  oc get imagepolicy -n demo-imagepolicies"
echo ""
echo "To view policy details:"
echo "  oc describe imagepolicy signed-image-policy -n demo-imagepolicies"
