#!/usr/bin/env bash

# Define the URLs
URL_countries="https://openholidaysapi.org/Countries"
URL_languages="https://openholidaysapi.org/Languages"
URL_subdivisions="https://openholidaysapi.org/Subdivisions?countryIsoCode=" # ${key}

# Define the temporary files and the refresh period
TMP_FILE_COUNTRIES="/tmp/dline_OHA_countries.json"
TMP_FILE_LANGUAGES="/tmp/dline_OHA_languages.json"
REFRESH_PERIOD=$((60*60*24*30*12))  # 12 months in seconds


delete_oha() {
    # Delete all instances of imported entries from OpenHolidaysAPI
    if delete_line " #oh$"; then
        # Reset 'oha_imported' from the $LOGS_FILE
        current_date_dd=""
        update_api_date_log
        # Reset 'oha_country_iso' from the $LOGS_FILE
        key=""
        update_oha_country_log
        # Reset 'oha_language_iso' from the $LOGS_FILE
        language_key=""
        update_oha_language_log
        # Reset 'oha_subdivision_iso' from the $LOGS_FILE
        subdivision_isoCode=""
        update_oha_subdivision_log
    fi
}


input_language() {
    # Get the available languages for the selected key from the countries data
    official_languages=$(echo "$content_countries" | jq -r --arg key "$key" '.[] | select(.isoCode==$key) | .officialLanguages[]')

    # Initialize an array to store the language options
    language_options=()

    # Add English as the first option
    language_options+=("EN English")

    # Loop through the official languages
    for language_key in $official_languages; do
        # Skip if the language key is EN since we already added English
        if [ "$language_key" != "EN" ]; then
            # Get the English name of the language from the languages data
            language_name=$(echo "$content_languages" | jq -r --arg key "$language_key" '.[] | select(.isoCode==$key) | .name[] | select(.language=="EN") | .text')

            # Add the language option to the array
            language_options+=("${language_key} ${language_name}")
        fi
    done

    # Print the available languages with formatting and a tab separator
    echo "Available Languages:"
    for line in "${language_options[@]}"; do
        language_key=$(echo "${line}" | cut -d' ' -f1)
        language_name=$(echo "${line}" | cut -d' ' -f2-)
        echo -e " [${yellow}${language_key}${reset}] ${language_name}"
    done

    # Initialize a variable to keep track of whether the user's selection is valid
    valid=false
    echo

    # Loop until the user's selection is valid
    while [ "$valid" = false ]; do
        # Prompt the user to choose a language
        read -p "Please choose a language from the list above (enter the value in square brackets): " language_key

        # Convert the user's input to uppercase
        language_key=${language_key^^}

        # Validate the user's input
        for line in "${language_options[@]}"; do
            language_isoCode=$(echo "${line}" | cut -d' ' -f1)
            language_name=$(echo "${line}" | cut -d' ' -f2-)
            if [[ "${language_isoCode^^}" == "${language_key}" ]]; then
                echo "▸▸▸ Selected: ${language_name}"
                echo
                valid=true
                break
            fi
        done

        if [ "$valid" = false ]; then
            echo "Invalid selection. Please enter a language code from the list."
            echo
        fi
    done
}


input_country() {
    # Use jq to parse the JSON and print the key-name pairs
    keys=$(echo "${content_countries}" | jq -r '.[] | "\(.isoCode) \(.name[] | select(.language=="EN") .text)"')

    # Add an option for "Other" or "Not listed"
    keys+=$(echo -e "\nX Other (Not listed)")

    # Print the key-name pairs
    echo "Available countries:"
    while IFS= read -r line; do
        key=$(echo "${line}" | cut -d' ' -f1)
        name=$(echo "${line}" | cut -d' ' -f2-)
        echo -e " [${yellow}${key}${reset}]\t${name}"
    done <<< "$keys"

    # Initialize a variable to keep track of whether the user's selection is valid
    valid=false
    echo

    # Loop until the user's selection is valid
    while [ "$valid" = false ]; do
        # Prompt the user to choose a key
        read -p "Please choose a key from the list above: " key
        key=${key^^}

        # Validate the user's input
        while IFS= read -r line; do
            country_isoCode=$(echo "${line}" | cut -d' ' -f1)
            country_name=$(echo "${line}" | cut -d' ' -f2-)
            if [ "${key}" == "${country_isoCode^^}" ]; then
                echo "▸▸▸ Selected: ${country_name}"
                echo
                valid=true
                break
            fi
        done <<< "${keys}"
        if [ "$valid" = false ]; then
            echo "Invalid selection. Please enter a country code from the list."
            echo
        fi

    done
}

