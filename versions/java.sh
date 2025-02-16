#!/bin/bash

# Function to get Maven version
get_maven_version() {
    mvn --version | head -n 1 | cut -d ' ' -f 3
}

# Function to format Java version entries
format_java_versions() {
    while read -r line; do
        # Extract version and vendor from SDKMAN output
        version=$(echo "$line" | awk -F'|' '{print $1}' | tr -d ' ')
        vendor=$(echo "$line" | awk -F'|' '{print $4}' | tr -d ' ')
        if [[ $line == *">"* ]]; then
            echo "- **${version}** (${vendor}) ⭐ _default_"
        else
            echo "- ${version} (${vendor})"
        fi
    done
}

# Print Markdown formatted output
cat << EOF
## Java Development Environment

### Installed Java Versions

$(sdk list java | grep installed | format_java_versions)

### Build Tools

- **Maven**: v$(get_maven_version)

> This environment includes multiple Java versions managed by SDKMAN, with Maven as the build tool.
> The ⭐ indicates the default Java version.
EOF