#!/usr/bin/env bash

project_version() {
    local project_file="$1"
    awk '/MARKETING_VERSION:/ { print $2; exit }' "${project_file}"
}

bump_patch_version() {
    local project_file="$1"
    local current major minor patch next

    current="$(project_version "${project_file}")"
    IFS=. read -r major minor patch <<<"${current}"

    if [[ -z "${major}" || -z "${minor}" || -z "${patch}" ]]; then
        echo "error: MARKETING_VERSION must look like major.minor.patch, got '${current}'" >&2
        exit 1
    fi

    next="${major}.${minor}.$((patch + 1))"

    perl -0pi -e "s/MARKETING_VERSION: \\Q${current}\\E/MARKETING_VERSION: ${next}/" "${project_file}"
    perl -0pi -e "s/CURRENT_PROJECT_VERSION: \\d+/CURRENT_PROJECT_VERSION: $((patch + 1))/" "${project_file}"

    echo "${next}"
}
