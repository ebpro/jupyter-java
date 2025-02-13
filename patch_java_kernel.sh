#!/bin/bash
JAVA_VERSION=$1 # 22.0.0
KERNEL_NAME=$2  # java-latest
JAVA_MAJOR_VERSION=$(echo "$JAVA_VERSION"|sed 's/ //g'|sed 's/^\([0-9]*\).*/\1/')
if "$KERNEL_NAME" == "java-latest"; then
        PREVIEW="--enable-preview --release ${JAVA_MAJOR_VERSION}"
else
        PREVIEW=""
fi
IKERNEL_JAR=$(ls /opt/conda/share/jupyter/kernels/${KERNEL_NAME}/IJava*.jar| sed 's/\//\\\//g')
# "IJAVA_COMPILER_OPTS":"-deprecation -Xlint:preview -XprintProcessorInfo -XprintRounds --enable-preview --release ${JAVA_MAJOR_VERSION} --add-exports=jdk.compiler/com.sun.tools.javac.processing=ALL-UNNAMED"
DYNENV=`cat <<EOF
"env": 
        {
        "JAVA_HOME":"/home/jovyan/.sdkman/candidates/java/${JAVA_VERSION}",
        "PATH":"/home/jovyan/.sdkman/candidates/java/${JAVA_VERSION}/bin:$PATH",
        "JAVA_OPTS":"--enable-preview",
        "IJAVA_COMPILER_OPTS":"-deprecation \
                -g \
                -Xlint:all \
                -XprintProcessorInfo \
                -XprintRounds \
                ${PREVIEW} \
                --add-exports=jdk.compiler/com.sun.tools.javac.processing=ALL-UNNAMED \
                --add-modules=ALL-SYSTEM"
        }
EOF
`
DYNENV=$(echo $DYNENV|sed 's/\//\\\//g')

echo "Java version      :" $JAVA_VERSION
echo "Kernel name       :" $KERNEL_NAME
echo "Java Major Version:" $JAVA_MAJOR_VERSION
echo "Java Kernel jar   :" $IKERNEL_JAR
echo "Kernel env        :" $DYNENV

sed -i s/___ENV/"$DYNENV"/                /opt/conda/share/jupyter/kernels/${KERNEL_NAME}/kernel.json
sed -i s/___DISPLAY_NAME/"$KERNEL_NAME"/  /opt/conda/share/jupyter/kernels/${KERNEL_NAME}/kernel.json
sed -i s/___IKERNEL_JAR/"$IKERNEL_JAR"/   /opt/conda/share/jupyter/kernels/${KERNEL_NAME}/kernel.json
