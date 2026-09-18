# Coder template

This directory contains a Docker-based [Coder](https://coder.com/) workspace
template for developing `kostabber.koplugin`.

## Deploy the template

From a machine with access to the Coder deployment and Docker daemon:

```sh
coder templates create kostabber --directory .coder
```

Create a workspace from the template:

```sh
coder create kostabber-dev --template kostabber
coder ssh kostabber-dev
```

The startup script clones the repository into `/home/coder/kostabber.koplugin`.
The image can be overridden when creating or updating the template:

```sh
coder templates push kostabber --directory .coder --variable docker_image=ubuntu:22.04
```
