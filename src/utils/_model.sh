#!/usr/bin/env bash

# Add a new event
# NOTE: The value is validated then stored in `./.deadline`
set_dcal() {
    local selection
    current_date="${TODAY}"
    next_date=$(date -d "+1 day" "+%Y/%m/%d")
    current_datetime=$(date +%s)

    if [[ ! $deadline =~ ${date_regex} ]]; then
        deadline=$(date -d "+${DEFAULT_DAYS_AHEAD}days" +%Y/%m/%d 2>/dev/null)
    fi

    confirmed_date=${1}
    shift
    confirmed_code=${1}
    shift
    confirmed_desc=${@}

    if [[ -n "$confirmed_code" && ${#confirmed_code} == 1 ]]; then
        code=${confirmed_code}
    elif [[ -n "$confirmed_code" && ${#confirmed_code} > 1 ]]; then
            error "[yyyy/mm/dd] [x] [desc]"
            exit 1
    else
        # INPUT: category
        echo "Please select a category:"
        view_categories
        read -p "Enter a code of the category above [1]: " selection
        if [[ -z "$selection" ]]; then
            code="1"
        elif [[ $selection =~ ^[1-9a-z]$ ]]; then
            # Check if the entered code exists in the categories
            if [[ -n ${defaults["categories[$selection][name]"]} ]]; then
                code="$selection"
            else
                echo "Invalid selection: ${selection}"
                exit 1
            fi
        else
            echo "Invalid selection: ${selection}"
            exit 1
        fi
    fi
    read last_deadline <<< $(get_last_deadline)
    range=${defaults["categories[$code][range]"]}

    # INPUT: start_date, end_date
    if [ -n "$confirmed_date" ]; then
        start_date="${confirmed_date}"
        end_date="${confirmed_date}"
        desc=$confirmed_desc
        force="$ENFORCE"
    else
        if (( range == 1 )); then
            if [ -n "$BASH_VERSION" ]; then
                echo -ne "${MSG['start_date']}"
                read -r -ei "$deadline" -p " [$(echo -e "${yellow}${MSG['date_format']}${reset}")]: " start_date
                echo -ne "${MSG['end_date']}"
                read -r -ei "$start_date" -p " [$(echo -e "${yellow}${MSG['date_format']}${reset}")]: " end_date
            else
                vared -ep "${MSG['start_date_zsh']}" deadline
                start_date=${(q)deadline}
                end_date=${(q)start_date}
                vared -ep "${MSG['end_date_zsh']}" end_date
            fi
            start_date=${start_date:-"$deadline"}
            end_date=${end_date:-"$deadline"}
        else
            if [ -n "$BASH_VERSION" ]; then
                echo -ne "${MSG['new_date']}"
                read -r -ei "$deadline" -p " [$(echo -e "${yellow}${MSG['date_format']}${reset}")]: " start_date
            else
                vared -ep "${MSG['new_date_zsh']}" deadline
                start_date=${(q)deadline}
            fi
            start_date=${start_date:-"$deadline"}
            end_date=$start_date
        fi
    fi

    if [[ $start_date =~ ${date_regex} && $end_date =~ ${date_regex} ]]; then
        # Use the date command once to get the date in seconds and in the locale format
        date_output=$(date -d "$start_date" "+%s ${LOCALE_FMT}" 2>/dev/null)

        # Use parameter expansion to extract the date in seconds and in the locale format
        start_date_sec=${date_output%% *}
        DEADLINE_FMT=${date_output#* }
        if [[ -z "$start_date_sec" ]]; then
            echo -ne "Invalid date format for start date: ${start_date}\n"
            exit 1
        fi

        end_date_sec=$(date -d "$end_date" +%s 2>/dev/null)
        if [[ -z "$end_date_sec" ]]; then
            echo -ne "Invalid date format for end date: ${end_date}\n"
            exit 1
        fi

        if [[ $start_date_sec -gt $end_date_sec ]]; then
            echo "Error: invalid date range."
            exit 1
        fi
    else
        echo -ne "Invalid date format. Please ensure both dates are in the format: yyyy/mm/dd\n"
        exit 1
    fi

    if [[ $force == "$ENFORCE" ]]; then
        DESC=${DESC:-"$desc"}
    else
        if [[ -z $desc ]]; then
            if [ -n "$BASH_VERSION" ]; then
                echo -ne "${MSG['new_desc']}"
                last_deadline=${last_deadline:-"${MSG['default_desc']}"}
                read -r -ei "${desc}" -p " [$(echo -e "${yellow}${last_deadline}${reset}")]: " DESC
            else
                vared -ep "${MSG['new_desc_zsh']}" desc
                DESC="${(q)desc}"
            fi
        fi
        DESC=${DESC:-"${last_deadline}"}
    fi

    if [[ -z ${DESC} ]]; then
        echo "Error: Description is missing"
        exit 1
    fi

    # Store events in a temporary array
    temp_events=()

    for ((date_sec=$start_date_sec; date_sec<=$end_date_sec; date_sec+=86400)); do
        date=$(date -d "@$date_sec" +%Y/%m/%d)
        # Check if event exists in the input file
        while grep -q "$date $code ${DESC}" "$INPUT_FILE" || grep -q "$date . ${DESC}" "$INPUT_FILE"; do
            if grep -q "$date $code ${DESC}" "$INPUT_FILE"; then
                category_name=${defaults["categories[$code][name]"]}
                echo
                echo -e "$category_name: [${yellow}$date${reset}] ${yellow}${DESC}${reset}"
                echo
                echo -en "This event already exists.\nWould you like to enter a different description? [Y/n] "
                read input_yn
                case $input_yn in
                [yY][eE][sS]|[yY]|"")
                    if [ -n "$BASH_VERSION" ]; then
                        echo -ne "${MSG['new_desc']}"
                        last_deadline=${last_deadline:-"${MSG['default_desc']}"}
                        read -r -ei "$desc" -p " [$(echo -e "${yellow}${last_deadline}${reset}")]: " DESC
                    else
                        vared -ep "${MSG['new_desc_zsh']}" desc
                        DESC=${(q)desc}
                    fi
                    if [[ force == "$ENFORCE" ]]; then
                        DESC=${DESC:-"$desc"}
                    else
                        DESC=${DESC:-"$last_deadline"}
                    fi
                    ;;
                *)
                    # interrupt the loop and cancel the operation of insertion
                    echo "Operation cancelled"
                    exit 1
                    ;;
                esac
            else
                echo -en "The same event under a different category already exists.\nWould you like to update its category instead? [Y/n] "
                read input_yn
                case $input_yn in
                [yY][eE][sS]|[yY]|"")
                    # update the status of the event from resolved to pending
                    # start_date_sec=$(date -d "$start_date" +%s)
                    # end_date_sec=$(date -d "$end_date" +%s)
                    # Create an associative array to store the dates in the new range
                    declare -A new_dates
                    for ((date_sec=$start_date_sec; date_sec<=$end_date_sec; date_sec+=86400)); do
                        new_date=$(date -d "@$date_sec" +%Y/%m/%d)
                        new_dates["$new_date"]=1
                    done

                    # Read the file line by line
                    while IFS= read -r line; do
                        read -r -a array <<< "$line"
                        old_date="${array[0]}"
                        old_description="${array[2]}"

                        # Convert old_date to seconds for comparison
                        IFS="/" read -r -a date_parts <<< "$old_date"
                        old_date_sec=$(( (date_parts[0] - 1970) * 31536000 + (date_parts[1] - 1) * 2592000 + (date_parts[2] - 1) * 86400 ))

                        # If a line's date is within the new date range and its description matches $DESC
                        if (( old_date_sec >= start_date_sec && old_date_sec <= end_date_sec )) && [[ "$old_description" == "${DESC}" ]]; then
                            # Change the category code to $code and unset the date in new_dates
                            echo "$old_date $code ${DESC}"
                            unset new_dates["$old_date"]
                        else
                            echo "$line"
                        fi
                    done < "$INPUT_FILE" >| tempfile

                    # Add the remaining dates in new_dates to the file
                    for new_date in "${!new_dates[@]}"; do
                        echo "$new_date $code ${DESC}" >> tempfile
                    done

                    mv tempfile "$INPUT_FILE"
                    echo "Event category updated."
                    return
                    ;;
                *)
                    # cancel the operation
                    echo "Operation cancelled"
                    return
                    ;;
                esac
            fi
        done
        validate_reminder "$date" "$code" "${DESC}"
        if [[ -n $REMINDER_DESC ]]; then
            temp_events+=("$date $code ${REMINDER_DESC}")
            unset $REMINDER_DESC
        else
            temp_events+=("$date $code ${DESC}")
        fi
    done
    # Write all new events to the file
    cleanup_inactive_pids
    printf "%s\n" "${temp_events[@]}" >> "$INPUT_FILE"
    echo $(expr '(' $start_date_sec - $(date +%s) + 86399 ')' / 86400) " days until deadline ($DEADLINE_FMT)"
}


# Sort the INPUT file by dates
# use the grep command to output all deadline dates with corresponding descriptions for the given month
# NOTE: argument 1 format: YYYY/MM
events_in_month() {
    # Output all deadline dates with corresponding descriptions for the given month
    if [[ ${HIDE_PAST_EVENTS} -ne 0 && ${HIDE_FUTURE_EVENTS} -eq 0 && $display_month -ne 1 ]]; then
        # Hide all past events
        awk -v year="$year" -v month="$month_zero" -v today="$day_zero" '
            BEGIN {
                FS="/"
            }
            {
                # Extract the day part from the $3
                day=substr($3, 1, 2)
                if ($1 == year && $2 == month && day >= today) {
                    print
                } else if ($1 > year || ($1 == year && $2 > month)) {
                    exit
                }
            }
' <<< "${sorted_lines}"
    elif [[ ${HIDE_PAST_EVENTS} -ne 0 && ${HIDE_FUTURE_EVENTS} -ne 0 && $display_month -ne 1 ]]; then
        # Show only today's agenda
        awk -v year="$year" -v month="$month_zero" -v today="$day_zero" '
            BEGIN {
                FS="/"
            }
            {
                # Extract the day part from the $3
                day=substr($3, 1, 2)
                if ($1 == year && $2 == month && day == today) {
                    print
                } else if (($1 == year && $2 == month && day > today) || ($1 == year && $2 > month) || $1 > year) {
                    exit
                }
            }
' <<< "${sorted_lines}"
    elif [[ ${HIDE_PAST_EVENTS} -eq 0 && ${HIDE_FUTURE_EVENTS} -ne 0 && $display_month -ne 1 ]]; then
        # Hide all upcoming events
        awk -v year="$year" -v month="$month_zero" -v today="$day_zero" '
            BEGIN {
                FS="/"
            }
            {
                # Extract the day part from the $3
                day=substr($3, 1, 2)
                if ($1 == year && $2 == month && day <= today) {
                    print
                } else if (($1 == year && $2 == month && day > today) || ($1 == year && $2 > month) || $1 > year) {
                    exit
                }
            }
' <<< "${sorted_lines}"
    else
        # Don't hide past events
        grep "^$year/$month_zero" <<<${sorted_lines}
    fi
}


update_line() {
    # Check if the correct number of arguments is provided
    if [ $# -ne 2 ]; then
        echo "Usage: `cmd` <pattern> <new_line>"
        exit 1
    fi

    # Assign the arguments to variables
    if [[ "$1" == *[\^\$]* ]]; then
        pattern="$1"
    else
        pattern="^$1.*$"
    fi
    new_line=$2

    # Find the line matching the pattern
    line=$(grep -v -e '^$' "$INPUT_FILE" | grep "$pattern")

    # Check if more than one line is found
    if [[ ! -z "$line" && $(echo "$line" | wc -l) -gt 1 ]]; then
        echo "Warning: More than one line matches the pattern ${pattern}"
        echo "$line"
        exit 1
    elif [[ -z "$line" ]]; then
        echo "Warning: No line matches the pattern ${pattern}"
        exit 1
    fi

    # Split the new line into three parts
    date_part=$(echo "$new_line" | cut -d " " -f 1)
    code_part=$(echo "$new_line" | cut -d " " -f 2)
    description_part=$(echo "$new_line" | cut -d " " -f 3-)

    # Check if the date is in the correct format
    # if ! [[ $date_part =~ ${date_regex} ]]; then
    if ! new_date=$(date -d "$date_part" +%Y/%m/%d 2>/dev/null); then
        echo "Error: The date is not in the correct format"
        exit 1
    fi

    # Check if the code is a single-digit number
    if (( code_part > 9 )); then
        echo "Error: The code is not a single-digit number"
        exit 1
    fi

    # Check if the description is not empty
    if [ -z "$description_part" ]; then
        echo "Error: The description is empty"
        exit 1
    fi

    # Replace the line with the new line
    # sed -i "s#$pattern#$new_date $code_part $description_part#" ${INPUT_FILE} && sort -k1.1,1.10 ${INPUT_FILE} -o ${INPUT_FILE}
    set +o noclobber
    awk -v pattern="$pattern" -v new="$new_date $code_part $description_part" 'BEGIN{FS=OFS=" "} $0 ~ pattern {$0=new} 1' ${INPUT_FILE} >| tmpfile
    if [[ -s tmpfile ]]; then
        mv tmpfile ${INPUT_FILE}
    else
        echo "No lines matching the pattern found."
    fi
    set -o noclobber

    echo "$new_date $code_part $description_part"
    echo "Line updated successfully"
}


# Get all entries prior to start_timestamp - seconds_in_months
expired_lines() {
    # Calculate the cutoff date
    cutoff_date=$(date -d"@$((start_timestamp - seconds_in_months))" +'%Y/%m/%d')
    lines=""

    while IFS= read -r line; do
        # Extract the date from the line
        line_date=${line:0:10}

        # If the line date is earlier than the cutoff date, add the line to lines
        if [[ "$line_date" < "$cutoff_date" ]]; then
            lines+=$'\n'$line
        fi
    done < ${INPUT_FILE}

    # Remove leading newlines
    lines="${lines#"${lines%%[!$'\n']*}"}"
    # Remove trailing newlines
    lines="${lines%"${lines##*[!$'\n']}"}"
}


delete_line() {
    # Check if the correct number of arguments is provided
    if [ $# -ne 1 ]; then
        echo "Usage: `cmd` <pattern>"
        exit 1
    fi

    # Assign the argument to a variable
    pattern=$1

    # Find the lines matching the pattern
    if [[ $pattern == "$ENFORCE" ]]; then
        expired_lines
    else
        lines=$(grep -ve '^[[:space:]]*$' "${INPUT_FILE}" | grep "$pattern")
        # lines=$(grep "$pattern" ${INPUT_FILE})
    fi

    # Check if no lines are found
    if [ -z "$lines" ]; then
        echo "No lines found for deletion"
        exit 1
    fi

    # Print the lines matching the pattern
    echo "$lines"
    echo

    local lines_to_delete=$(echo "$lines" | wc -l)
    # Check if more than one line is found
    if [[ $lines_to_delete -gt 1 ]]; then
        echo -e "There are ${alert}$lines_to_delete${reset} entries found for deletion."
    fi

    # Ask the user if they want to delete the lines
    read -p "Are you sure you want to delete the above line(s)? (y/n) " answer

    # Delete the lines if the user answers yes
    if [ "$answer" = "y" ]; then
        set +o noclobber
        if [[ $pattern == "$ENFORCE" ]]; then
            # Create a temporary file
            tmpfile=$(mktemp)
            # Iterate over each line in the input file
            while IFS= read -r line; do
                # If the line is not in the lines to be deleted, write it to the temporary file
                if ! echo "$lines" | grep -Fxq "$line"; then
                    echo "$line" >> "$tmpfile"
                fi
            done < ${INPUT_FILE}
            # Replace the input file with the temporary file
            mv "$tmpfile" ${INPUT_FILE}
        else
            # Delete the line(s) that match a given pattern
            awk -v pattern="$pattern" 'BEGIN{FS=OFS=" "} $0 !~ pattern' ${INPUT_FILE} >| tmpfile
            if [[ -s tmpfile ]]; then
                mv tmpfile ${INPUT_FILE}
            else
                echo "All lines match the pattern."
                if [[ -e tmpfile ]]; then
                    rm tmpfile
                fi
            fi
        fi
        set -o noclobber
        echo "Line(s) deleted successfully"
        return 0
    else
        echo "Operation cancelled"
        return 1
    fi
}


scheduled_cleanup() {
    # Update the last execution date for this use case
    jq --argjson date "$start_timestamp" '.scheduled_cleanup = $date' $SETTINGS > tmp.$$.json && mv tmp.$$.json $SETTINGS

    while true; do
        echo
        echo -e "${alert}This will delete all events that are older than ${DEFAULT_CLEANUP_FREQUENCY} months.${reset}"
        echo -en "Would you like to perform automatic cleanup? [Y/n] "
        read input_yn
        case $input_yn in
            [yY][eE][sS]|[yY]|"")
                # Call your function
                echo
                delete_line "$ENFORCE"
                break
                ;;
            *)
                echo "Ok, you could always clean it manually."
                break
                ;;
        esac
    done
}


export_to_tsv() {
    # Check if the required input files exist
    if [[ ! -f $INPUT_FILE ]] || [[ ! -f $SETTINGS ]]; then
        echo "Error: Missing input file(s)."
        echo
        return 1
    fi

    # Process the input file line by line
    while IFS=' ' read -r date key desc; do
        # Add the category name as the fourth column
        echo -e "$date\t$key\t$desc\t"${defaults["categories[$key][name]"]}
    done < $INPUT_FILE >| $TSV_FILE

    # Get the current date
    todays_date=$(date +"%Y/%m/%d")

    # Add the export date as an extended attribute to the TSV file
    setfattr -n user.export_date -v "Export date: $todays_date" ${TSV_FILE}

    # Open the TSV file
    xdg-open ${TSV_FILE} > /dev/null 2>&1
}


import_from_tsv() {
  # Check if the required input files exist
  if [[ ! -f $TSV_FILE ]]; then
    echo "Error: The TSV file does not exist. Proceeding with export as a required step prior to this action..."
    echo
    export_to_tsv
    return 1
  fi

  # Print the last export data on screen
  getfattr -n user.export_date ${TSV_FILE} 2>/dev/null | cut -d '"' -f 2

  echo "Select an option:"
  echo -e " [${yellow}1${reset}] Overwrite"
  echo -e " [${yellow}2${reset}] Append new values"
  echo -e " [${yellow}3${reset}] Cancel"
  echo
  read -p "Enter your choice [1]: " choice

  # Validate the data in the TSV file
  while IFS=$'\t' read -r date key desc category_name; do
    if [[ ! $date =~ ${date_regex} ]] || [[ ${#key} -ne 1 ]] || [[ -z $desc ]]; then
      echo "Error: Invalid data in the TSV file:"
      echo -e "${date}\t${key}\t${desc}"
      return 1
    fi
  done < $TSV_FILE

  case ${choice:-1} in
    1)
      # Ask the user if they want to overwrite the existing content
      read -p "Are you sure you want to overwrite your existing events? (Y/n): " answer
      case ${answer:-y} in
        [yY][eE][sS]|[yY]|"")
          # Overwrite the existing content
          while IFS=$'\t' read -r date key desc category_name; do
            # Trim leading and trailing spaces in the description
            desc=$(echo "$desc" | sed 's/^ *//;s/ *$//')
            echo -e "${date} ${key} ${desc}"
          done < ${TSV_FILE} >| ${INPUT_FILE}
          ;;
        *)
          echo "Ok, no worries."
          return 0
          ;;
      esac
      ;;
    2)
      # Append values to the end of the input file
      while IFS=$'\t' read -r date key desc category_name; do
        # Trim leading and trailing spaces in the description
        desc=$(echo "$desc" | sed 's/^ *//;s/ *$//')
        echo -e "${date} ${key} ${desc}"
      done < ${TSV_FILE} >> ${INPUT_FILE}
      ;;
    *)
      echo "Operation cancelled"
      return 0
      ;;
  esac

  echo "The process has been completed. The '${INPUT_FILE}' has been updated."
}


sanitize() {
    # Replace spaces with underscores
    local CLEAN=${1// /_}
    # Clean out anything that's not alphanumeric or an underscore
    CLEAN=${CLEAN//[^a-zA-Z0-9_]/}
    # Remove trailing underscores
    CLEAN=$(echo "$CLEAN" | sed 's/_*$//')
    # Lowercase with TR
    echo -n $CLEAN | tr A-Z a-z
}


# Print available files
file_options() {
    maxsize=1
    i=1
    get_files

    while read -r line; do
        size=$(echo ${line} | awk '{print $1}')
        [[ ${maxsize} -lt ${#size} ]] && maxsize=${#size}
    done< <(echo "${data}" | awk '{printf "%s\n", $6}')

    while read -r line; do
        size=$(echo ${line} | awk '{print $1}')
        date=$(echo ${line} | awk '{print $2}')
        time=$(echo ${line} | awk '{print $3}')
        prefix=$(echo ${line} | awk '{print $4}')

        printf -v size "%*s" $maxsize "$size"
        if [[ -f "${SCRIPTPATH}/${DATA}/${default_filename}" && -w "${SCRIPTPATH}/${DATA}/${default_filename}" && ${prefix^^} == "DEFAULT" ]]; then
            echo -e " [${green}${i}${reset}] ${size} ${date} ${time} ${green}${prefix}${reset}"
            tags+=("${prefix}")
        elif [[ -f "${SCRIPTPATH}/${DATA}/${prefix}_${default_filename}" && -w "${SCRIPTPATH}/${DATA}/${prefix}_${default_filename}" ]]; then
            echo -e " [${green}${i}${reset}] ${size} ${date} ${time} ${green}${prefix}${reset}"
            tags+=("${prefix}")
        fi
        (( i++ ))
    done< <(echo "${data}" | awk '{printf "%s %s %s %s\n", $1, $2, $3, $4}')
    echo
}


new_file() {
    # Delete a file
    sanitized=""
    if [[ ${new} -ne 1 ]]; then
        echo "Available files:"
        file_options
        if [[ ${#tags[@]} -eq 0 ]]; then
            echo "No files."
            echo
        fi
    fi
    prefix=""
    echo -e "  Sample filename: ${yellow}prefix${reset}_${default_filename}"
    echo
    while [[ ! $FILE =~ ^[A-Za-z0-9_]+$ ]] || [[ " ${tags[@]} " =~ " ${sanitized} " ]]; do
        read -p "Enter a prefix for the new file [a-z0-9_]: " FILE
        sanitized="$(sanitize "${FILE}")"
    done
    sanitized+="_"
    if [[ "${prefix}" != "${sanitized}" ]]; then
        touch "${SCRIPTPATH}/${DATA}/${sanitized}${default_filename}"
        touch "${SCRIPTPATH}/${DATA}/${sanitized}${default_log}"
        echo "New file created: '${sanitized}${default_filename}'."
    fi
}


view_file() {
    # Delete a file
    echo "Available files:"
    file_options
    prefix=""
    if [[ ${#tags[@]} -eq 0 ]]; then
        new=1
        echo "Nothing to view, create a new file instead."
        echo
        new_file
        return
    fi
    opt=$(( ${#tags[@]} ))
    while [[ ! $FILE =~ ^[1-${opt}]$ ]]; do
        read -p "Choose a file to view [1-${opt}]: " FILE
    done
    (( FILE-- ))
    if [[ "${tags[$FILE]^^}" != "DEFAULT" ]]; then
        prefix="${tags[$FILE]}_"
    fi

    # Define options
    options=("View with bat/cat" "View with fzf" "View with less/more" "Copy path to clipboard" "Back")

    custom_select

    # Process user's choice
    case $REPLY in
        1)
            # Check if bat is installed
            if command -v bat >/dev/null 2>&1; then
                echo "Opening file '${prefix}${default_filename}' with bat..."
                bat "${SCRIPTPATH}/${DATA}/${prefix}${default_filename}"
            else
                echo "Opening file '${prefix}${default_filename}' with cat..."
                cat "${SCRIPTPATH}/${DATA}/${prefix}${default_filename}"
            fi
            ;;
        2)
            # Check if bat is installed
            if command -v fzf >/dev/null 2>&1; then
                echo "Opening file '${prefix}${default_filename}' with fzf..."
                cat "${SCRIPTPATH}/${DATA}/${prefix}${default_filename}" | fzf
            else
                echo "Error: 'fzf' is not installed"
            fi
            ;;
        3)
            # Check if bat is installed
            if command -v less >/dev/null 2>&1; then
                echo "Opening file '${prefix}${default_filename}' with less..."
                less "${SCRIPTPATH}/${DATA}/${prefix}${default_filename}"
            else
                echo "Opening file '${prefix}${default_filename}' with more..."
                more "${SCRIPTPATH}/${DATA}/${prefix}${default_filename}"
            fi
            ;;
        4)
            echo -n "${SCRIPTPATH}/${DATA}/${prefix}${default_filename}" | xclip -selection clipboard
            echo "Full file path copied to clipboard."
            echo
            return
            ;;
        5)
            return
            ;;
    esac
    echo "File closed."
}


select_file() {
    # Select a file
    unset REPLY
    echo "Available files:"
    file_options
    prefix=""
    if [[ ${#tags[@]} -eq 0 ]]; then
        new=1
        echo "Nothing to select, let's create a new file instead."
        echo
        new_file
        echo
        echo "Available files:"
        file_options
    fi
    opt=$(( ${#tags[@]} ))
    if [[ ${opt} -gt 1 ]]; then
        while [[ ! $REPLY =~ ^[1-${opt}]$ ]]; do
            read -p "Choose a file to be selected [1-${opt}]: " REPLY
        done
        (( REPLY-- ))
        if [[ "${tags[$REPLY]^^}" != "DEFAULT" ]]; then
            prefix="${tags[$REPLY]}_"
        fi
        if [[ -n $REPLY ]]; then
            yes_no "Select the file '${prefix}${default_filename}'?"
        fi
    else
        [[ -n "${tags[0]}" && "${tags[0]}" != "DEFAULT" ]] && prefix="${tags[0]}_" || prefix=""
        user_input="yes"
    fi
    if [[ $user_input == "yes" ]]; then
        jq --arg file "${prefix}${default_filename}" '.active_file = $file' ${DEFAULT_SETTINGS} > tmp.$$.json && mv tmp.$$.json ${DEFAULT_SETTINGS}
        defaults["active_file"]="${prefix}${default_filename}"
        INPUT_FILE="${SCRIPTPATH}/${DATA}/${prefix}${default_filename}"
        SETTINGS="${SCRIPTPATH}/${DATA}/${prefix}${default_log}"
        TSV_FILE="${SCRIPTPATH}/${DATA}/${prefix}${default_tsv}"
        touch ${SETTINGS}
        echo "New file selected."
    else
        echo "No action taken, the previous selection remains intact."
    fi
}


edit_file() {
    # Delete a file
    echo "Available files:"
    file_options
    prefix=""
    if [[ ${#tags[@]} -eq 0 ]]; then
        new=1
        echo "Nothing to edit, create a new file instead."
        echo
        new_file
        echo
        echo "Available files:"
        file_options
    fi
    opt=$(( ${#tags[@]} ))
    while [[ ! $FILE =~ ^[1-${opt}]$ ]]; do
        read -p "Choose a file to be edited [1-${opt}]: " FILE
    done
    (( FILE-- ))
    if [[ "${tags[$FILE]^^}" != "DEFAULT" ]]; then
        prefix="${tags[$FILE]}_"
    fi

    # Define options
    options=("Open in terminal" "Open in GUI" "Back")

    custom_select

    echo "Opening file '${prefix}${default_filename}'..."
    # Process user's choice
    case $REPLY in
        1)
            # Check if the EDITOR variable is set
            if [[ -z "$EDITOR" ]]; then
                echo "The EDITOR environment variable is not set. Please set it to your preferred text editor."
                echo
                return
            fi
            $EDITOR "${SCRIPTPATH}/${DATA}/${prefix}${default_filename}"
            ;;
        2)
            xdg-open "${SCRIPTPATH}/${DATA}/${prefix}${default_filename}"
            ;;
        3)
            return
            ;;
    esac
}


rename_file() {
    # Delete a file
    sanitized=""
    echo "Available files:"
    file_options
    prefix=""
    if [[ ${#tags[@]} -eq 0 ]] || [[ ${#tags[@]} -eq 1 && " ${tags[@]} " =~ " DEFAULT " ]]; then
        new=1
        echo "Nothing to rename, create a new file instead."
        echo
        new_file
        return
    fi
    opt=$(( ${#tags[@]} ))
    while [[ ! $REPLY =~ ^[1-${opt}]$ ]]; do
        read -p "Choose a file to be renamed [1-${opt}]: " REPLY
    done
    (( REPLY-- ))
    if [[ "${tags[$REPLY]^^}" != "DEFAULT" ]]; then
        prefix="${tags[$REPLY]}_"
    fi
    if [[ -n $REPLY ]]; then
        yes_no "Are you sure to rename the file '${prefix}${default_filename}'?"
    fi
    if [[ $user_input == "yes" ]]; then
        echo
        if [[ "${prefix}" != "" ]]; then
            prefix_nd="${prefix:0:-1}"
            echo -e "  Current filename: ${yellow}${prefix_nd}${reset}_${default_filename}"
        else
            echo -e "  Old filename: ${default_filename}"
            echo -e "  New filename: ${yellow}prefix${reset}_${default_filename}"
        fi
        echo
        while [[ ! $FILE =~ ^[A-Za-z0-9_]+$ ]] || [[ " ${tags[@]} " =~ " ${sanitized} " ]]; do
            read -p "Enter a new prefix to the old file name [a-z0-9_]: " FILE
            sanitized="$(sanitize "${FILE}")"
        done
        sanitized+="_"
        if [[ "${prefix}" != "${sanitized}" ]]; then
            mv "${SCRIPTPATH}/${DATA}/${prefix}${default_filename}" "${SCRIPTPATH}/${DATA}/${sanitized}${default_filename}"
            NEW_SETTINGS="${SCRIPTPATH}/${DATA}/${sanitized}${default_log}"
            NEW_TSV_FILE="${SCRIPTPATH}/${DATA}/${sanitized}${default_tsv}"
            # Check if the SETTINGS is empty then initialize it
            if [[ -e "${SCRIPTPATH}/${DATA}/${prefix}${default_log}" ]]; then
                mv "${SCRIPTPATH}/${DATA}/${prefix}${default_log}" "${NEW_SETTINGS}"
            else
                touch ${NEW_SETTINGS}
            fi
            SETTINGS="${NEW_SETTINGS}"
            # Check if the TSV_FILE is empty then initialize it
            if [[ -e "${SCRIPTPATH}/${DATA}/${prefix}${default_tsv}" ]]; then
                mv "${SCRIPTPATH}/${DATA}/${prefix}${default_tsv}" "${NEW_TSV_FILE}"
            fi
            TSV_FILE="${NEW_TSV_FILE}"
            echo "File renamed to '${sanitized}${default_filename}'."
        else
            echo "You entered the same prefix."
        fi
    else
        echo "No action taken, the file remains intact."
    fi
}


delete_file() {
    # Delete a file
    no_active_file=0
    echo "Available files:"
    file_options
    prefix=""
    if [[ ${#tags[@]} -eq 0 ]]; then
        new=1
        echo "Nothing to delete, create a new file instead."
        echo
        new_file
        return
    fi
    opt=$(( ${#tags[@]} ))
    while [[ ! $REPLY =~ ^[1-${opt}]$ ]]; do
        read -p "Choose a file to be deleted [1-${opt}]: " REPLY
    done
    (( REPLY-- ))
    if [[ "${tags[$REPLY]^^}" != "DEFAULT" ]]; then
        prefix="${tags[$REPLY]}_"
    fi
    if [[ -n $REPLY && "${prefix}${default_filename}" == "${defaults["active_file"]}" ]]; then
        yes_no "WARNING: Are you sure to delete currently active file '${prefix}${default_filename}'?"
        if [[ $user_input == "yes" ]]; then
            no_active_file=1
        fi
    elif [[ -n $REPLY && "${prefix}${default_filename}" != "${defaults["active_file"]}" ]]; then
        yes_no "Are you sure to delete the file '${prefix}${default_filename}'?"
    fi
    if [[ $user_input == "yes" ]]; then
        rm "${SCRIPTPATH}/${DATA}/${prefix}${default_filename}"
        # Delete if the SETTINGS exists
        if [[ -e "${SCRIPTPATH}/${DATA}/${prefix}${default_log}" ]]; then
            rm "${SCRIPTPATH}/${DATA}/${prefix}${default_log}"
        fi
        # Delete if the TSV_FILE exists
        if [[ -e "${SCRIPTPATH}/${DATA}/${prefix}${default_tsv}" ]]; then
            rm "${SCRIPTPATH}/${DATA}/${prefix}${default_tsv}"
        fi
        echo "File deleted."
    else
        echo "No action taken, the file remains intact."
    fi
    if [[ $user_input == "yes" && $no_active_file -eq 1 ]]; then
        echo
        select_file
    fi
}


# Custom select function
custom_select() {
    echo -e "\nAvailable actions: "
    for i in "${!options[@]}"; do
        echo -e " [${yellow}$((i+1))${reset}] ${options[$i]}"
    done

    echo
    opt=${#options[@]}
    while [[ ! $REPLY =~ ^[1-${opt}]$ ]]; do
        read -p "Enter choice [1-${opt}]: " REPLY
    done
}


get_files() {
    default_f=$(echo "$([[ -f ${SCRIPTPATH}/${DATA}/${default_filename} && -w ${SCRIPTPATH}/${DATA}/${default_filename} ]] && ls -lih --time-style="+%Y-%m-%d %X" ${SCRIPTPATH}/${DATA}/${default_filename} 2>/dev/null | awk '{print $6, $7, $8}') DEFAULT")
    data="${default_f}"
    for file in "${SCRIPTPATH}/${DATA}/"*_${default_filename}; do
        if [[ -w "$file" ]] && [[ "$file" != "${SCRIPTPATH}/${DATA}/${default_filename}" ]]; then
            info=$(ls -lih --time-style="+%Y-%m-%d %X" "$file" | awk '{print $6, $7, $8}')
            prefix=$(basename "$file" | awk -v filename="_${default_filename}" '{n = split($0,a,filename); printf "%s", a[1]; for (i = 2; i < n; i++) printf "_%s", a[i]}')
            data+=$'\n'"${info} ${prefix}"
        fi
    done
}


# Main menu
base() {
    declare -a tags=()
    local selected
    new=0
    echo

    while :
    do
        unset REPLY FILE
        tags=()
        get_files
        # Process each line of the data
        if [[ -z ${data} ]]; then
            new=1
            echo "No files found, let's create one."
            echo
            new_file
        else
            if [[ "${defaults["active_file"]}" == "${default_filename}" ]]; then
                selected="DEFAULT"
            elif [[ "${defaults["active_file"]}" == "" ]]; then
                selected=""
            else
                selected="${defaults["active_file"]%_$default_filename}"
            fi
            echo "${data}" | awk -v green="${green}" -v reset="${reset}" -v bullet="${bullet_personal}" -v var="${selected}" '{if ($4 == var) selected=bullet; else selected=" "; printf "%6s %s %s %s %s\n", $1, $2, $3, selected, green $4 reset}'
        fi

        # Define options
        options=("Create New" "View" "Edit" "Select" "Rename" "Delete" "Import from TSV" "Export to TSV" "Quit")

        # Call the function
        custom_select

        # Process user's choice
        case $REPLY in
            1)
                echo "▸▸▸ Selected: ${options[0]}"
                echo
                new_file
                ;;
            2)
                echo "▸▸▸ Selected: ${options[1]}"
                echo
                view_file
                ;;
            3)
                echo "▸▸▸ Selected: ${options[2]}"
                echo
                edit_file
                ;;
            4)
                echo "▸▸▸ Selected: ${options[3]}"
                echo
                select_file
                ;;
            5)
                echo "▸▸▸ Selected: ${options[4]}"
                echo
                rename_file
                ;;
            6)
                echo "▸▸▸ Selected: ${options[5]}"
                echo
                delete_file
                ;;
            7)
                echo "▸▸▸ Selected: ${options[6]}"
                echo
                import_from_tsv
                ;;
            8)
                echo "▸▸▸ Selected: ${options[7]}"
                export_to_tsv
                ;;
            9)
                echo "Bye."
                echo
                exit
                ;;
        esac
        print_report_line
        echo
    done
}
