#!/bin/bash
echo "## Java"
sdk list java|grep installed
echo "  * "$(mvn --version|head -n 1|cut -d ' ' -f 1,2,3)