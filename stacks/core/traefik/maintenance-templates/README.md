# Maintenance router templates

Workflow:

1) Copy the template into the Traefik dynamic directory.
2) Replace `REPLACE_SERVER` and `REPLACE_HOST`.
3) When the service is back, remove the maintenance file.

Example:

```
cp maintenance-template.yml /mnt/user/appdata/traefik/dynamic/maintenance-nextcloud.yml
sed -i \
  -e 's/REPLACE_SERVER/nextcloud/' \
  -e 's/REPLACE_HOST/cloud.dege.app/' \
  /mnt/user/appdata/traefik/dynamic/maintenance-nextcloud.yml
```
