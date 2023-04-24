FROM brunoe/jupyter-base:develop

LABEL maintainer="Emmanuel Bruno <emmanuel.bruno@univ-tln.fr>"

USER root


# Install minimal dependencies 

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
 	apt-get update && \
	apt-get install -qq --yes --no-install-recommends \
		$(cat /tmp/apt_packages) && \
	rm -rf /var/lib/apt/lists/*	

RUN --mount=type=cache,target=/var/cache/buildkit/pip,sharing=locked \
	echo -e "\e[93m**** Install Java Kernel for Jupyter ****\e[38;5;241m" && \
        curl -sL https://github.com/SpencerPark/IJava/releases/download/v1.3.0/ijava-1.3.0.zip -o /tmp/ijava-kernel.zip && \
        unzip /tmp/ijava-kernel.zip -d /tmp/ijava-kernel && \
        cd /tmp/ijava-kernel && \
        python3 install.py --sys-prefix && \
	# jupyter kernelspec install --user java/ && \
        cd && rm -rf /tmp/ijava-kernel /tmp/ijava-kernel.zip && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

## Enable Java Early Access
COPY kernel.json /opt/conda/share/jupyter/kernels/java/kernel.json
# Adds IJava Jupyter Kernel Personnal Magics
ADD magics  /magics

# ENV IJAVA_COMPILER_OPTS="-deprecation -Xlint -XprintProcessorInfo -XprintRounds --enable-preview --release 17"
ENV IJAVA_CLASSPATH="${HOME}/lib/*.jar:/usr/local/bin/*.jar"
ENV IJAVA_STARTUP_SCRIPTS_PATH="/magics/*"

# Tool to easily install java dev tools with sdkman  
# Install latest java jdk LTS
# Install the latest mvn 3
RUN --mount=type=cache,target=/opt/sdkmanArchives/,sharing=locked \
    echo -e "\e[93m**** Installs SDKMan, Java JDKs and Maven3 ****\e[38;5;241m" && \
    curl -s "https://get.sdkman.io" | bash && \
    mkdir -p /home/jovyan/.sdkman/archives/ && \
    ln -s /opt/sdkmanArchives/ /home/jovyan/.sdkman/archives/ && \
    echo "sdkman_auto_answer=true" > $HOME/.sdkman/etc/config && \
	source "$HOME/.sdkman/bin/sdkman-init.sh" && \
	sdk install java && \
	sdk install maven && \
	# sdk flush && \
	groupadd sdk && \
	chgrp -R sdk $SDKMAN_DIR &&\
	chmod 770 -R $SDKMAN_DIR && \	
	adduser $NB_USER sdk && \
	# sdk flush && \
	# sdk flush broadcast && \
	fix-permissions /home/$NB_USER/.sdkman

RUN echo \
    "<settings xmlns='http://maven.apache.org/SETTINGS/1.2.0' \
    xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' \
    xsi:schemaLocation='http://maven.apache.org/SETTINGS/1.2.0 https://maven.apache.org/xsd/settings-1.2.0.xsd'> \
        <localRepository>\${user.home}/work/.m2/repository</localRepository> \
    </settings>" \
    > $HOME/.sdkman/candidates/maven/current/conf/settings.xml

ENV NEEDED_WORK_DIRS "$NEEDED_WORK_DIRS .m2"

RUN echo '#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!' >> $HOME/.zshenv && \
    echo 'export SDKMAN_DIR="$HOME/.sdkman"' >> $HOME/.zshenv && \
    echo '[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"' >> $HOME/.zshenv

SHELL ["/bin/zsh","-l","-c"]

RUN echo -e "\e[93m**** Install lombok and java dependencies ***\e[38;5;241m" && \
        mkdir -p "${HOME}/lib/" && \
        curl -sL https://projectlombok.org/downloads/lombok.jar -o "${HOME}/lib/lombok.jar"

COPY dependencies/* "$HOME/lib/"

# Adds Java and Maven to the user path and intellij idea
ENV PATH=/home/jovyan/.sdkman/candidates/maven/current/bin:/home/jovyan/.sdkman/candidates/java/current/bin:/opt/idea/bin/:$PATH

ARG ENV

RUN if [[ "$ENV" = "ultimate" || "$ENV" = "community" ]] ; then \
	 # Installs the latest intellij idea ultimate
	 if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
		target=linux; \
  	 elif [ "$TARGETPLATFORM" = "linux/arm64/v8" ] || [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
		target=linuxARM64; \
	 else \
		target=linux; \
	 fi && \
	# Ultimate Installs the latest jdk and intellij ultimate
	 if [[ "$ENV" = "ultimate" ]] ; then \
	 	sdk install java $(sdk list java|grep tem|head -n 1|cut -d '|' -f 6) && \
	 	product=IU; \
	 else \
	 	product=IC; \
	 fi && \
	 idea_releases_url="https://data.services.jetbrains.com/products/releases?code=${product}&latest=true&type=release" && \
        download_url=$(curl --silent $idea_releases_url | jq --raw-output ".I${product}[0].downloads.${target}.link") && \    
		filename=${download_url##*/} && \
        echo -e "\e[93m**** Download and install jetbrains ${filename%.tar.gz} ***\e[38;5;241m" && \
		mkdir /opt/idea/ && \
#		curl --silent -L "https://download.jetbrains.com/product?code=IU&latest&distribution=linux" | \
		curl --silent -L "${download_url}" | \
			tar xz -C /opt/idea --strip 1; \
	fi
ENV PATH=:$PATH

USER $NB_UID
