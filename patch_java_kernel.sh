#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Function to print formatted messages
log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

# Function to validate input parameters
validate_inputs() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: $0 <java_version> <kernel_name>" >&2
        echo "Example: $0 22.0.0 java-latest" >&2
        exit 1
   fi 
}

# Function to extract major version
get_major_version() {
    echo "$1" | sed 's/ //g' | sed 's/^\([0-9]*\).*/\1/'
}

# Function to get kernel jar path
get_kernel_jar() {
    local kernel_name=$1
    ls "${KERNELS_DIR}/${kernel_name}/IJava"*.jar | sed 's/\//\\\//g'
}

# Function to generate environment configuration
generate_env_config() {
    local java_version=$1
    local java_major_version=$2
    local preview=$3

    echo "env": {"JAVA_HOME":"/home/jovyan/.sdkman/candidates/java/${java_version}","PATH":"/home/jovyan/.sdkman/candidates/java/${java_version}/bin:${PATH}","JAVA_OPTS":"--enable-preview","IJAVA_COMPILER_OPTS":"-deprecation -g -Xlint:all -XprintProcessorInfo -XprintRounds ${preview} --add-exports=jdk.compiler/com.sun.tools.javac.processing=ALL-UNNAMED --add-modules=ALL-SYSTEM"}
}

# Main execution
main() {
    validate_inputs "$@"

    local java_version=$1
    local kernel_name=$2
    local java_major_version
    local preview
    local ikernel_jar
    local dynenv

    java_major_version=$(get_major_version "$java_version")
    
    if [[ "$kernel_name" == "java-latest" ]]; then
        preview="--enable-preview --release ${java_major_version}"
    else
        preview=""
    fi

    ikernel_jar=$(get_kernel_jar "$kernel_name")
    dynenv=$(generate_env_config "$java_version" "$java_major_version" "$preview" | sed 's/\//\\\//g')

    # Log configuration
    log_info "Java version      : $java_version"
    log_info "Kernel name       : $kernel_name"
    log_info "Java Major Version: $java_major_version"
    log_info "Java Kernel jar   : $ikernel_jar"
    log_info "Kernel env        : $dynenv"

    # Update kernel configuration
    if [[ ! -d "${KERNELS_DIR}/${kernel_name}" ]]; then
        echo "Error: Kernel directory not found: ${KERNELS_DIR}/${kernel_name}" >&2
        exit 1
    fi

    sed -i "s/___ENV/$dynenv/"                 "${KERNELS_DIR}/${kernel_name}/kernel.json"
    sed -i "s/___DISPLAY_NAME/$kernel_name/"   "${KERNELS_DIR}/${kernel_name}/kernel.json"
    sed -i "s/___IKERNEL_JAR/$ikernel_jar/"    "${KERNELS_DIR}/${kernel_name}/kernel.json"

    log_info "Kernel configuration updated successfully"
}

# Execute main function
main "$@"