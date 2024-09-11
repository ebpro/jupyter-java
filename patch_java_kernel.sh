#!/bin/bash
JAVA_VERSION=$1 # 22.0.0
KERNEL_NAME=$2  # java-latest
JAVA_MAJOR_VERSION=$(echo "$JAVA_VERSION"|sed 's/ //g'|sed 's/^\([0-9]*\).*/\1/')
IKERNEL_JAR=$(ls /opt/conda/share/jupyter/kernels/${KERNEL_NAME}/IJava*.jar| sed 's/\//\\\//g')
DYNENV=`cat <<EOF
"env": 
        {
        "JAVA_HOME":"/home/jovyan/.sdkman/candidates/java/${JAVA_VERSION}",
        "PATH":"/home/jovyan/.sdkman/candidates/java/${JAVA_VERSION}/bin:$PATH",
        "JAVA_OPTS":"--enable-preview",
        "IJAVA_COMPILER_OPTS":"-deprecation -Xlint:preview -XprintProcessorInfo -XprintRounds --enable-preview --release ${JAVA_MAJOR_VERSION} --add-exports=jdk.compiler/com.sun.tools.javac.processing=ALL-UNNAMED"
        }
EOF
`
DYNENV=$(echo $DYNENV|sed 's/\//\\\//g')

echo "Java version      :" $JAVA_VERSION
echo "Kernel name       :" $KERNEL_NAME
echo "Java Major Version:" $JAVA_MAJOR_VERSION
echo "Java Kernel jar   :" $IKERNEL_JAR
echo "Kernel envi       :" $DYNENV

sed -i s/ENV/"$DYNENV"/ /opt/conda/share/jupyter/kernels/${KERNEL_NAME}/kernel.json
sed -i s/Java/"$KERNEL_NAME"/ /opt/conda/share/jupyter/kernels/${KERNEL_NAME}/kernel.json
sed -i s/IKERNEL_JAR/"$IKERNEL_JAR"/ /opt/conda/share/jupyter/kernels/${KERNEL_NAME}/kernel.json
