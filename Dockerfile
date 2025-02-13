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
RUN --mount=type=bind,source=Artefacts/,target=/tmp/Artefacts/ \ 
	--mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
	apt-get install -qq --yes --no-install-recommends \
		$(cat /tmp/apt_packages) && \
	rm -rf /var/lib/apt/lists/*

# Adds IJava Jupyter Kernel Personnal Magics
COPY magics  /magics

ARG VERSION

ENV JAVA_LTS="^17\|^21\|^25"

# Install java dev tools with sdkman  
#     latest java jdk LTS, the latest jdk, and early access
#     stable mvn 3
RUN --mount=type=cache,target=/opt/sdkmanArchives/,sharing=locked \
    echo -e "\e[93m**** Installs SDKMan, JDK and Maven ****\e[38;5;241m" && \
    curl -s "https://get.sdkman.io" | bash && \
    echo "sdkman_auto_answer=true" > ${HOME}/.sdkman/etc/config && \
	source "$HOME/.sdkman/bin/sdkman-init.sh" && \
    if [[ -z "CI" ]] ; then echo "USING SDKMAN CACHE";else echo "NOT USING SDKMAN CACHE" ; \
            find /opt/sdkmanArchives -name \*.h -exec cp {} ${SDKMAN_DIR}/tmp/ \; ; fi && \
	JAVA_LTS=$(sdk list java|grep default| grep -o "[^ ]*$"|tr -d ':') && \
	# Installs all LTSs, early access JDK and latest maven
	if [[ "$ENV" = "stable" ]] ; then \
		sdk install java ;\
	else \
		# Install latest java
		JAVA_LATEST=$(sdk list java|grep -- "-tem"|cut -d '|' -f 6|head -n 1|tr -d ' ') && \
		sdk install java "$JAVA_LATEST" && \
		# Install Java 8
	    sdk install java $(sdk list java|grep "8\..*fx-zulu"|head -n 1|cut -d '|' -f 6)  && \ 
		# Install Java Early Access
		JAVA_EA=$(sdk list java|grep "\.ea\..*-open"|head -1|cut -d '|' -f 6|tr -d ' ') && \
		sdk install java "$JAVA_EA" && \ 
		# Install some LTSs
		for v in $(sdk list java|\
				tr -s ' '|grep ' tem '|cut -d '|' -f 6|tr -d ' '| \
				sed 's/\(^[^\.-]*\)\(.*\)$/\1,\1\2/'|\
				sort -u -t, -k 1,1|cut -f 2 -d,|grep ${JAVA_LTS}); do \
			sdk install java "$v"; \
		done ;\
		# Install GraalVM
		GRAAL_VERSION=$(sdk list java|tr -d ' '|grep '\-graal$'|grep -v "\.ea\."|cut -d '|' -f 6|head -n 1) && \
		sdk install java "$GRAAL_VERSION" && \ 
		# set default java to LTS
		sdk default java "$JAVA_LTS";\
	fi && \
	sdk install maven && \
	# Set maven repository to persistent user space
	source "$HOME/.sdkman/bin/sdkman-init.sh" && \
	# add sdkman config to .zshrc
 	echo '#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!' >> "$HOME"/.zshenv && \
    echo 'export SDKMAN_DIR="$HOME/.sdkman"' >> "$HOME"/.zshenv && \
    echo '[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"' >> "$HOME"/.zshenv && \
    chown -R ${NB_UID}:${NB_GID} ${SDKMAN_DIR} && \
    mv ${SDKMAN_DIR}/tmp/*.zip /opt/sdkmanArchives/

# Adds Java, Maven to the user path
ENV PATH=/home/jovyan/.sdkman/candidates/maven/current/bin:/home/jovyan/.sdkman/candidates/java/current/bin:$PATH

# link ~/.m2 to ~/work/.m2
ENV NEEDED_WORK_DIRS="$NEEDED_WORK_DIRS .m2"

# Default to ZSH shell
SHELL ["/bin/zsh","-l","-c"]

# Adds usefull java librairies to classpath
RUN echo -e "\e[93m**** Install lombok and java dependencies ***\e[38;5;241m" && \
        mkdir -p "${HOME}/lib/" && \
        curl -sL https://projectlombok.org/downloads/lombok.jar -o "${HOME}/lib/lombok.jar" && \
        chown -R ${NB_UID}:${NB_GID} "${HOME}/lib" 
COPY --chown=$NB_UID:$NB_GID dependencies/* "$HOME/lib/"

RUN conda install --yes -c jetbrains kotlin-jupyter-kernel

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
RUN --mount=type=bind,source=Artefacts/codeserver_extensions,target=/tmp/codeserver_extensions \ 
	if [[ "$ENV" != "minimal" ]] ; then \
		echo -e "\e[93m**** Installs Code Server Extensions ****\e[38;5;241m" && \
				CODESERVERDATA_DIR=/tmp/codeserver && \
				mkdir -p "$CODESERVERDATA_DIR" && \
                PATH=/opt/bin:${PATH} code-server \
                	--user-data-dir "$CODESERVERDATA_DIR"\
                	--extensions-dir "$CODESERVEREXT_DIR" \
                    $(cat /tmp/codeserver_extensions|sed 's/./--install-extension &/') && \
				rm -rf "$CODESERVERDATA_DIR" && \
                chown -R ${NB_UID}:${NB_GID} "${CODESERVEREXT_DIR}" ; \
	fi

# Install a Java Kernel for Jupyter
ADD https://bruno.univ-tln.fr/ijava-latest.zip /tmp/ijava-kernel.zip
# Enable Java Annotations and Preview and personnal magics. Sets classpath.
COPY patch_java_kernel.sh /tmp/patch_java_kernel.sh
COPY kernel.json /opt/conda/share/jupyter/kernels/java-latest/kernel.json
ENV IJAVA_CLASSPATH="${HOME}/lib/*.jar:/usr/local/bin/*.jar"
ENV IJAVA_STARTUP_SCRIPTS_PATH="/magics/*"
RUN --mount=type=cache,target=/opt/sdkmanArchives/ --mount=type=cache,target=/var/cache/buildkit/pip,sharing=locked \
	echo -e "\e[93m**** Install Java Kernel for Jupyter ****\e[38;5;241m" && \
    unzip /tmp/ijava-kernel.zip -d /tmp/ijava-kernel && \
    cd /tmp/ijava-kernel && \
	python3 install.py --sys-prefix && \
    cd && rm -rf /tmp/ijava-kernel /tmp/ijava-kernel.zip && \
	cp --archive /opt/conda/share/jupyter/kernels/java /opt/conda/share/jupyter/kernels/java-lts && \
	cp --archive /opt/conda/share/jupyter/kernels/java /opt/conda/share/jupyter/kernels/java-ea   && \
	for v in $(sdk list java|tr -s ' '|grep ' installed '|\
		cut -d '|' -f 6|tr -d ' '|\
		sed 's/\(^[^\.-]*\)\(.*\)$/\1,\1\2/'|sort -u -t, -k 1,1|cut -f 1 -d,); do \
			if [ "$v" -ge "17" ]; then \
				cp --archive /opt/conda/share/jupyter/kernels/java /opt/conda/share/jupyter/kernels/java-"$v"; \
			fi ; \
	done && \
	rm /opt/conda/share/jupyter/kernels/java/kernel.json && \
	mv /opt/conda/share/jupyter/kernels/java/* /opt/conda/share/jupyter/kernels/java-latest/ && \
	java_lts=$(sdk list java|grep default| grep -o "[^ ]*$"|tr -d ':') && \
	java_latest=$(sdk list java|tr -s ' '|grep -v '.ea.\|-graal' |\
		grep "installed"|cut -d '|' -f 6|head -n 1|sed 's/ //g') && \
	java_ea=$(sdk list java|tr -s ' '|grep -e '.ea.' |\
		grep "installed"|cut -d '|' -f 6|sort|tail -n 1|sed 's/ //g') && \
	cp /opt/conda/share/jupyter/kernels/java-latest/kernel.json /opt/conda/share/jupyter/kernels/java-lts/kernel.json && \
	cp /opt/conda/share/jupyter/kernels/java-latest/kernel.json /opt/conda/share/jupyter/kernels/java-ea/kernel.json && \
	for v in $(sdk list java|\
                                tr -s ' '|grep ' tem '|cut -d '|' -f 6|tr -d ' '|\
                                sed 's/\(^[^\.-]*\)\(.*\)$/\1,\1\2/'|\
                                sort -u -t, -k 1,1); do \
									version=$(echo "$v"|cut -f 2 -d,)  && \
									major_version=$(echo "$v"|cut -f 1 -d,) && \
									if [ "$major_version" -ge "17" ]; then \
										cp /opt/conda/share/jupyter/kernels/java-latest/kernel.json \
											/opt/conda/share/jupyter/kernels/java-"$major_version"/kernel.json && \
										/tmp/patch_java_kernel.sh "$version" java-"$major_version"; \
									fi; \
    done && \
	/tmp/patch_java_kernel.sh ${java_lts} java-lts && \
	/tmp/patch_java_kernel.sh ${java_latest} java-latest && \
	/tmp/patch_java_kernel.sh ${java_ea} java-ea && \
    mkdir -p /home/jovyan/.local/share/jupyter/{kernels,runtime} && \
    chown -R ${NB_UID}:${NB_GID} /home/jovyan/.local/share/jupyter && \
    chown -R ${NB_UID}:${NB_GID} /opt/conda/share/jupyter/kernels

# Update installed software versions. 
COPY versions/ /versions/
COPY --chown=$NB_UID:$NB_GID README.md ${HOME}/
RUN touch ${HOME}/README.md && \
    echo "# jupyter-java softwares" > ${HOME}/README.md && \
    for versionscript in $(ls -d /versions/*) ; do \
      eval "$versionscript" 2>/dev/null >> ${HOME}/README.md ; \
    done

USER $NB_UID
COPY settings.xml /home/jovyan/.sdkman/candidates/maven/current/conf/settings.xml