input_subdivisions() {
    # Define the URL for subdivisions
    URL_subdivisions+="${key}"
    TMP_FILE_SUBDIVISIONS="/tmp/dline_OHA_${key}_subdivisions.json"

    # Fetch the data for subdivisions
    fetch_data "$URL_subdivisions" "$TMP_FILE_SUBDIVISIONS"

    # Read the content from the temporary file
    content_subdivisions=$(cat "$TMP_FILE_SUBDIVISIONS")

    # Get the available subdivisions for the selected key
    subdivisions=$(echo "$content_subdivisions" | jq -r --arg lang "$language_key" '.[] | "\(.isoCode) \(.shortName) \(.name[] | select(.language==$lang) .text)"')

    # Check if there are any subdivisions
    if [ -n "$subdivisions" ]; then
        # Print the available subdivisions with formatting and a tab separator
        echo "Available Subdivisions:"
        while IFS= read -r line; do
            isoCodeSubdivision=$(echo "${line}" | cut -d' ' -f1)
            subdivision=$(echo "${line}" | cut -d' ' -f2)
            name=$(echo "${line}" | cut -d' ' -f3-)
            echo -e " [${yellow}${subdivision}${reset}]\t${name}"
        done <<< "${subdivisions}"

        # Initialize a variable to keep track of whether the user's selection is valid
        valid=false
        echo

        # Loop until the user's selection is valid
        while [ "$valid" = false ]; do
            # Prompt the user to choose a subdivision
            read -p "Please choose a subdivision from the list above: " subdivision
            subdivision=${subdivision^^}

            # Validate the user's input
            while IFS= read -r line; do
                subdivision_isoCode=$(echo "${line}" | cut -d' ' -f1)
                subdivision_shortName=$(echo "${line}" | cut -d' ' -f2)
                subdivision_name=$(echo "${line}" | cut -d' ' -f3-)
                if [ "${subdivision}" == "${subdivision_shortName^^}" ]; then
                    echo "▸▸▸ Selected: ${subdivision_name}"
                    echo
                    valid=true
                    break
                fi
            done <<< "${subdivisions}"
            if [ "$valid" = false ]; then
                echo "Invalid selection. Please enter a subdivision code from the list."
                echo
            fi
        done
    fi
}


export_public_holiday() {
    URL_public_holiday="https://openholidaysapi.org/PublicHolidays?countryIsoCode=${key}&languageIsoCode=${language_key}&validFrom=${current_year}-01-01&validTo=${next2_year}-12-31"
    TMP_FILE_PUBLIC_HOLIDAY="/tmp/dline_OHA_${key}_${language_key}_${current_year}_public_holiday.json"

    # Fetch the data for public holiday
    fetch_data "$URL_public_holiday" "$TMP_FILE_PUBLIC_HOLIDAY"

    # Read the content from the temporary file
    content_public_holiday=$(cat "$TMP_FILE_PUBLIC_HOLIDAY")

    # Get the public holidays for the selected country from the JSON data
    public_holidays=$(echo "$content_public_holiday" | jq -r --arg key "$key" --arg lang "$language_key" --arg sub "$subdivision" '.[] | select(.nationwide==true or (.subdivisions[]? | .shortName==$sub)) | "\(.startDate) \(.endDate) \(.name[] | select(.language==$lang) | .text)"')

    # Write the public holidays to a file
    while IFS= read -r line; do
        start_date=$(echo "$line" | cut -d' ' -f1)
        end_date=$(echo "$line" | cut -d' ' -f2)
        name=$(echo "$line" | cut -d' ' -f3-)

        # Skip invalid entries
        if [[ -z "$start_date" || -z "$end_date" || -z "$name" ]]; then
            continue
        fi

        # If the start date and end date are different, add multiple entries
        if [ "$start_date" != "$end_date" ]; then
            current_date="$start_date"
            while [ "$current_date" != "$end_date" ]; do
                # Check if the entry already exists in the file
                if ! grep -q "^${current_date//-//} 5 $name #oh$" $INPUT_FILE; then
                    echo "${current_date//-//} 5 $name #oh" >> $INPUT_FILE
                fi
                current_date=$(date -I -d "$current_date + 1 day")
            done
        fi

        # Check if the entry already exists in the file
        if ! grep -q "^${end_date//-//} 5 $name #oh$" $INPUT_FILE; then
            echo "${end_date//-//} 5 $name #oh" >> $INPUT_FILE
        fi
    done <<< "$public_holidays"
}


