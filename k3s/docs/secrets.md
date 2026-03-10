# SOPS + age Secrets

## Key handling

- Generate the age keypair on the control machine:

```bash
age-keygen -o age.key
age-keygen -y age.key
```

- Store the private key offline (password manager + offline backup).
- The public key goes into `k3s/cluster/.sops.yaml`.

## Flux decryption

- Flux expects a secret named `sops-age` in `flux-system`.
- It must contain `age.agekey`.

```bash
kubectl -n flux-system create secret generic sops-age \
  --from-file=age.agekey=age.key
```

## Encrypt/decrypt workflow

```bash
# Encrypt
sops --encrypt --in-place k3s/cluster/secrets/<name>.sops.yaml

# Decrypt (view only)
sops --decrypt k3s/cluster/secrets/<name>.sops.yaml
```

Note: `k3s/cluster/secrets/example-secret.sops.yaml` is a placeholder. Re-encrypt it after you set your age public key.

## Rotation

1. Generate a new age keypair.
2. Add the new public key to `k3s/cluster/.sops.yaml` (keep old key during transition).
3. Re-encrypt secrets with the new key.
4. Update the `sops-age` secret in `flux-system`.
5. Remove the old key from `.sops.yaml` once all secrets are re-encrypted.
