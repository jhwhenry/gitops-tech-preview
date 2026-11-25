# Mirror olm-utils-premium-v4 image

**Note:** The latest olm-utils-v4 image should be mirrored to the private image registory.

## 1. Set environment variables
```
# ------------------------------------------------------------------------------
# IBM Entitled Key for IBM Software Hub Premium features 
# ------------------------------------------------------------------------------

export IBM_ENTITLEMENT_KEY=<enter your IBM entitlement API key>

# ------------------------------------------------------------------------------
# Private container registry
# ------------------------------------------------------------------------------
# Set the following variables if you mirror images to a private container registry.

export PRIVATE_REGISTRY_LOCATION=<enter the location of your private container registry>
export PRIVATE_REGISTRY_PUSH_USER=<enter the username of a user that can push to the registry>
export PRIVATE_REGISTRY_PUSH_PASSWORD=<enter the password of the user that can push to the registry>
export PRIVATE_REGISTRY_PULL_USER=<enter the username of a user that can pull from the registry>
export PRIVATE_REGISTRY_PULL_PASSWORD=<enter the password of the user that can pull from the registry>

# ------------------------------------------------------------------------------
# Components
# ------------------------------------------------------------------------------
export VERSION=5.4.0

```

## 2. Mirror olm-utils-premium-v4 image using podman
**Note:** Podman is used as an example for mirroring the olm-utils-premium-v4 image. Alternative tools, such as Docker or Skopeo, may also be used where appropriate.

```
podman login cp.icr.io -u cp -p $IBM_ENTITLEMENT_KEY

#Pull the latest olm-utils-premium-v4 image for the 5.4.0 version
podman pull cp.icr.io/cp/cpd/olm-utils-premium-v4:${VERSION} --tls-verify=false

podman login ${PRIVATE_REGISTRY_LOCATION} -u ${PRIVATE_REGISTRY_PUSH_USER} -p ${PRIVATE_REGISTRY_PUSH_PASSWORD}

podman tag cp.icr.io/cp/cpd/olm-utils-premium-v4:${VERSION} ${PRIVATE_REGISTRY_LOCATION}/cp/cpd/olm-utils-premium-v4:${VERSION}

podman push ${PRIVATE_REGISTRY_LOCATION}/cp/cpd/olm-utils-premium-v4:${VERSION} --remove-signatures

```

## 3. Validate and confirm successful image mirroring
Ensure the `the olm-utils-premium-v4` can be pulled successfully from your private image registry.
```
podman pull ${PRIVATE_REGISTRY_LOCATION}/cp/cpd/olm-utils-premium-v4:${VERSION} --tls-verify=false
```

Get the image digest and creation date of `the olm-utils-premium-v4` in your private image registry.
```
podman inspect ${PRIVATE_REGISTRY_LOCATION}/cp/cpd/olm-utils-premium-v4:${VERSION} --format $'Digest: {{.Digest}}\nCreated: {{.Created}}'
```

Get the image digest and creation date of `the olm-utils-premium-v4` in IBM Entitlement registry.
```
podman inspect cp.icr.io/cp/cpd/olm-utils-premium-v4:${VERSION} --format $'Digest: {{.Digest}}\nCreated: {{.Created}}'
```

Compare the results and ensure they are consistent.

The `olm-utils-premium-v4` image digest is required during Argo CD deployment and will be referenced by the deployment configuration.