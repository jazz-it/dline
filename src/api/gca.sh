#!/bin/bash

# Specify your date range
start_date=${TODAY////-}
end_date="${next_year}-12-31"
today=${start_date}
# Create temporary files
tempfile=$(mktemp)
temp_output=$(mktemp)


# Delete selected entries
delete_gca_lines() {
    awk -v start_date="$1" -v end_date="$2" -v code="$3" '
        BEGIN { FS = OFS = " " }
        $1 ~ /^[0-9]{4}\/[0-9]{2}\/[0-9]{2}$/ && $1 >= start_date && $1 <= end_date {
            if (code != "") {
                if ($2 == code && $0 ~ / #gc$/) {
                    next;  # Skip this line
                }
            }
        }
        { print }  # Print all other lines
' "${INPUT_FILE}" >| ${tempfile}
    if [[ -s ${tempfile} ]]; then
        mv ${tempfile} ${INPUT_FILE}
    else
        rm ${tempfile}
    fi
}


# Delete the entry from the $SETTINGS
delete_gca_json() {
    echo "Please select an imported Google Calendar to delete:"
    for ((i=0; i<${num_gca}; i++)); do
        j=$((i+1))
        if [[ -n ${defaults["gca[$i][name]"]} ]]; then
            echo -e " [${yellow}${j}${reset}] ${defaults["gca[$i][name]"]}"
        else
            echo -e " [${yellow}${j}${reset}] Multiple calendars"
        fi
    done
    [[ $j -ne 1 ]] && echo -e " [${yellow}A${reset}] All calendars from above"
    echo -e " [${yellow}X${reset}] Cancel"
    echo

    # Infinite loop until a valid option is chosen
    while true; do
        read -p "Enter a calendar code: " choice

        # Check if the choice is a valid calendar "key"
        if [[ ( "${choice}" =~ ^[1-9][0-9]*$ && ${choice} -le ${j} && ${choice} -gt 0 ) || ${choice^^} == "A" || ${choice^^} == "X" ]]; then
            if [[ ${choice^^} == "A" ]]; then
                selected_cal="All calendars"
            elif [[ ${choice^^} == "X" ]]; then
                echo "Operation cancelled"
                echo
                return
            elif [[ -n ${defaults["gca[$((choice-1))][name]"]} && ${choice} -le ${j} ]]; then
                selected_cal="${defaults["gca[$((choice-1))][name]"]}"
            else
                selected_cal="Multiple calendars"
            fi
            echo "▸▸▸ Selected: ${selected_cal}"
            echo
            if [[ ${choice^^} == "A" ]]; then
                if delete_line " #gc$"; then
                    jq 'del(.gca[] | select(.name != ""))' ${SETTINGS} > temp.json && mv temp.json ${SETTINGS}
                fi
                break
            elif [[ ${selected_cal} == "Multiple calendars" ]]; then
                delete_gca_lines ${defaults["gca[$((choice-1))][imported_date]"]} ${defaults["gca[$((choice-1))][end_date]"]} ${defaults["gca[$((choice-1))][category]"]}
                # Delete the entry from the JSON file
                jq --arg name "${defaults["gca[$((choice-1))][name]"]}" 'del(.gca[] | select(.name == $name))' ${SETTINGS} > temp.json && mv temp.json ${SETTINGS}
            else
                delete_gca_lines ${defaults["gca[$((choice-1))][imported_date]"]} ${defaults["gca[$((choice-1))][end_date]"]}
                # Delete the entry from the JSON file
                jq 'del(.gca[] | select(.name != ""))' ${SETTINGS} > temp.json && mv temp.json ${SETTINGS}
            fi
            echo -e "${yellow}${selected_cal}${reset} deleted successfully."
            sort_input
            echo
            break
        else
            echo "Invalid choice. Please enter a valid option."
            echo
        fi
    done
}


# Update the entry from the $SETTINGS
update_gca_json() {
    # If no existing entry is found, append the new entry to the reminders attribute in the $SETTINGS file
    jq --arg name "${calendar_name}" --arg imported_date "${today}" --arg end_date "${end_date}" --arg category "${selected_code}" '
        if (.gca | map(select(.name == $name)) | length > 0)
        then
            .gca |= map(if .name == $name then . + {imported_date: $imported_date, end_date: $end_date, category: $category} else . end)
        else
            .gca += [{name: $name, imported_date: $imported_date, end_date: $end_date, category: $category}]
        end
' "${SETTINGS}" > temp.json && mv temp.json "${SETTINGS}"
}


# Import Google Calendar
import_gca() {
    if [[ -n $1 && -z $2 ]]; then
        arg_choice="A"
        selected_code="${1}"
        selectAll=1
    elif [[ ${#1} -eq 1 && -n $2 ]]; then
        selected_code="${1}"
        shift
        selected_calendar="$@"
    fi

    selectAll=0
    # Convert the variable into an array (one option per line)
    IFS=$'\n' read -d '' -ra calendar_array <<< "$calendars"
    # IFS=$'\n' read -d '' -ra calendar_array <<< "$(echo "$calendars" | awk 'NF {print substr($0, index($0, $3))}')"

    if [[ -z ${selected_calendar} && -z ${selected_code} ]]; then
        # Calculate the max number of iterations
        remaining_gca=$(( ${num_lines} - ${num_gca} ))
        [[ $remaining_gca -lt 1 ]] && remaining_gca=1
        for (( remaining=0; remaining<${remaining_gca}; remaining++ )); do
            # Display the menu
            echo "Please select a Google Calendar to import:"
            for i in "${!calendar_array[@]}"; do
                if [[ -n ${calendar_array[i]} && ! "${calendar_array[i]}" =~ ^[[:space:]]*$ ]]; then
                    echo -e " [${yellow}$((i+1))${reset}] ${calendar_array[i]}"
                fi
            done
            [[ $i -ne 0 ]] && echo -e " [${yellow}A${reset}] All calendars above"
            echo -e " [${yellow}X${reset}] Don't ask me again"
            echo

            # Infinite loop until a valid option is chosen
            while true; do
                read -p "Select an option: " choice

                # Check if the choice is a valid integer or "x"
                if [[ "$choice" =~ ^[1-9][0-9]*$ && "$choice" -le "${#calendar_array[@]}" || "${choice^^}" == "A" || "${choice^^}" == "X" ]]; then
                    if [ "${choice^^}" == "X" ]; then
                        jq --argjson gca_skip 1 '.gca_skip = $gca_skip' $SETTINGS > tmp.$$.json && mv tmp.$$.json $SETTINGS && echo "▸▸▸ Selected: Don't ask me again"
                        echo
                        return
                    elif [ "${choice^^}" == "A" ]; then
                        selectAll=1
                        remaining=${remaining_gca} # Prevent importing more calendars
                        echo "▸▸▸ Selected: All calendars"
                        echo
                        break
                    else
                        selected_calendar="${calendar_array[choice-1]}"
                        echo "▸▸▸ Selected: ${selected_calendar}"
                        echo
                        break
                    fi
                else
                    echo "Invalid choice. Please enter a valid option."
                    echo
                fi
            done

            echo "Select a corresponding category:"
            jq -r '.categories | to_entries[] | select(.key != "0") | "\(.key)\t\(.value.name)"' ${SETTINGS} | awk -v yellow="${yellow}" -v reset="${reset}" 'BEGIN{FS="\t"}{printf " [%s%s%s] %s\n", yellow, $1, reset, $2}'
            echo

            # Infinite loop until a valid option is chosen
            while true; do
                read -p "Enter a category code: " choice

                # Check if the choice is a valid category "key"
                if [[ -z ${defaults["categories[${choice}][name]"]} ]]; then
                    echo "Invalid choice. Please enter a valid option."
                    echo
                else
                    selected_code="${choice}"
                    echo "▸▸▸ Selected: ${defaults["categories[${choice}][name]"]}"
                    echo
                    break
                fi
            done

            yes_no "Import another Google Calendar?"
            if [[ $user_input == "yes" ]] ; then
                echo
            else
                break
            fi
        done
    fi

    # Get the events from gcalcli
    if [[ ${selectAll} -ne 1 ]]; then
        events=$(gcalcli --calendar "${selected_calendar}" agenda --tsv "${start_date}" "${end_date}" | awk '{print $1, $2, substr($0, index($0, $5))}')
    else
        events=$(gcalcli agenda --tsv "${start_date}" "${end_date}" | awk '{print $1, $2, substr($0, index($0, $5))}')
    fi

    # Process each line of the events
    echo "$events" | while read -r line; do
        # Extract the date, time, and summary from the line
        date=$(echo $line | awk '{print $1}')
        time=$(echo $line | awk '{print $2}')
        summary=$(echo $line | cut -d' ' -f3-)

        # If the date is not in the correct format, use the previous date
        if [[ ! $date =~ ^[0-9]{4}\-[0-1]{1}[0-9]{1}\-[0-3]{1}[0-9]{1}$ || $date < $today ]]; then
            continue
        else
            date=${date//-//}
        fi

        # Detect birthdays, name days and anniversaries
        shopt -s nocasematch
        if [[ $summary =~ (birthday|name day|anniversary)$ ]]; then
            code=4
        else
            code=$selected_code
        fi
        shopt -u nocasematch

        # Print the formatted event
        if [[ $time == "00:00" ]]; then
            echo "$date $code $summary #gc"
        else
            echo "$date $code $time $summary #gc"
        fi
    done >| ${tempfile}

    # Loop through each line in the tempfile
    while IFS= read -r line; do
        # Extract the date and message, excluding the single digit code
        leading=$(echo "$line" | awk '{print substr($0, 1, 11)}')
        trailing=$(echo "$line" | awk '{print substr($0, 13)}')

        # Sensible cherry picking the insertion of the new events:
        # Check if the same event exists in the input file with any category key
        if ! grep "^${leading}[[:alnum:]]${trailing}$" "$INPUT_FILE" > /dev/null; then
            # Only if the event does not exist, append the line to the temporary output file
            echo "$line" >> "$temp_output"
        fi
    done < "${tempfile}"

    # Check if temp_output has at least one non-empty line
    if [ $(grep -c . "$temp_output") -gt 0 ]; then
        # Append the non-empty lines from temp_output to the input file
        grep . "$temp_output" >> "$INPUT_FILE"
        if [[ ${selectAll} -ne 1 ]]; then
            calendar_name="${selected_calendar}"
            update_gca_json
        else
            # All calendars are inserted under the same category
            for i in "${!calendar_array[@]}"; do
                if [[ -n ${calendar_array[$i]} && ! "${calendar_array[$i]}" =~ ^[[:space:]]*$ ]]; then
                    calendar_name="${calendar_array[$i]}"
                    update_gca_json
                fi
            done
        fi
    fi

    # Remove the temporary output file
    rm "$tempfile"
    rm "$temp_output"
}

gca() {
    # Get all calendars from gcalcli list and strip all ANSI sequences from it
    calendars=$(gcalcli list 2>/dev/null | awk 'NR>2 && NF {print substr($0, index($0, $3))}' | sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g')
    num_lines=$(echo "$calendars" | wc -l)

    # iterate through all end_dates and update the existing calendars only if needed
    # enable a flag for updating calendars
    # enable a flag for deleting calendars
    # remove the Multiple calendars option and save individual entries instead

    # Check if the calendars variable is not empty
    if [[ -n "$calendars" ]]; then
        if [[ -z "$@" ]]; then
            import_gca
        else
            import_gca "$@"
        fi
    fi
}


# Iterate through all outdated imported calendars and run auto update
gca_auto_update() {
    for (( i=0; i<${#outdated_names[@]}; i++ )); do
        j=${outdated_index[$i]}
        gca "${defaults["gca[$j][category]"]}" "${defaults["gca[$j][name]"]}"
    done
}
