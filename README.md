# JupyterLab Base Image

**Test it on** [![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/ebpro/notebook-qs-base/develop)

A base image for the Jupyter Lab ased on jupyter/minimal-notebook :
  
* ZSH
* TexLive
* Code Server Web IDE
* Jupyter Book

## Quickstart

```bash
docker run --rm --name jupyter-base-${PWD##*/} \
  --volume data-${PWD##*/}:/home/jovyan/work/${PWD##*/} \
  --publish 8888:8888 \
  --env NB_UID=$UID \
  brunoe/jupyter-base:develop start-notebook.sh --notebook-dir=work/${PWD##*/}
```

## Host files and UIDs

```bash
docker run --rm --name jupyter-base-${PWD##*/} \
  --user root
  --volume $PWD:/home/jovyan/work/${PWD##*/} \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  --publish 8888:8888 \
  --env NB_UID=$UID \
  brunoe/jupyter-base:develop start-notebook.sh --notebook-dir=work/${PWD##*/}
```

## With Docker support

```bash
docker run --rm --name jupyter-base-${PWD##*/} \
  --user root \
  --privileged=true \
  --volume $PWD:/home/jovyan/work/${PWD##*/} \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  --publish 8888:8888 \
  --env NB_UID=$UID \
  brunoe/jupyter-base:develop start-notebook.sh --notebook-dir=work/${PWD##*/}
```