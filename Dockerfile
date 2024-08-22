FROM brunoe/jupyter-base:develop

LABEL org.opencontainers.image.authors="Emmanuel BRUNO <emmanuel.bruno@univ-tln.fr>" \
      org.opencontainers.image.description="A jupyterlab image for Java development" \
      org.opencontainers.image.documentation="https://github.com/ebpro/jupyter-java/" \
      org.opencontainers.image.license="MIT" \
      org.opencontainers.image.support="https://github.com/ebpro/jupyter-java/issues" \
      org.opencontainers.image.title="Jupyter Java" \
      org.opencontainers.image.vendor="UTLN"

USER root

# Install minimal dependencies 
COPY Artefacts/apt_packages* /tmp/
# RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
RUN --mount=type=bind,source=/opt/cache/apt,target=/var/cache/apt \
 	apt-get update && \
	apt-get install -qq --yes --no-install-recommends \
		$(cat /tmp/apt_packages) && \
	rm -rf /var/lib/apt/lists/*	

# Install a Java Kernel for Jupyter
# RUN --mount=type=cache,target=/var/cache/buildkit/pip,sharing=locked \
RUN --mount=type=bind,source=/opt/cache/buildkit/pip,target=/var/cache/buildkit/pip \
	echo -e "\e[93m**** Install Java Kernel for Jupyter ****\e[38;5;241m" && \
        #curl -sL https://github.com/SpencerPark/IJava/releases/download/v1.3.0/ijava-1.3.0.zip -o /tmp/ijava-kernel.zip && \
        curl -sL https://bruno.univ-tln.fr/ijava-latest.zip -o /tmp/ijava-kernel.zip && \
        unzip /tmp/ijava-kernel.zip -d /tmp/ijava-kernel && \
        cd /tmp/ijava-kernel && \
        python3 install.py --sys-prefix && \
        cd && rm -rf /tmp/ijava-kernel /tmp/ijava-kernel.zip && \
    fix-permissions ${CONDA_DIR} && \
    fix-permissions /home/${NB_USER}

# Adds IJava Jupyter Kernel Personnal Magics
ADD magics  /magics

ARG VERSION

# Install java dev tools with sdkman  
#     latest java jdk LTS (ENV=stable) or the latest jdk (ENV="")
#     stable mvn 3
# RUN --mount=type=cache,target=/opt/sdkmanArchives/,sharing=locked \
RUN --mount=type=bind,source=/opt/cache/sdkmanarchives,target=/opt/sdkmanarchives/ \
    echo -e "\e[93m**** Installs SDKMan, JDK and Maven ****\e[38;5;241m" && \
    curl -s "https://get.sdkman.io" | bash && \
    mkdir -p /home/jovyan/.sdkman/archives/ && \
    ln -s /opt/sdkmanArchives/ /home/jovyan/.sdkman/archives/ && \
    echo "sdkman_auto_answer=true" > ${HOME}/.sdkman/etc/config && \
	source "$HOME/.sdkman/bin/sdkman-init.sh" && \
	if [[ "$ENV" = "stable" ]] ; then \
		sdk install java ;\
	else \
	 	sdk install java $(sdk list java|grep tem|head -n 1|cut -d '|' -f 6) ;\
	fi && \
	sdk install maven && \
	# Set maven repository to persistent user space
	echo \
    "<settings xmlns='http://maven.apache.org/SETTINGS/1.2.0' \
      		   xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' \
    		   xsi:schemaLocation='http://maven.apache.org/SETTINGS/1.2.0 https://maven.apache.org/xsd/settings-1.2.0.xsd'> \
        <localRepository>\${user.home}/work/.m2/repository</localRepository> \
    </settings>" \
    	> ${HOME}/.sdkman/candidates/maven/current/conf/settings.xml && \
	# add sdkman config to .zshrc
 	echo '#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!' >> $HOME/.zshenv && \
    echo 'export SDKMAN_DIR="$HOME/.sdkman"' >> $HOME/.zshenv && \
    echo '[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"' >> $HOME/.zshenv && \
	# sdk flush && \
	groupadd sdk && \
	chgrp -R sdk ${SDKMAN_DIR} &&\
	chmod 770 -R ${SDKMAN_DIR} && \	
	adduser ${NB_USER} sdk && \
	# sdk flush && \
	# sdk flush broadcast && \
	fix-permissions /home/${NB_USER}/.sdkman

# Adds Java, Maven and intellij Idea to the user path
ENV PATH=/home/jovyan/.sdkman/candidates/maven/current/bin:/home/jovyan/.sdkman/candidates/java/current/bin:/opt/idea/bin/:$PATH

# link ~/.m2 to ~/work/.m2
ENV NEEDED_WORK_DIRS="$NEEDED_WORK_DIRS .m2"

# Default to ZSH shell
SHELL ["/bin/zsh","-l","-c"]

# Adds usefull java librairies to classpath
RUN echo -e "\e[93m**** Install lombok and java dependencies ***\e[38;5;241m" && \
        mkdir -p "${HOME}/lib/" && \
        curl -sL https://projectlombok.org/downloads/lombok.jar -o "${HOME}/lib/lombok.jar"
COPY dependencies/* "$HOME/lib/"

ARG ENV

# If not minimal install Intellij Idea
#RUN if [[ "$ENV" != "minimal" ]] ; then \
#	 # Installs the latest intellij idea ultimate
#	 if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
#		target=linux; \
#  	 elif [ "$TARGETPLATFORM" = "linux/arm64/v8" ] || [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
#		target=linuxARM64; \
#	 else \
#		target=linux; \
#	 fi && \
#	# By default install ultimate version
#	 if [[ "$LICENCE" = "community" ]] ; then \
#	 	product=IC; \
#	 else \
#	 	product=IU; \
#	 fi && \
#	 idea_releases_url="https://data.services.jetbrains.com/products/releases?code=${product}&latest=true&type=release" && \
#        download_url=$(curl --silent $idea_releases_url | jq --raw-output ".I${product}[0].downloads.${target}.link") && \    
#	 	echo "Idea URL: $download_url" && \
#		filename=${download_url##*/} && \
#        echo -e "\e[93m**** Download and install jetbrains ${filename%.tar.gz} ***\e[38;5;241m" && \
#		mkdir /opt/idea/ && \
#		curl --silent -L "${download_url}" | \
#			tar xz -C /opt/idea --strip 1; \
#	fi
# ENV PATH=:${PATH}

