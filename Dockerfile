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
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update && \
	apt-get install -qq --yes --no-install-recommends \
		$(cat /tmp/apt_packages) && \
	rm -rf /var/lib/apt/lists/*	

# Adds IJava Jupyter Kernel Personnal Magics
COPY magics  /magics

ARG VERSION

# Install java dev tools with sdkman  
#     latest java jdk LTS, the latest jdk, and early access
#     stable mvn 3
RUN --mount=type=cache,target=/opt/sdkmanArchives/,sharing=locked \
    echo -e "\e[93m**** Installs SDKMan, JDK and Maven ****\e[38;5;241m" && \
    curl -s "https://get.sdkman.io" | bash && \
    mkdir -p /home/jovyan/.sdkman/archives/ && \
    ln -s /opt/sdkmanArchives/ /home/jovyan/.sdkman/archives/ && \
    echo "sdkman_auto_answer=true" > ${HOME}/.sdkman/etc/config && \
	source "$HOME/.sdkman/bin/sdkman-init.sh" && \
	java_lts=$(sdk list java|grep default| grep -o "[^ ]*$"|tr -d ':') && \
	# Installs all LTSs, early access JDK and latest maven
	if [[ "$ENV" = "stable" ]] ; then \
		sdk install java ;\
	else \
		# install Java 8
	    sdk install java $(sdk list java|grep "8\..*fx-zulu"|head -n 1|cut -d '|' -f 6)  && \ 
		# install Java Early Access
		sdk install java $(sdk list java|grep "\.ea\..*-open"|head -1|cut -d '|' -f 6) && \ 
		# Install LTSs and Latest
		for v in $(sdk list java|\
				tr -s ' '|grep ' tem '|cut -d '|' -f 6|tr -d ' '| \
				sed 's/\(^[^\.-]*\)\(.*\)$/\1,\1\2/'|\
				sort -u -t, -k 1,1|cut -f 2 -d,); do \
			sdk install java "$v"; \
		done ;\
		GRAAL_VERSION=$(sdk list java|tr -d ' '|grep '\-graal$'|grep -v "\.ea\."|cut -d '|' -f 6|head -n 1) && \
		sdk install java "$GRAAL_VERSION" && \ 
		sdk default java "$java_lts";\
	fi && \
	sdk install maven

	# Set maven repository to persistent user space
RUN  --mount=type=cache,target=/opt/sdkmanArchives/,sharing=locked \
	source "$HOME/.sdkman/bin/sdkman-init.sh" && \
	echo \
    "<settings xmlns='http://maven.apache.org/SETTINGS/1.2.0' \
      		   xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' \
    		   xsi:schemaLocation='http://maven.apache.org/SETTINGS/1.2.0 https://maven.apache.org/xsd/settings-1.2.0.xsd'> \
        <localRepository>\${user.home}/work/.m2/repository</localRepository> \
		<interactiveMode>false</interactiveMode> \
		<mirrors> \    
 			<mirror> \
  				<id>compute-lsis-2</id> \
  				<mirrorOf>central</mirrorOf> \
  				<url>https://nexus.ebruno.fr/repository/maven-central</url> \
 			</mirror> \
		</mirrors> \
		<profiles> \
		  <profile> \
  			<id>myprofile</id> \
 			<activation> \
  				<activeByDefault>true</activeByDefault> \
 			</activation> \
			<properties> \
				<style.color>never</style.color>\
			</properties> \
  			<repositories> \
    			<repository> \
      				<id>MavenCentral</id> \
       				<name>Central but with another name to bypass proxy unavailable</name> \
       				<url>https://repo1.maven.org/maven2</url> \ 
    			</repository> \
  			</repositories> \ 
		 </profile> \
		</profiles> \
		</settings>" \
    	> ${HOME}/.sdkman/candidates/maven/current/conf/settings.xml && \
	# add sdkman config to .zshrc
 	echo '#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!' >> "$HOME"/.zshenv && \
    echo 'export SDKMAN_DIR="$HOME/.sdkman"' >> "$HOME"/.zshenv && \
    echo '[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"' >> "$HOME"/.zshenv && \
	# sdk flush && \
	groupadd sdk && \
	chgrp -R sdk ${SDKMAN_DIR} &&\
	chmod 770 -R ${SDKMAN_DIR} && \	
	adduser ${NB_USER} sdk && \
	# sdk flush && \
	# sdk flush broadcast && \
	fix-permissions /home/${NB_USER}/.sdkman

# Adds Java, Maven to the user path
ENV PATH=/home/jovyan/.sdkman/candidates/maven/current/bin:/home/jovyan/.sdkman/candidates/java/current/bin:$PATH

# link ~/.m2 to ~/work/.m2
ENV NEEDED_WORK_DIRS="$NEEDED_WORK_DIRS .m2"

# Default to ZSH shell
SHELL ["/bin/zsh","-l","-c"]

# Adds usefull java librairies to classpath
RUN echo -e "\e[93m**** Install lombok and java dependencies ***\e[38;5;241m" && \
        mkdir -p "${HOME}/lib/" && \
        curl -sL https://projectlombok.org/downloads/lombok.jar -o "${HOME}/lib/lombok.jar"
COPY dependencies/* "$HOME/lib/"

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
COPY Artefacts/codeserver_extensions /tmp/

#RUN cd $(dirname $(readlink $(type code-server))) && \
#	rm -rf node_modules/argon2 \
#	&& npm install -g node-gyp \
#	&& npm install argon2 argon2-cli \
#	&& npx argon2-cli -d -e

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

# Install a Java Kernel for Jupyter
ADD https://bruno.univ-tln.fr/ijava-latest.zip /tmp/ijava-kernel.zip
# Enable Java Annotations and Preview and personnal magics. Sets classpath.
COPY patch_java_kernel.sh /tmp/patch_java_kernel.sh
COPY kernel.json /opt/conda/share/jupyter/kernels/java-latest/kernel.json
ENV IJAVA_CLASSPATH="${HOME}/lib/*.jar:/usr/local/bin/*.jar"
ENV IJAVA_STARTUP_SCRIPTS_PATH="/magics/*"
RUN --mount=type=cache,target=/opt/sdkmanArchives/ --mount=type=cache,target=/var/cache/buildkit/pip,sharing=locked \
	echo -e "\e[93m**** Install Java Kernel for Jupyter ****\e[38;5;241m" && \
    #curl -sL https://github.com/SpencerPark/IJava/releases/download/v1.3.0/ijava-1.3.0.zip -o /tmp/ijava-kernel.zip && \
	echo ok5 && \
    unzip /tmp/ijava-kernel.zip -d /tmp/ijava-kernel && \
    cd /tmp/ijava-kernel && \
	# conda create -y --name java-lts && \
	# /bin/bash -c "source activate java-lts" && \
	python3 install.py --sys-prefix && \
    cd && rm -rf /tmp/ijava-kernel /tmp/ijava-kernel.zip && \
	cp --archive /opt/conda/share/jupyter/kernels/java /opt/conda/share/jupyter/kernels/java-lts && \
	cp --archive /opt/conda/share/jupyter/kernels/java /opt/conda/share/jupyter/kernels/java-ea && \
	for v in $(sdk list java|tr -s ' '|grep ' installed '|\
		cut -d '|' -f 6|tr -d ' '|\
		sed 's/\(^[^\.-]*\)\(.*\)$/\1,\1\2/'|sort -u -t, -k 1,1|cut -f 1 -d,); do \
			if [ "$v" -ge "17" ]; then \
				cp --archive /opt/conda/share/jupyter/kernels/java /opt/conda/share/jupyter/kernels/java-"$v"; \
			fi ; \
	done && \
	mv /opt/conda/share/jupyter/kernels/java /opt/conda/share/jupyter/kernels/java-latest && \
	java_lts=$(sdk list java|grep default| grep -o "[^ ]*$"|tr -d ':') && \
	java_latest=$(sdk list java|tr -s ' '|grep -v '.ea.' |\
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
    fix-permissions ${CONDA_DIR} && \
    fix-permissions /home/${NB_USER}

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