export_school_holiday() {
    URL_school_holiday="https://openholidaysapi.org/SchoolHolidays?countryIsoCode=${key}&subdivisionCode=${subdivision_isoCode}&languageIsoCode=${language_isoCode}&validFrom=${current_year}-01-01&validTo=${next2_year}-12-31"
    TMP_FILE_SCHOOL_HOLIDAY="/tmp/dline_OHA_${key}_${subdivision_isoCode}_${language_isoCode}_${current_year}_school_holiday.json"

    # Fetch the data for school holiday
    fetch_data "$URL_school_holiday" "$TMP_FILE_SCHOOL_HOLIDAY"

    # Read the content from the temporary file
    content_school_holiday=$(cat "$TMP_FILE_SCHOOL_HOLIDAY")

    # Get the school holidays for the selected country from the JSON data
    school_holidays=$(echo "$content_school_holiday" | jq -r --arg key "$key" --arg lang "$language_key" --arg sub "$subdivision" '.[] | select(.nationwide==true or (.subdivisions[]? | .shortName==$sub)) | "\(.startDate) \(.endDate) \(.name[] | select(.language==$lang) | .text)"')

    # Write the school holidays to a file
    while IFS= read -r line; do
        start_date=$(echo "$line" | cut -d' ' -f1)
        end_date=$(echo "$line" | cut -d' ' -f2)
        name=$(echo "$line" | cut -d' ' -f3-)

        # Skip invalid entries
        if [[ -z "$start_date" || -z "$end_date" || -z "$name" ]]; then
            continue
        fi

        # If the start date and end date are different, add multiple entries
        if [ "$start_date" != "$end_date" ]; then
            current_date="$start_date"
            while [ "$current_date" != "$end_date" ]; do
                # Check if the entry already exists in the file
                if ! grep -q "^${current_date//-//} 8 $name #oh$" $INPUT_FILE; then
                    echo "${current_date//-//} 8 $name #oh" >> $INPUT_FILE
                fi
                current_date=$(date -I -d "$current_date + 1 day")
            done
        fi

        # Check if the entry already exists in the file
        if ! grep -q "^${end_date//-//} 8 $name #oh$" $INPUT_FILE; then
            echo "${end_date//-//} 8 $name #oh" >> $INPUT_FILE
        fi
    done <<< "$school_holidays"
}


# Function to fetch data from a URL and save it to a temporary file
fetch_data() {
  local url=${1}
  local tmp_file=${2}

  # Check if the temporary file exists and is not older than the refresh period
  if [[ ! -f "${tmp_file}" || $(($(date +%s) - $(date +%s -r "${tmp_file}"))) -gt $REFRESH_PERIOD ]]; then
    # Use curl to get the content from the URL and save it to the temporary file
    curl -s "${url}" -H "accept: text/json" >| "${tmp_file}"
  fi
}


update_api_date_log() {
    jq --arg current_date_dd "$current_date_dd" '.oha_imported = $current_date_dd' $SETTINGS > tmp.$$.json && mv tmp.$$.json $SETTINGS
}


update_oha_country_log() {
    jq --arg country_iso "$key" '.oha_country_iso = $country_iso' $SETTINGS > tmp.$$.json && mv tmp.$$.json $SETTINGS
}


update_oha_language_log() {
    jq --arg language_iso "$language_key" '.oha_language_iso = $language_iso' $SETTINGS > tmp.$$.json && mv tmp.$$.json $SETTINGS
}


update_oha_subdivision_log() {
    jq --arg subdivision_iso "$subdivision_isoCode" '.oha_subdivision_iso = $subdivision_iso' $SETTINGS > tmp.$$.json && mv tmp.$$.json $SETTINGS
}


oha() {
    # Fetch the data
    fetch_data "${URL_countries}" "${TMP_FILE_COUNTRIES}"
    fetch_data "${URL_languages}" "${TMP_FILE_LANGUAGES}"

    # Read the content from the temporary files
    content_countries=$(cat "$TMP_FILE_COUNTRIES")
    content_languages=$(cat "$TMP_FILE_LANGUAGES")

    if [[ -z "$(echo "${oha_country_iso}" | xargs)" || "${1^^}" == "IMPORT" ]]; then
        input_country
        update_oha_country_log
    else
        key=$oha_country_iso
    fi
    if [[ ${key^^} == "X" ]]; then
        return 0
    fi
    oha_language_iso= # Trim spaces
    if [[ -z "$(echo "${oha_language_iso}" | xargs)" || "${1^^}" == "IMPORT" ]]; then
        input_language
        update_oha_language_log
    else
        language_key=$oha_language_iso
    fi
    if [[ -z "$(echo "${oha_subdivision_iso}" | xargs)" || "${1^^}" == "IMPORT" ]]; then
        input_subdivisions
        update_oha_subdivision_log
    else
        subdivision_isoCode=$oha_subdivision_iso
    fi
    export_public_holiday
    if [[ -z $@ ]]; then
        yes_no "Download school holidays for your region?"
    else
        yes_no "Download updates on school holidays for your region?"
    fi
    if [[ $user_input == "yes" ]]; then
        export_school_holiday
    fi
    echo "OpenHolidaysAPI: Operation completed."
    echo
}