# Codeserver extensions to install
COPY Artefacts/codeserver_extensions /tmp/

RUN cd $(dirname $(readlink $(type code-server))) && \
	rm -rf node_modules/argon2 \
	&& npm install -g node-gyp \
	&& npm install argon2 argon2-cli \
	&& npx argon2-cli -d -e

RUN if [[ "$ENV" != "minimal" ]] ; then \
		echo -e "\e[93m**** Installs Code Server Extensions ****\e[38;5;241m" && \
				CODESERVERDATA_DIR=/tmp/codeserver && \
				mkdir -p "$CODESERVERDATA_DIR" && \
                PATH=/opt/bin:${PATH} code-server \
                	--user-data-dir "$CODESERVERDATA_DIR"\
                	--extensions-dir "$CODESERVEREXT_DIR" \
                    $(cat /tmp/codeserver_extensions|sed 's/./--install-extension &/') && \
				rm -rf "$CODESERVERDATA_DIR" ; \
	fi

# Enable Java Annotations and Preview and personnal magics. Sets classpath.
COPY kernel.json /opt/conda/share/jupyter/kernels/java/kernel.json
ENV IJAVA_CLASSPATH="${HOME}/lib/*.jar:/usr/local/bin/*.jar"
ENV IJAVA_STARTUP_SCRIPTS_PATH="/magics/*"
RUN JAVA_MAJOR_VERSION=$(java --version|head -n 1|cut -d ' ' -f 2|cut -d '.' -f 1) && \
	DYNENV="\"env\": {\"JAVA_OPTS\":\"--enable-preview\",\"IJAVA_COMPILER_OPTS\":\"-deprecation -Xlint:preview -XprintProcessorInfo -XprintRounds --enable-preview --release ${JAVA_MAJOR_VERSION} --add-exports=jdk.compiler\/com.sun.tools.javac.processing=ALL-UNNAMED\"}" && \
	IKERNEL_JAR=$(ls /opt/conda/share/jupyter/kernels/java/IJava*.jar| sed 's/\//\\\//g') && \
	sed -i s/ENV/"$DYNENV"/ /opt/conda/share/jupyter/kernels/java/kernel.json && \
	sed -i s/IKERNEL_JAR/"$IKERNEL_JAR"/ /opt/conda/share/jupyter/kernels/java/kernel.json

# Update installed software versions. 
COPY versions/ /versions/
COPY --chown=$NB_UID:$NB_GID README.md ${HOME}/
RUN touch ${HOME}/README.md && \
    echo "# jupyter-java softwares" > ${HOME}/README.md && \
    for versionscript in $(ls -d /versions/*) ; do \
      eval "$versionscript" 2>/dev/null >> ${HOME}/README.md ; \
    done

COPY kernel.json /opt/conda/share/jupyter/kernels/java/kernel.json
RUN JAVA_MAJOR_VERSION=$(java --version|head -n 1|cut -d ' ' -f 2|cut -d '.' -f 1) && \
	DYNENV="\"env\": {\"JAVA_OPTS\":\"--enable-preview\",\"IJAVA_COMPILER_OPTS\":\"-deprecation -Xlint:preview -XprintProcessorInfo -XprintRounds --add-exports=jdk.compiler\/com.sun.tools.javac.processing=ALL-UNNAMED\"}" && \
	IKERNEL_JAR=$(ls /opt/conda/share/jupyter/kernels/java/IJava*.jar| sed 's/\//\\\//g') && \
	sed -i "s/ENV/$DYNENV/" /opt/conda/share/jupyter/kernels/java/kernel.json && \
	sed -i "s/IKERNEL_JAR/$IKERNEL_JAR/" /opt/conda/share/jupyter/kernels/java/kernel.json

RUN quarto add martinomagnifico/quarto-verticator --no-prompt && \
	quarto add quarto-ext/include-code-files --no-prompt && \
	quarto install extension schochastics/academicons --no-prompt && \
	quarto add mcanouil/quarto-iconify --no-prompt && \
	quarto install extension schochastics/quarto-nutshell --no-prompt && \
	quarto install extension jjallaire/code-visibility --no-prompt && \
	quarto add shafayetShafee/line-highlight --no-prompt && \
	quarto add mcanouil/quarto-lua-env --no-prompt && \
	quarto add shafayetShafee/hide-comment --no-prompt && \
	quarto install extension EmilHvitfeldt/quarto-roughnotation --no-prompt && \
	quarto add shafayetShafee/code-fullscreen --no-prompt 

RUN conda install --yes -c jetbrains kotlin-jupyter-kernel

USER $NB_UID
