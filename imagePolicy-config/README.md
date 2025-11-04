# ImagePolicy Configuration for Signed Images

This directory contains the configuration for verifying signed container images in the `demo-imagepolicies` namespace using Cosign public key verification with Rekor transparency log.

## Files

- **`imagepolicy.yaml`**: The ImagePolicy custom resource that enforces signature verification
- **`signer-public-key.pem`**: The public key used to verify image signatures
- **`rekor-public-key.pem`**: The Rekor transparency log public key
- **`encode-keys.sh`**: Helper script to base64 encode the public keys
- **`deploy-policy.sh`**: Script to deploy the ImagePolicy to the cluster

## Overview

The ImagePolicy is configured to:

1. Apply to the `demo-imagepolicies` namespace
2. Verify **ALL images** from the repository namespace: `quay-d68nk.apps.cluster-d68nk.dynamic.redhatworkshops.io/demo-imagepolicies`
3. Use Cosign public key verification
4. Verify signatures against the Rekor transparency log at `https://rekor.sigstore.dev`
5. Use `MatchRepository` policy to ensure the signature matches the repository

This means any pod deployed in the `demo-imagepolicies` namespace that pulls images from this registry organization **must have valid signatures** or it will be rejected.

## Prerequisites

- OpenShift Container Platform 4.16+ (ImagePolicy is a Tech Preview feature)
- Cluster admin access or appropriate permissions
- The `demo-imagepolicies` namespace (will be created if it doesn't exist)

## Deployment

To deploy the ImagePolicy:

```bash
./deploy-policy.sh
```

Or manually:

```bash
# Create namespace if needed
oc create namespace demo-imagepolicies

# Apply the ImagePolicy
oc apply -f imagepolicy.yaml
```

## Verification

Check if the ImagePolicy is deployed:

```bash
oc get imagepolicy -n demo-imagepolicies
```

View policy details:

```bash
oc describe imagepolicy signed-image-policy -n demo-imagepolicies
```

## How It Works

When a pod is deployed in the `demo-imagepolicies` namespace that references an image from the configured scope:

1. OpenShift will check if the image has a valid Cosign signature
2. The signature will be verified using the provided public key
3. The signature will be verified against the Rekor transparency log certificate
4. Only images with valid signatures will be allowed to run

Images that do not have valid signatures or fail verification will be rejected.

## Public Keys

The public keys are embedded in the ImagePolicy as base64-encoded strings:

- **Signer Public Key**: Used to verify the image signature created with Cosign
- **Rekor Public Key**: Used to verify entries in the Rekor transparency log

### Important Note: Secrets Not Supported

**The ImagePolicy API does not support referencing Kubernetes secrets for public keys.** The keys must be provided inline as base64-encoded data in the `keyData` field.

This limitation exists because the Machine Config Operator (MCO) reads the ImagePolicy and writes the configuration directly to `/etc/containers/policy.json` on all cluster nodes, requiring the key data to be available in the resource definition.

**Security Note:** Public keys are meant to be public (not sensitive like private keys), so embedding them directly in the ImagePolicy is acceptable from a security perspective. Access to ImagePolicy resources can be controlled via RBAC.

If you need to re-encode the keys (e.g., if they change), run:

```bash
./encode-keys.sh
```

Then update the `keyData` fields in `imagepolicy.yaml` with the new base64-encoded values.

## Testing

To test the policy:

1. **Deploy a signed image** (should succeed):
   ```bash
   oc apply -f ../signed-with-key-image/deploy.yaml
   ```

2. **Deploy an unsigned image** (should fail):
   ```bash
   oc apply -f ../unsigned-image/deploy.yaml
   ```

## Troubleshooting

If pods fail to start with signature verification errors, see **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** for detailed debugging steps.

### Quick Checks

1. Check the ImagePolicy status:
   ```bash
   oc get imagepolicy signed-image-policy -n demo-imagepolicies -o yaml
   ```

2. Check pod events:
   ```bash
   oc describe pod <pod-name> -n demo-imagepolicies
   ```

3. Verify the image was signed correctly:
   ```bash
   cosign verify --key signer-public-key.pem <image-url>
   ```

4. Check node configuration (see TROUBLESHOOTING.md for details):
   ```bash
   oc debug node/<node-name> -- chroot /host cat /etc/containers/registries.d/sigstore-registries.yaml
   ```

### Common Error: "A signature was required, but no signature exists"

If you can verify the signature with `cosign` locally but OpenShift rejects it, this usually means:
- The MCO hasn't properly configured the nodes yet
- The `use-sigstore-attachments` setting is missing from the registry configuration

See **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** for complete debugging steps.

## Notes

- The ImagePolicy feature is in Tech Preview in OpenShift 4.16+
- The policy only applies to images within the specified scopes
- Images from other repositories or registries are not affected by this policy
- The Rekor URL points to the public Sigstore Rekor instance
