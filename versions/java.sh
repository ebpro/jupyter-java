#!/bin/bash
echo "## Java"
echo "  * "$(java --version|head -n 1)
echo "  * "$(mvn --version|head -n 1|cut -d ' ' -f 1,2,3)