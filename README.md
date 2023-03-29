# JupyterLab for Java Base Image

**Test it on** [![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/ebpro/notebook-qs-java-base/develop)

A base image for Jupyter Lab for Java :

* JDK 17 (Temurin) and Maven 3.8 from [sdkman](https://sdkman.io/)
* Code Server Web IDE
* PlantUML
* ZSH
* TexLive
* Jupyter Book
* Docker client

## Quickstart

The notebooks and the working directories are separated in two directories (`/home/jovyan/notebooks/{notebooks,work}`) usually monted as volumes.

```bash
docker run --rm --name jupyter-java-${PWD##*/} \
  --volume data-notebooks-${PWD##*/}:/home/jovyan/notebooks \
  --volume data-work-${PWD##*/}:/home/jovyan/work \
  --publish 8888:8888 \
  --env NB_UID=$UID \
  brunoe/jupyter-java-base:develop start-notebook.sh \
      --notebook-dir=/home/jovyan/notebooks
```

## Host files and UIDs

The image can be launched with two mounted directories :

* one containing some notebooks.
* another one for working files (caches likes maven local files `.m2`).

```bash
docker run --rm --name jupyter-java-${PWD##*/} \
  --user root
  --volume $PWD:/home/jovyan/notebooks \
  --volume $HOME/JUPYTER_WORK:/home/jovyan/work \
  --publish 8888:8888 \
  --env NB_UID=$UID \
  brunoe/jupyter-java-base:develop start-notebook.sh \
      --notebook-dir=/home/jovyan/notebooks
```

## With Docker support

The image includes `docker client, compose and buildx`. 
It supports mount docker socket.

```bash
docker run --rm --name jupyter-java-${PWD##*/} \
  --user root \
  --privileged=true \
  --volume $PWD:/home/jovyan/work/${PWD##*/} \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  --publish 8888:8888 \
  --env NB_UID=$UID \
  brunoe/jupyter-java-base:develop start-notebook.sh \
      --notebook-dir=/home/jovyan/notebooks
```
