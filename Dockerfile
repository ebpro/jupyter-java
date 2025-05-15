ARG IJAVA_ROOTPROJET_NAME=IJava

# Build stage for IJava kernel
FROM eclipse-temurin:21-jdk AS ijava-builder

# Set build arguments
ARG IJAVA_ROOTPROJET_NAME

# Set working directory
WORKDIR /${IJAVA_ROOTPROJET_NAME}

# Copy gradle wrapper files first to leverage Docker cache
COPY IJava/gradle/ /${IJAVA_ROOTPROJET_NAME}/gradle/
COPY IJava/gradlew /${IJAVA_ROOTPROJET_NAME}/

# Copy project configuration files
COPY IJava/build.gradle IJava/settings.gradle IJava/gradle.properties /${IJAVA_ROOTPROJET_NAME}/

# Download dependencies first (cached layer)
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew downloadDependencies

# Copy source code and license
COPY IJava/src/ /${IJAVA_ROOTPROJET_NAME}/src/
COPY IJava/LICENSE /${IJAVA_ROOTPROJET_NAME}/LICENSE

# Build the project with caching
RUN --mount=type=cache,target=/root/.gradle \
    --mount=type=cache,target=.gradle \
    set -eux && \
    ./gradlew clean packDist \
        --info \
        --stacktrace 

FROM docker.io/brunoe/jupyter-base:feature-minimal

# Set build arguments
ARG IJAVA_ROOTPROJET_NAME

LABEL org.opencontainers.image.authors="Emmanuel BRUNO <emmanuel.bruno@univ-tln.fr>" \
      org.opencontainers.image.description="A devcontainer image for Java development" \
      org.opencontainers.image.documentation="https://github.com/ebpro/jupyter-java/" \
      org.opencontainers.image.license="MIT" \
      org.opencontainers.image.support="https://github.com/ebpro/jupyter-java/issues" \
      org.opencontainers.image.title="Java Devcontainer" \
      org.opencontainers.image.vendor="UTLN"

USER root

