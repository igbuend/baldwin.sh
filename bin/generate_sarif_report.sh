#!/bin/bash

# This script generates a markdown report from SARIF files.

# Check if jq is installed
if ! command -v jq &> /dev/null
then
    echo "jq could not be found, please install it to use this script."
    exit 1
fi

# Directory containing SARIF files
SARIF_DIR="./output/sarif"

# Check if the directory exists
if [ ! -d "$SARIF_DIR" ]; then
    echo "Directory $SARIF_DIR not found."
    exit 1
fi

# Iterate over all SARIF files in the directory
for sarif_file in "$SARIF_DIR"/*.sarif; do
    if [ ! -f "$sarif_file" ]; then
        continue
    fi

    echo "Processing $sarif_file..."

    # Extract and process issues
    jq -c '.runs[].results[]' "$sarif_file" | while IFS= read -r result; do
        # Extract information for the report
        title=$(echo "$result" | jq -r '.ruleId')
        description=$(echo "$result" | jq -r '.message.text')
        locations=$(echo "$result" | jq -r '[.locations[] | .physicalLocation.artifactLocation.uri + " (" + (.physicalLocation.region.startLine | tostring) + ")"] | join(", ")')
        recommendation=$(echo "$result" | jq -r '.remediation.fixes[].description.text // "Not available"')
        references=$(echo "$result" | jq -r 'try .properties.references[] catch "Not available"')
        supporting_info=$(echo "$result" | jq -r '.message.text')

        # Generate Markdown output
        echo "## $title"
        echo ""
        echo "### Description"
        echo "$description"
        echo ""
        echo "### Location"
        echo "$locations"
        echo ""
        echo "### Recommendation"
        echo "$recommendation"
        echo ""
        echo "### References"
        echo "$references"
        echo ""
        echo "### Supporting Information"
        echo "$supporting_info"
        echo ""
    done
done
