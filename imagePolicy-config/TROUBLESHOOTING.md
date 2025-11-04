# Troubleshooting ImagePolicy Signature Verification

## Error: "A signature was required, but no signature exists"

If you see this error even though your image is signed and can be verified with `cosign verify`, follow these debugging steps.

### Understanding the Error

```
Error: checking signature of "registry/org/image:tag": verifying signatures:
SignatureValidationFailed: A signature was required, but no signature exists
```

This error means CRI-O (the container runtime) cannot find or access the signature, even though it exists in the registry.

## Common Causes

1. **Registry configuration not propagated to nodes**
2. **Missing `use-sigstore-attachments` configuration**
3. **ImagePolicy not properly applied**
4. **Registry mirror misconfiguration**

## Debugging Steps

### 1. Verify Your Image is Actually Signed

Test locally with cosign:

```bash
cosign verify --key /path/to/public-key.pem registry.com/org/image:tag
```

If this works, the signature exists and the issue is with OpenShift's configuration.

### 2. Check ImagePolicy Status

Verify the ImagePolicy was created and is active:

```bash
# For namespace-scoped ImagePolicy
oc get imagepolicy -n demo-imagepolicies
oc describe imagepolicy signed-image-policy -n demo-imagepolicies

# For cluster-scoped
oc get clusterimagepolicy
oc describe clusterimagepolicy <name>
```

### 3. Check Node Configuration Files

The Machine Config Operator (MCO) should have created configuration files on the nodes. Check them:

**Check the namespace-specific policy file:**
```bash
# Pick a node where the pod is scheduled
NODE_NAME=$(oc get nodes -o jsonpath='{.items[0].metadata.name}')

# Check the namespace policy (for ImagePolicy)
oc debug node/$NODE_NAME -- chroot /host cat /etc/crio/policies/demo-imagepolicies.json
```

**Check the sigstore registries configuration:**
```bash
oc debug node/$NODE_NAME -- chroot /host cat /etc/containers/registries.d/sigstore-registries.yaml
```

You should see entries for your registry with `use-sigstore-attachments: true`:

```yaml
docker:
  quay-d68nk.apps.cluster-d68nk.dynamic.redhatworkshops.io/demo-imagepolicies:
    use-sigstore-attachments: true
```

**If this entry is missing or incorrect, the MCO hasn't properly configured the nodes.**

### 4. Check CRI-O Logs

View CRI-O logs on the node where the pod failed:

```bash
# Get the node where the pod is scheduled
oc get pod <pod-name> -n demo-imagepolicies -o jsonpath='{.spec.nodeName}'

# View CRI-O logs
oc debug node/$NODE_NAME -- chroot /host journalctl -u crio -f
```

Look for messages like:
- "Using registries.d directory /etc/containers/registries.d for sigstore configuration"
- "Not looking for sigstore attachments"
- Signature verification errors

### 5. Test with Podman Debug Mode

SSH to a node or use `oc debug node` and try pulling with podman in debug mode:

```bash
oc debug node/$NODE_NAME

# Inside the debug pod
chroot /host

# Try pulling with debug logs
podman --log-level debug pull <your-image>
```

This will show detailed information about where podman is looking for signatures.

### 6. Verify MCO has Processed the ImagePolicy

Check if the Machine Config Operator has picked up the ImagePolicy:

```bash
# Check MCO logs
oc logs -n openshift-machine-config-operator deployment/machine-config-operator | grep -i imagepolicy

# Check if a machine config was created/updated
oc get machineconfig | grep rendered
```

### 7. Force MCO to Re-sync (if needed)

If the configuration files on nodes are missing, you may need to trigger an MCO update:

```bash
# Delete and recreate the ImagePolicy
oc delete imagepolicy signed-image-policy -n demo-imagepolicies
oc apply -f imagepolicy.yaml

# Wait for nodes to update (check MachineConfigPool)
oc get mcp
```

## Known Issues

### Missing use-sigstore-attachments Configuration

**Issue:** The Container Runtime Config controller might not properly detect mirror configurations before adding the ClusterImagePolicy scope to the sigstore configuration.

**Symptom:** Logs show "Not looking for sigstore attachments"

**Solution:** Ensure your ImagePolicy scope exactly matches the registry path where signatures are stored.

### Registry Mirrors

**Issue:** If you use registry mirrors (ICSP/IDMS), the `use-sigstore-attachments` option needs to be configured on **every mirror** of the scope.

**Solution:** Check your ImageContentSourcePolicy or ImageDigestMirrorSet configuration.

## Verification Commands

### Check if Signatures are Accessible from the Cluster

From a debug pod on a node:

```bash
oc debug node/$NODE_NAME

chroot /host

# Try to access the signature using skopeo
skopeo inspect --raw docker://registry.com/org/image:tag

# Check for cosign signature layers
skopeo inspect docker://registry.com/org/image:sha256-<digest>.sig
```

### Verify Policy Configuration

```bash
# Check the policy JSON on a node
oc debug node/$NODE_NAME -- chroot /host cat /etc/crio/policies/demo-imagepolicies.json | jq .
```

Expected structure:
```json
{
  "default": [{"type": "insecureAcceptAnything"}],
  "transports": {
    "docker": {
      "quay-d68nk.apps.cluster-d68nk.dynamic.redhatworkshops.io/demo-imagepolicies": [
        {
          "type": "sigstoreSigned",
          "keyData": "base64-encoded-key...",
          "signedIdentity": {
            "type": "matchRepository"
          }
        }
      ]
    }
  }
}
```

## Quick Checklist

- [ ] Image is signed (verified with `cosign verify` locally)
- [ ] ImagePolicy exists (`oc get imagepolicy`)
- [ ] ImagePolicy scope matches your image repository exactly
- [ ] Node policy file exists (`/etc/crio/policies/<namespace>.json`)
- [ ] Sigstore config exists in `/etc/containers/registries.d/sigstore-registries.yaml`
- [ ] `use-sigstore-attachments: true` is set for your registry
- [ ] CRI-O logs don't show "Not looking for sigstore attachments"
- [ ] MCO has processed the ImagePolicy (no errors in MCO logs)

## Additional Resources

- OpenShift documentation: Managing secure signatures with sigstore
- CRI-O signature verification documentation
- Cosign documentation for signature format

## Still Having Issues?

If you've verified all the above and still have issues:

1. Check if your OpenShift version supports ImagePolicy (4.16+ tech preview)
2. Verify the SigstoreImageVerification feature gate is enabled
3. Check if there are any network policies blocking access to the registry
4. Ensure the registry supports cosign signatures (Quay, Docker Hub, etc.)
