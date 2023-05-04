# JupyterLab for Java Base Image

**Test it on** [![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/ebpro/notebook-qs-java-base/develop)

A base image for Jupyter Lab for Java :

* Minimal
  * JDK (Temurin) and Maven 3 from [sdkman](https://sdkman.io/)
  * Jupyter Book
  * PlantUML
  * ZSH
* Default
  * Code Server Web IDE
  * Intellij Idea
  * TexLive full
  * Docker client

## Quickstart

Working directories is `/home/jovyan/work/` (usually monted as a volume).
Notebooks are in `/home/jovyan/work/notebooks`).

### Use Jupyter

```bash
docker run --rm -it \
    --name jupyter-java \
    --volume JUPYTER_WORKDIR:/home/jovyan/work \
    --publish 8888:8888 \
    --env NB_UID=$UID \
    brunoe/jupyter-java:develop $@
```

### Use Intellij Idea

MacOs  

```bash
brew install --cask xquartz
open -a XQuartz
xhost + 127.0.0.1
````

All

```bash
docker run --rm -it \
    --name jupyter-java \
    --volume JUPYTER_WORKDIR:/home/jovyan/work \
    --publish 8888:8888 \
    --env NB_UID=$UID \
    --env DISPLAY=host.docker.internal:0 \
    --volume /tmp/.X11-unix:/tmp/.X11-unix \
    brunoe/jupyter-java:develop idea.sh
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