# Install minimal dependencies 
RUN --mount=type=bind,source=Artefacts/apt_packages,target=/tmp/Artefacts/apt_packages \ 
	--mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
	apt-get install -qq --yes --no-install-recommends \
		$(cat /tmp/Artefacts/apt_packages) && \
	rm -rf /var/lib/apt/lists/*

# Copy version scripts
COPY --chown=${NB_USER}:${NB_USER} versions/ ${HOME}/versions/

USER $NB_USER

# Set Java LTS versions to install
ENV JAVA_LTS="^21\|^25"

# Install Java development tools with SDKMAN
RUN set -e && \
    # Initialize SDKMAN
    echo "Installing SDKMAN..." && \
    curl -s "https://get.sdkman.io" | bash && \
    echo "sdkman_auto_answer=true" > ${HOME}/.sdkman/etc/config && \
    source "${HOME}/.sdkman/bin/sdkman-init.sh" && \
    # Install Java versions in a single layer
    echo "Installing Java versions..." && \
    { \
        # Install latest Java version
        JAVA_LATEST=$(sdk list java | grep -- "-tem" | cut -d '|' -f 6 | head -n 1 | tr -d ' ') && \
        echo "Installing Latest Java: ${JAVA_LATEST}" && \
        sdk install java "${JAVA_LATEST}" && \
        # Install Early Access Java
        JAVA_EA=$(sdk list java | grep "\.ea\..*-open" | head -1 | cut -d '|' -f 6 | tr -d ' ') && \
        echo "Installing EA Java: ${JAVA_EA}" && \
        sdk install java "${JAVA_EA}" && \
        # Install Java LTS versions
        echo "Installing LTS Java versions..." && \
        for version in $(sdk list java | \
                tr -s ' ' | grep ' tem ' | cut -d '|' -f 6 | tr -d ' ' | \
                sed 's/\(^[^\.-]*\)\(.*\)$/\1,\1\2/' | \
                sort -u -t, -k 1,1 | cut -f 2 -d, | grep "${JAVA_LTS}"); do \
            echo "Installing Java LTS: ${version}" && \
            sdk install java "${version}"; \
        done && \
        # Install GraalVM
        GRAAL_VERSION=$(sdk list java | tr -d ' ' | grep '\-graal$' | grep -v "\.ea\." | cut -d '|' -f 6 | head -n 1) && \
        echo "Installing GraalVM: ${GRAAL_VERSION}" && \
        sdk install java "${GRAAL_VERSION}" && \
        # Set default Java to LTS
        JAVA_LTS=$(sdk list java | grep default | grep -o "[^ ]*$" | tr -d ':') && \
        echo "Setting default Java to: ${JAVA_LTS}" && \
        sdk default java "${JAVA_LTS}" && \
        # Install Maven
        echo "Installing Maven..." && \
        sdk install maven && \
        sdk install gradle && \
        sdk install quarkus && \
        sdk install jbang && \
        sdk install kotlin; \
    } && \
    # Configure environment
    echo "Configuring environment..." && \
        echo '# SDKMAN configuration' >> "${HOME}/.zshenv" && \
        echo 'export SDKMAN_DIR="$HOME/.sdkman"' >> "${HOME}/.zshenv" && \
        echo '[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"' >> "${HOME}/.zshenv" && \
    # Verify configuration
    echo "Installation complete. Installed versions:" && \
    sdk list java | grep installed
# Adds Java, Maven to the user path
ENV PATH=/home/jovyan/.sdkman/candidates/maven/current/bin:/home/jovyan/.sdkman/candidates/java/current/bin:$PATH

# link ~/.m2 to ~/work/.m2
ENV NEEDED_WORK_DIRS=$NEEDED_WORK_DIRS:.m2

COPY settings.xml /home/jovyan/.sdkman/candidates/maven/current/conf/settings.xml

RUN conda install --yes -c jetbrains kotlin-jupyter-kernel

# Install a Java Kernel for Jupyter
# COPY --chown=${NB_USER}:${NB_USER} --from=IJava-builder ${IJAVA_ROOTPROJET_NAME}/build/distributions/IJava-latest.zip /tmp/ijava-kernel.zip

# Enable Java Annotations and Preview and personnal magics. Sets classpath.
#COPY --chown=${NB_USER}:${NB_USER} patch_java_kernel.sh /tmp/patch_java_kernel.sh
COPY --chown=${NB_USER}:${NB_USER} kernel.json /home/jovyan/miniforge3/share/jupyter/kernels/java-latest/kernel.json
ENV IJAVA_CLASSPATH="${HOME}/lib/*.jar:/usr/local/bin/*.jar"
ENV IJAVA_STARTUP_SCRIPTS_PATH="${HOME}/magics/*"

# Configure Java Kernels 
RUN --mount=type=cache,target=/var/cache/buildkit/pip,sharing=locked \
   --mount=type=bind,source=patch_java_kernel.sh,target=/tmp/patch_java_kernel.sh \ 
   --mount=type=bind,from=IJava-builder,source=${IJAVA_ROOTPROJET_NAME}/build/distributions/IJava-latest.zip,target=/tmp/ijava-kernel.zip \ 
    unzip /tmp/ijava-kernel.zip -d /tmp/ijava-kernel && \
    cd /tmp/ijava-kernel && \
    export KERNELS_DIR=$(python3 install.py --sys-prefix|sed 's/.*"\([^"]*\)\/java".*/\1/') && \
    echo "Kernel directory: ${KERNELS_DIR}" && \
    cd && rm -rf /tmp/ijava-kernel && \
    rm -v ${KERNELS_DIR}/java/kernel.json && \ 
    mkdir -p ${KERNELS_DIR}/java-lts ${KERNELS_DIR}/java-ea && \
	cp --archive ${KERNELS_DIR}/java/* ${KERNELS_DIR}/java-lts/ && \
	cp --archive ${KERNELS_DIR}/java/* ${KERNELS_DIR}/java-ea/ && \ 
    for v in $(sdk list java|tr -s ' '|grep ' installed '|\
		cut -d '|' -f 6|tr -d ' '|\
		sed 's/\(^[^\.-]*\)\(.*\)$/\1,\1\2/'|sort -u -t, -k 1,1|cut -f 1 -d,); do \
			if [ "$v" -ge "17" ]; then \
				cp --archive ${KERNELS_DIR}/java ${KERNELS_DIR}/java-"$v"; \
			fi ; \
	done && \    
	mv ${KERNELS_DIR}/java/* ${KERNELS_DIR}/java-latest/ && \
	java_lts=$(sdk list java|grep default| grep -o "[^ ]*$"|tr -d ':') && \
	java_latest=$(sdk list java|tr -s ' '|grep -v '.ea.\|-graal' |\
		grep "installed"|cut -d '|' -f 6|head -n 1|sed 's/ //g') && \
	java_ea=$(sdk list java|tr -s ' '|grep -e '.ea.' |\
		grep "installed"|cut -d '|' -f 6|sort|tail -n 1|sed 's/ //g') && \
	cp ${KERNELS_DIR}/java-latest/kernel.json ${KERNELS_DIR}/java-lts/kernel.json && \
	cp ${KERNELS_DIR}/java-latest/kernel.json ${KERNELS_DIR}/java-ea/kernel.json && \
    for v in $(sdk list java|\
                                tr -s ' '|grep ' tem '|cut -d '|' -f 6|tr -d ' '|\
                                sed 's/\(^[^\.-]*\)\(.*\)$/\1,\1\2/'|\
                                sort -u -t, -k 1,1); do \
									version=$(echo "$v"|cut -f 2 -d,)  && \
									major_version=$(echo "$v"|cut -f 1 -d,) && \
									if [ "$major_version" -ge "17" ]; then \
										cp ${KERNELS_DIR}/java-latest/kernel.json \
                                        ${KERNELS_DIR}/java-"$major_version"/kernel.json && \
										/tmp/patch_java_kernel.sh "$version" java-"$major_version"; \
									fi; \
    done && \
	/tmp/patch_java_kernel.sh ${java_lts} java-lts && \
	/tmp/patch_java_kernel.sh ${java_latest} java-latest && \
	/tmp/patch_java_kernel.sh ${java_ea} java-ea && \
    mkdir -p /home/jovyan/.local/share/jupyter/{kernels,runtime}

# Adds usefull java librairies to classpath
COPY --chown=${NB_USER}:${NB_USER} dependencies/* "$HOME/lib/"

# Adds IJava Jupyter Kernel Personnal Magics
COPY magics  ${HOME}/magics