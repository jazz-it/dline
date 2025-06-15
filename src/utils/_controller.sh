#!/usr/bin/env bash

# Function to replace spaces outside ANSI codes
replace_spaces() {
    local original_string="$1"
    local injection_string="$2"
    echo "$original_string" | awk -v inject="$injection_string" 'BEGIN{RS="\\\\033\\\\\\\\[0m "; ORS="\\\\033\\\\\\\\[0m"inject}{print $0}' | head -c -${#injection_string}
}


trunc_desc() {
    if (( ${#1} > MAX_LINE_LENGTH-length )); then
        desc_truncated="${1:0:(( MAX_LINE_LENGTH - length ))}…"
    else
        desc_truncated=${description}
    fi
}


tiny_text() {
    local input="$1"
    local -A map=(
        ['a']='ᵃ' ['b']='ᵇ' ['c']='ᶜ' ['d']='ᵈ' ['e']='ᵉ'
        ['f']='ᶠ' ['g']='ᵍ' ['h']='ʰ' ['i']='ⁱ' ['j']='ʲ'
        ['k']='ᵏ' ['l']='ˡ' ['m']='ᵐ' ['n']='ⁿ' ['o']='ᵒ'
        ['p']='ᵖ' ['q']='q' ['r']='ʳ' ['s']='ˢ' ['t']='ᵗ'
        ['u']='ᵘ' ['v']='ᵛ' ['w']='ʷ' ['x']='ˣ' ['y']='ʸ'
        ['z']='ᶻ' ['A']='ᴬ' ['B']='ᴮ' ['C']='ᶜ' ['D']='ᴰ'
        ['E']='ᴱ' ['F']='ᶠ' ['G']='ᴳ' ['H']='ᴴ' ['I']='ᴵ'
        ['J']='ᴶ' ['K']='ᴷ' ['L']='ᴸ' ['M']='ᴹ' ['N']='ᴺ'
        ['O']='ᴼ' ['P']='ᴾ' ['Q']='Q' ['R']='ᴿ' ['S']='ˢ'
        ['T']='ᵀ' ['U']='ᵁ' ['V']='ⱽ' ['W']='ᵂ' ['X']='ˣ'
        ['Y']='ʸ' ['Z']='ᶻ' ['0']='⁰' ['1']='¹' ['2']='²'
        ['3']='³' ['4']='⁴' ['5']='⁵' ['6']='⁶' ['7']='⁷'
        ['8']='⁸' ['9']='⁹' ['(']='⁽' [')']='⁾' ['-']='⁻'
        ['+']='⁺'
    )
    output=""
    for (( i=0; i<${#input}; i++ )); do
        char="${input:$i:1}"
        output+="${map[$char]:-$char}"
    done
    echo "$output"
}


# Merge foreground and a background ANSI color codes for the weekends
get_bg_color() {
    # Set fg_color
    local fg_color=${color_weekends:-"\033[38;5;233m"}
    local color_code=$1
    # Remove the trailing 'm' and leading '\033[' from fg_color
    local fg_color_code=$(echo $fg_color | sed -e 's/m$//' -e 's/^\\033\[//')
    local bg_color=$(echo $color_code | grep -oP '(?<=48;5;)\d+')

    if [[ -n $bg_color ]]; then
        echo -e "\033[${fg_color_code};48;5;${bg_color}m"
    else
        bg_color=$(echo $color_code | grep -oP '(?<=4)\d')
        if [[ -n $bg_color ]]; then
            case $bg_color in
                0) bg_color=16 ;; # Black
                1) bg_color=124 ;; # Red
                2) bg_color=22 ;; # Green
                3) bg_color=94 ;; # Yellow
                4) bg_color=18 ;; # Blue
                5) bg_color=54 ;; # Magenta
                6) bg_color=30 ;; # Cyan
                7) bg_color=15 ;; # White
            esac
            echo "\033[${fg_color_code};48;5;${bg_color}m"
        fi
    fi
}


# Toggle the visibility of a certain category in calendar details
toggle_show() {
    # If the array is not empty
    if [[ -n ${1} ]]; then
        # Iterate over each key in the array
        for key in "$@"; do
            if [[ -n ${defaults["categories[$key][name]"]} ]]; then
                local show="${defaults["categories[$key][show]"]}"
                local name="${defaults["categories[$key][name]"]}"
            else
                echo "Error: Category '$key' not found."
                continue
            fi

            local new_show=$((1 - $show))
            jq ".categories.\"$key\".show = $new_show" $SETTINGS > tmp.$$.json && mv tmp.$$.json $SETTINGS
            local notice=$(if [[ $new_show -eq 1 ]]; then echo "VISIBLE"; else echo "HIDDEN"; fi)
            echo "Category '$name' is now $notice in a detailed view."
        done
    fi
    echo "Current visibility of all categories:"
    jq -r '.categories | to_entries[] | "\(.key): \(.value.name)\t\(.value.show)"' $SETTINGS | sed "s/1$/ON/g" | sed 's/0$/OFF/g' | column -t -s $'\t' | sed 's/^/ /'
}


# Toggle the visibility of calendar details
toggle_school() {
    local work_day="WORK DAY"
    local holiday="HOLIDAY"
    local school_category_name=${defaults["categories[8][name]"]}
    if [[ -n $1 && $1 -eq 0 ]]; then
        local new_school=0
        local notice=${work_day}
    elif [[ $1 -eq 1 ]]; then
        local new_school=1
        local notice=${holiday}
    else
        local new_school=${defaults["school"]}
        local notice=$(if [[ $new_school -eq 1 ]]; then echo "${holiday}"; else echo "${work_day}"; fi)
    fi
    if [[ -n $1 ]]; then
        jq --argjson new_school $new_school '.school = $new_school' $SETTINGS > tmp.$$.json && mv tmp.$$.json $SETTINGS
    fi
    echo "'${school_category_name}' is currently set as a ${notice} period."
}


# Toggle the visibility of calendar details
toggle_legend() {
    if [[ -z $legend || $legend -eq 0 ]]; then
        local new_legend=1
        local notice="ON"
    else
        local new_legend=0
        local notice="OFF"
    fi
    jq --argjson new_legend $new_legend '.legend = $new_legend' $SETTINGS > tmp.$$.json && mv tmp.$$.json $SETTINGS && echo "Print legend: $notice"
}


# Toggle the visibility of calendar details
toggle_print_details() {
    if [[ -z $verbose || $verbose -eq 0 ]]; then
        local new_verbose=1
        local notice="ON"
    else
        local new_verbose=0
        local notice="OFF"
    fi
    jq --argjson new_verbose $new_verbose '.verbose = $new_verbose' $SETTINGS > tmp.$$.json && mv tmp.$$.json $SETTINGS && echo "Print details: $notice"
}


get_value() {
    local key=$1
    local attr1=$2
    local attr2=$3

    if [[ -n $attr1 ]]; then
        key="${key}[$attr1]"
    fi

    if [[ -n $attr2 ]]; then
        key="${key}[$attr2]"
    fi

    echo "${defaults[$key]}"
}


parse_json() {
    local json=$(jq -r '.' "${SETTINGS}")

    i=0
    while IFS="=" read -r key value; do
        for attr in name color bullet range show; do
            defaults["categories[$key][$attr]"]=$(echo "$value" | jq -r ".$attr")
        done
        ((i++))
    done < <(echo "$json" | jq -r '.categories | to_entries[] | "\(.key)=\(.value)"')
    num_categories=${i}

    i=0
    while IFS="=" read -r key value; do
        for attr in pid time_created time_scheduled name; do
            defaults["reminders[$i][$attr]"]=$(echo "$value" | jq -r ".$attr")
        done
        ((i++))
    done < <(echo "$json" | jq -r '.reminders | to_entries[] | "\(.key)=\(.value)"')
    num_reminders=${i}

    i=0
    while IFS="=" read -r key value; do
        for attr in name imported_date end_date category; do
            defaults["gca[$i][$attr]"]=$(echo "$value" | jq -r ".$attr")
        done
        ((i++))
    done < <(echo "$json" | jq -r '.gca | to_entries[] | "\(.key)=\(.value)"')
    num_gca=${i}

    for attr in verbose legend school scheduled_cleanup oha_imported oha_country_iso oha_language_iso oha_subdivision_iso gca_skip process_overdues; do
        defaults["$attr"]=$(echo "$json" | jq -r ".$attr")
    done
}


assign_categories() {
    if [[ -z $categories ]]; then
        categories=$(jq -r '.categories' $SETTINGS)
    fi

    # Parse the JSON data into the associative array
    while IFS="=" read -r key value; do
        for attr in name color bullet range show; do
            # Prepend 'k' to the key to avoid issues with leading zeros
            JSON_array["k${key}_${attr}"]=$(echo $value | jq -r .${attr})
        done
    done < <(echo "$categories" | jq -r 'to_entries[] | "\(.key)=\(.value)"')
}


# Function to validate date
validate_date() {
    if [[ $1 =~ $date_regex ]]; then
        IFS="/" read -r year month day <<< "$1"
        # Remove leading zeros
        month=$((10#$month))
        day=$((10#$day))
        # Yes, I plan this script will be THAT popular!
        if ((year >= 2020 && year <= 2499 && month >= 1 && month <= 12 && day >= 1 && day <= 31)); then
            return 0
        fi
    fi
    return 1
}


add_thousand_separators() {
    # Convert the number to a string with thousand separators
    echo "$(printf "%'.f\n" "${1}")"
}


# Function to remove ANSI escape codes
strip_escape_codes() {
    echo -e "$1" | sed 's/\x1b\[[0-9;]*m//g'
}


# Function to calculate the length of the longest string in an array
max_length() {
    local array=("$@")
    local max=-1
    for item in "${array[@]}"; do
        item_length=$(strip_escape_codes "$item" | wc -m)
        if ((item_length > max)); then
            max=$item_length
        fi
    done
    echo $max
}


# Function to generate a string of spaces
spaces() {
    for ((i=0; i<$1; i++)); do
        echo -n " "
    done
}


count_group_events() {
    # Validate start and end dates
    local custom_range
    if [[ -n ${1} && -n ${2} ]]; then
        if validate_date "${1}" && validate_date "${2}"; then
            start_date=${1}
            end_date_input=${2}
            year=${start_date:0:4}
            month=${start_date:5:2}
            day=${start_date:8:2}
            custom_range=1
        else
            echo "Invalid date format. Please use 'YYYY/MM/DD'."
            exit 1
        fi
    else
        echo "No input attributes provided. Please use 'YYYY/MM/DD'."
        exit 1
    fi
    local last_month
    local today_date
    local year_month_ago
    local prev_year
    local prev_month
    local prev_day

    weekdays_with_events=0
    weekends_with_events=0

    # Initialize the count of non-working days
    non_working_days=0
    # Initialize the count of working days
    working_days=0
    local next_year=$(( year + 1 ))

    # Sort the file and save the sorted lines in a variable
    sorted_lines=$(sort ${INPUT_FILE} | awk -v start="${start_date}" -v end="${end_date_input}" '
    BEGIN { FS = "/" }
    { 
        # Convert the date parts to numbers for comparison
        year = sprintf("%04d", $1)
        month = sprintf("%02d", $2)
        day = sprintf("%02d", $3)
        date = year "/" month "/" day

        # Compare the date with the start and end dates
        if (date >= start && date <= end) {
            print
        }
    }')

    # Handle ${INPUT_FILE} data unless it was empty
    if [ -n "${sorted_lines}" ]; then
        # Iterate over the lines in the file
        while IFS= read -r line; do
            # Extract the date, status, and description from the line
            local d_date=${line:0:10}
            status=${line:11:1}
            description=${line:13}

            # Extract the year, month, and day from the date
            local d_year=${d_date:0:4}
            local d_month=$((10#${d_date:5:2}))
            local d_day=$((10#${d_date:8:2}))

            # Initialize month_zeller and year_zeller
            local month_zeller=$d_month
            local year_zeller=$d_year

            # Adjust the month and year for Zeller's Congruence
            if (( d_month < 3 )); then
                month_zeller=$((d_month + 12))
                year_zeller=$((d_year - 1))
            fi

            # Calculate the day of the week (6 for Saturday, 7 for Sunday)
            day_of_week=$(( (d_day + 2*month_zeller + 3*(month_zeller + 1)/5 + year_zeller + year_zeller/4 - year_zeller/100 + year_zeller/400) % 7 + 1 ))

            if [[ $day_of_week -lt 6 ]]; then
                # Group Work day events
                # echo "$line : $day_of_week : On"
                if [[ "$d_date" < "$year/$month/$day" ]]; then
                    continue
                fi
                report_workday["$status"]=$(( ${report_workday[$status]:-0}+1 ))
                if [[ "${d_year}${d_month}${d_day}" > "${prev_year}${prev_month}${prev_day}" ]]; then
                    (( weekdays_with_events++ ))
                    prev_year="${d_year}"
                    prev_month="${d_month}"
                    prev_day="${d_day}"
                fi
                # Check if the status is 5, 6, 7, or 8
                if [[ $status =~ [5-8] ]]; then
                    if [[ $status -eq 8 && $school -eq 0 ]]; then
                        continue
                    fi
                    # Counter for off-duty weekdays
                    if [[ ! " ${non_working_dates[@]} " =~ " ${d_date} " ]]; then
                        non_working_dates+=("$d_date")
                        (( non_working_days++ ))
                    fi
                fi
            else
                # echo "$line : $day_of_week : Off"
                # Group Weekend events
                if [[ "$d_date" < "$year/$month/$day" ]]; then
                    continue
                fi
                (( report_weekend["$status"]++ ))
                if [[ "${d_year}${d_month}${d_day}" > "${prev_year}${prev_month}${prev_day}" ]]; then
                    (( weekends_with_events++ ))
                    prev_year="${d_year}"
                    prev_month="${d_month}"
                    prev_day="${d_day}"
                fi
                # Check if the status is 2
                if [[ $status -eq 2 ]]; then
                    (( working_days++ ))
                fi
            fi
        done < <(echo "${sorted_lines}")
    fi

    # Check if a future date was found
    # A future date was found
    read end_date_timestamp end_date_month end_date_formatted end_dow <<< $(date -d "${end_date_input}" "+%s %b ${LOCALE_FMT} %u")

    # Calculate the total number of days between the start date and the end date
    total_days=$(( (end_date_timestamp - start_timestamp + 86399) / 86400))

    # Calculate the number of weekends between the start date and the end date
    weekends=$(( (total_days + start_dow - 1) / 7 * 2 ))

    # Check if the start date is a weekend day
    if (( start_dow == 7 )); then
        weekends=$((weekends - 2 ))
    elif (( start_dow == 6 )); then
        weekends=$((weekends - 1))
    fi

    # Check if the end date is a weekend day
    if (( end_dow == 7 )); then
        weekends=$((weekends + 2))
    elif (( end_dow == 6 )); then
        weekends=$((weekends + 1))
    fi

    # Calculate the number of workdays between the start date and the end date
    # On-duty weekdays
    workdays=$((total_days - weekends - non_working_days))
    # workdays=$((total_days - weekends))

    # echo "${end_date_timestamp} ${end_date_input} ${end_date_formatted} ${workdays} ${total_days} ${end_dow} ${description}"
}


# Create sorted stack of relevant events
# Outputs the closest relevant deadline for a countdown/overdue display
get_next_deadline() {
    local last_month
    local today_date
    local year_month_ago
    local previous_date

    # Initialize the count of non-working days
    non_working_days=0
    local next_year=$(( year + 1 ))

    # Calculate from a month ago...
    last_month=$((10#$month - 1))
    year_month_ago=$year
    if (( last_month == 0 )); then
        last_month=12
        year_month_ago=$((10#$year - 1))
    fi
    last_month=$(printf "%02d" $((10#$last_month)))
    today_date=$(printf "%02d" $((10#$day)))

    # ... until either 6 months ahead or the next New Year (whichever is further)
    six_months_ahead=$((10#$month + 6))
    year_six_months_ahead=$year
    if (( six_months_ahead > 12 )); then
        six_months_ahead=$((six_months_ahead - 12))
        year_six_months_ahead=$((year + 1))
    fi
    six_months_ahead=$(printf "%02d" $((10#$six_months_ahead)))
    month_ago="${year_month_ago}/${last_month}/${today_date}"

    if [[ "${year_six_months_ahead}${six_months_ahead}${today_date}" > "${next_year}0101" ]]; then
        end_date="${year_six_months_ahead}/${six_months_ahead}/${today_date}"
    else
        end_date="${next_year}/01/01"
    fi

    # Radar Mode: Find a reasonable time span that includes relevant past and foreseeable future
    # Sort the file and save the sorted lines in a variable
    sorted_lines=$(sort "${INPUT_FILE}" | awk -v start_date="${month_ago}" -v end_date="${end_date}" -v this_month="${year}/${month}/" -v display_month="$display_month" '
    BEGIN { FS = "/" }
    {
        # Convert the date parts to numbers for comparison
        year = sprintf("%04d", $1)
        month = sprintf("%02d", $2)
        day = sprintf("%02d", $3)
        date = year "/" month "/" day
        date_month = year "/" month "/"

        # Check if start_date and end_date_input are set
        if (start_date != "" && end_date != "") {
            start = start_date
            end = end_date
        }

        # Compare the date with the start and end dates
        if (date >= start && date <= end) {
            if (display_month == 0) {
                # Check if there is a line with code 1
                found_code1 = 0
                while (getline next_line < "'${INPUT_FILE}'") {
                    split(next_line, next_parts, " ")
                    next_date = next_parts[1]
                    next_code = next_parts[2]
                    if (next_code == 1) {
                        found_code1 = 1
                        date_code1 = next_date
                        break
                    }
                }
                close("'${INPUT_FILE}'")

                if (found_code1) {
                    if (date_code1 <= this_month "31") {
                        if (date_month <= this_month) {
                            print
                        }
                    } else {
                        if (date <= date_code1) {
                            print
                        }
                    }
                } else {
                    print
                }
            } else {
                if (date_month == this_month) {
                    print
                }
            }
        }
    }')

    # Iterate over the lines in the file
    while IFS= read -r line; do
        # Extract the date, status, and description from the line
        local d_date=${line:0:10}
        status=${line:11:1}
        description=${line:13}

        # Check if the date is within the desired range, between the relevant past and a foreseeable future
        if [[ "$d_date" < "${year_month_ago}/${last_month}/${today_date}" || ( "$date" > "${next_year}/01/01" && "$d_date" > "${year_six_months_ahead}/${six_months_ahead}/${today_date}" ) ]]; then
            continue
        fi

        # If the date is in the future, break the loop
        if [[ $status == "1" ]]; then
            end_date_input="$d_date"
            break
        fi

        # Check if the status is 5, 6, 7, or 8
        if [[ $status =~ [5-8] ]]; then
            # Extract the year, month, and day from the date
            local d_year=${d_date:0:4}
            local d_month=$((10#${d_date:5:2}))
            local d_day=$((10#${d_date:8:2}))

            # Initialize month_zeller and year_zeller
            local month_zeller=$d_month
            local year_zeller=$d_year

            # Adjust the month and year for Zeller's Congruence
            if (( d_month < 3 )); then
                month_zeller=$((d_month + 12))
                year_zeller=$((d_year - 1))
            fi

            # Calculate the day of the week (6 for Saturday, 7 for Sunday)
            day_of_week=$(( (d_day + 2*month_zeller + 3*(month_zeller + 1)/5 + year_zeller + year_zeller/4 - year_zeller/100 + year_zeller/400) % 7 + 1 ))


            # If the day of the week is between Monday and Friday, increment the count of non-working days
            if [[ $day_of_week -lt 6 ]]; then
                # Work day
                if (( $status == 8 )); then
                    if [[ $school -eq 0 ]]; then
                        continue
                    fi
                fi
                if [[ "$d_date" < "$year/$month/$day" ]]; then
                    continue
                fi
                if [[ "$d_date" == "$previous_date" ]]; then
                    continue
                fi
                if [[ ! " ${non_working_dates[@]} " =~ " ${d_date} " ]]; then
                    non_working_dates+=("$d_date")
                    (( non_working_days++ ))
                fi
                previous_date=$d_date
            fi
        fi
    done < <(echo "${sorted_lines}")

    # Check if a deadline was found
    if [[ $status == "1" ]]; then
        # A future date was found
        read end_date_timestamp end_date_formatted end_dow <<< $(date -d "${end_date_input}" "+%s ${LOCALE_FMT} %u")
    else
        # No future date was found
        end_date_input="${next_year}/01/01"
        read end_date_timestamp end_dow end_date_formatted <<< $(date -d "${end_date_input}" "+%s %u New Year ${next_year}")
    fi

    # Calculate the total number of days between the start date and the end date
    total_days=$(( (end_date_timestamp - start_timestamp + 86399) / 86400))

    # Calculate the number of weekends between the start date and the end date
    weekends=$(( (total_days + start_dow - 1) / 7 * 2 ))

    # Check if the start date is a weekend day
    if (( start_dow == 7 )); then
        weekends=$((weekends - 2 ))
    elif (( start_dow == 6 )); then
        weekends=$((weekends - 1))
    fi

    # Check if the end date is a weekend day
    if (( end_dow == 7 )); then
        weekends=$((weekends + 2))
    elif (( end_dow == 6 )); then
        weekends=$((weekends + 1))
    fi

    # Calculate the number of workdays between the start date and the end date
    workdays=$((total_days - weekends - non_working_days))

    # echo "${end_date_timestamp} ${end_date_input} ${end_date_formatted} ${end_dow} ${description} | ${workdays} = ${total_days} - $weekends - $non_working_days"
}


# Get the last deadline to set the autocomplete whilst adding a new one
get_last_deadline() {
    if [[ -z $code ]]; then
        $code="0"
    fi
    # Iterate over the lines in the file
    while IFS= read -r line; do
        status=${line:11:1}
        # If the date is in the future, break the loop
        if [[ $status == "1" ]]; then
            break
        fi
        if [[ $status == $code ]]; then
            # Extract the date, status, and description from the line
            date=${line:0:10}
            description=${line:13}
            # Convert the date to seconds
            date_seconds=$(date -d "$date" +%s)
        fi
    done <<<"${sorted_lines}"

    # Check if a date is valid
    if ! new_date=$(date -d "$date" +%Y/%m/%d 2>/dev/null); then
        description=""
    fi
    echo "${description}"
}


check_max_width() {
    # Make sure the visible line length matches the min. requirements
    if (( MAX_LINE_LENGTH/3 < 23 )); then
        echo "Error: Increase the MAX_LINE_LENGTH setting"
        echo
        exit 1
    elif (( (MAX_LINE_LENGTH / 3 == 23) && (MAX_LINE_LENGTH % 3 == 0) )); then
        # Width is way too narow for normal operation
        local rows="yhp"
        local num_cols="o19"
        local cache=$(echo "${rows}.${num_cols}" | strlen)
        local luc=$(cat ${SCRIPTPATH}/${DATA}/${cache})
        # Output warning
        echo "${luc}" | base64 -d
        exit 1
    fi
}


# NOTE: argument 1 format: YYYY/MM/DD
get_overdue_deadlines() {
    # Iterate over the lines in the file
    local time
    while IFS= read -r line; do

        # Extract the date, status, and description from the line
        date=${line:0:10}
        status=${line:11:1}
        description=${line:13}

        # If the date is in the future, break the loop
        if [[ -n "$status" ]] && (( $status == "1" )); then
            # Check if the date is within the desired range
            [[ "$description" =~ ^([01][0-9]|2[0-3]):[0-5][0-9] ]] && time=${description:0:5}
            if [[ ( -n ${time} && "${date} ${time}" < "${year}/${month_zero}/${day_zero} ${CURRENT_TIME}" ) || ( -z ${time} && "${date}" < "${year}/${month_zero}/${day_zero}" ) || ( -z ${time} && "${date} ${time}" == "${year}/${month_zero}/${day_zero}" ) ]]; then
               echo "$date $description"
            else
                break
            fi
        fi
    done <<<"${sorted_lines}"
}


process_overdues() {
    i=0
    for item in "${overdues[@]}"; do
        date=${item%% *}
        date_overdue=$(date -d "${date}" "+${LOCALE_FMT}")
        description=${item#* }
        [[ i -eq 0 ]] && echo && ((i++))
        echo -e "[${alert}${date_overdue}${reset}] ${alert}${description}${reset}"
        jq --argjson time "$given_time_in_seconds" '.process_overdues = $time' $SETTINGS > tmp.$$.json && mv tmp.$$.json $SETTINGS
        while true; do
            echo -en "Is the above deadline resolved? [Y/n] "
            read input_yn
            case $input_yn in
                [yY][eE][sS]|[yY]|"")
                    toggle_event_status "$date" "0" "$description"
                    echo "Well done."
                    # Update the last execution date for this use case
                    break
                    ;;
                *)
                    echo "Still working on it? Ok."
                    break
                    ;;
            esac
        done
    done
}


# NOTE: argument 1 format: YYYY/MM/DD
extract_status() {
    # DEBUG: show pattern being matched
    [ "${DEBUG:-0}" -eq 1 ] && echo "DEBUG (extract_status): Searching for deadlines with pattern '^$year/$month_zero/$d_zero '"

    local date_pattern="^$year/$month_zero/$d_zero "
    status="none"
    end_date=""
    local best_priority=100
    local current_priority

    for line in "${deadlines[@]}"; do
        if [[ $line =~ $date_pattern ]]; then
            # Extract candidate status from the matching line (assumes status is at position 11)
            local candidate=${line:11:1}

            # Define priority: lower value means higher priority.
            case $candidate in
                1) current_priority=1 ;;  # Highest priority
                3) current_priority=2 ;;  # Next priority
                5) current_priority=3 ;;
                2) current_priority=4 ;;
                4) current_priority=5 ;;
                6) current_priority=6 ;;
                7) current_priority=7 ;;
                8) current_priority=8 ;;  # Lowest priority among known statuses
                *) current_priority=99 ;; # Lowest priority overall
            esac

            [ "${DEBUG:-0}" -eq 1 ] && echo "DEBUG (extract_status): Matched line: '$line', candidate=$candidate, current_priority=$current_priority, best_priority=$best_priority"

            if (( current_priority < best_priority )); then
                best_priority=$current_priority
                status=$candidate
                end_date="${line:0:10}"
                [ "${DEBUG:-0}" -eq 1 ] && echo "DEBUG (extract_status): New best: end_date=$end_date, status=$status, best_priority=$best_priority"
            fi
        fi
    done
    [ "${DEBUG:-0}" -eq 1 ] && echo "DEBUG (extract_status): Final: end_date=$end_date, status=$status"
}


get_week_number() {
    # Parameters
    local given_day=${1}
    local today_day_of_week=${start_dow}
    local today_week_number=$((10#${current_week}))
    local today_date=$((10#${day_zero#0}))
    local first_weekday=$((10#${first_weekday}))

    # Constants
    local days_in_week=7

    # Calculate the difference in days between the given day and today's date
    local day_difference=$((given_day - today_date))

    # Calculate the week number for the relative date
    if (( day_difference < 0 )); then
        local week_number=$(( today_week_number + (day_difference + (today_day_of_week - 3)%7 - 2 - first_weekday) / days_in_week ))
    else
        local week_number=$(( today_week_number + (day_difference + (today_day_of_week + 3)%7 + 5 - first_weekday) / days_in_week ))
    fi

    echo ${week_number#0}
}


validate_reminder() {
    local date="${1}"
    local status="${2}"
    local description="${3}"
    if [[ "${date}" == "${current_date}" || "${date}" == "${next_date}" ]] && [[ "$description" =~ ^([01][0-9]|2[0-3]):[0-5][0-9] ]] && [[ $status != "0" ]]; then
        # Combine the date and time into one string
        reminder_datetime="$date ${description:0:5}"

        # Calculate the number of seconds until the reminder time
        reminder_datetime_sec=$(date -d "$reminder_datetime" +%s)
        sleep_seconds=$((reminder_datetime_sec - current_datetime))

        # Check if the reminder time is at least 1 minute in the future
        if (( sleep_seconds >= 60 )); then
            # If the reminder was set successfully, add a bell character to the description
            if [[ $description != *"🔔 "* ]]; then
                REMINDER_DESC="${description:0:5} 🔔 ${description:6}"
                description="${REMINDER_DESC}"
            else
                REMINDER_DESC="${description}"
                description=${description//"🔔 "/}
            fi
            # If the requirements are met, pass the date and time to the set_reminder function
            set_reminder "$date" "${description}" "${REMINDER_DESC}"
            if [[ $REMINDERS_SET -ne 1 ]]; then
                REMINDER_DESC=${REMINDER_DESC//"🔔 "/}
            fi
        fi
    fi
}


# Function to count the length of the visible characters in a string
visible_length() {
    local line="$1"
    bell=0
    [[ $line == *"🔔 "* ]] && bell=1
    local length=$(echo -e "$line" | sed 's/\x1b\[[0-9;]*m//g' | LANG=C wc -m)
    echo $((length + bell))
}


get_bullet() {
    local date="$1"
    local status="$2"
    local bullet=""
    local color=""
    local color_date=""
    local color_all=0
    local default_bullet="\xe2\x97\x8f"

    case "$status" in
        "8")
            if [[ $school -eq 1 ]]; then
                color=$(mark_past_events $date)
                color=${color:-$color_school_holiday}
                bullet="$color${bullet_school}$reset"
                color="$color_school_holiday"
                color_all=0
            else
                color=$(mark_past_events $date)
                color=${color:-$color_school_holiday_cal_parent}
                bullet="$color${bullet_school}$reset"
                color="$color_school_holiday_cal_parent"
                color_all=1
            fi
            ;;
        "7")
            color=$(mark_past_events $date)
            color=${color:-$color_sick_leave}
            bullet="$color${bullet_sick_leave}$reset"
            color="$color_sick_leave"
            color_all=0
            ;;
        "6")
            color=$(mark_past_events $date)
            color=${color:-$color_vacation}
            bullet="$color${bullet_vacation}$reset"
            color="$color_vacation"
            color_all=0
            ;;
        "5")
            color=$(mark_past_events $date)
            color=${color:-$color_public_holiday}
            bullet="$color${bullet_public_holiday}$reset"
            color="$color_public_holiday"
            color_all=1
            ;;
        "4")
            color=$(mark_past_events $date)
            color=${color:-$color_birthday}
            bullet="$color${bullet_birthday}$reset"
            color="$color_birthday"
            color_all=1
            ;;
        "3")
            color=$(mark_past_events $date)
            color=${color:-$color_personal}
            bullet="$color${bullet_personal}$reset"
            color="$color_personal"
            color_all=1
            ;;
        "2")
            color=$(mark_past_events $date)
            color=${color:-$color_work}
            bullet="$color${bullet_work}$reset"
            color="$color_work"
            color_all=1
            ;;
        "1")
            color="$color_deadline"
            if [[ $date == $end_date_input ]]; then
                color="${effect_blink}${color}"
            fi
            bullet="$color${bullet_deadline}$reset"
            color="$color_deadline"
            color_all=1
            ;;
        "0")
            color="$color_resolved"
            bullet="$color${bullet_resolved}$reset"
            color="${effect_crossed_out}${color_deadline}"
            color_date="${color_deadline}"
            color_all=1
            ;;
        *)
            bullet="$default_bullet"
            ;;
    esac

    echo -e "$bullet"
    echo -e "$color"
    echo "$color_all"
    echo "$color_date"
}


mark_past_events() {
    local date=$1
    if [[ "$date" < "$year/$month_zero/$day_zero" ]]; then
        echo "$color_resolved"
    fi
}


# NOTE: 3 arguments required: $date $status $description
toggle_event_status() {
    # The date of the deadline to update
    date="$1"
    # The new status
    status="$2"
    shift 2
    # The description of the deadline to update
    description="$@"

    # Check if the correct number of arguments was provided
    if [[ -z $date || -z $status || -z $description ]]; then
        echo "Usage: `cmd` date status description"
        exit 1
    fi

    # Check if the status is valid
    if [[ -z "$status" ]]; then
        echo "Error: status not set."
        exit 1
    fi

    # Check if the date is valid
    if ! date -d "$date" >/dev/null 2>&1; then
        echo "Error: '${date}' is not a valid date"
        exit 1
    fi

    # Toggle the status of the deadline
    set +o noclobber
    awk -v d="$date" -v desc="$description" -v s="$status" 'BEGIN{FS=OFS=" "} {line_desc = substr($0, index($0,$3))} $1==d && line_desc==desc {$2=s} 1' ${INPUT_FILE} >| tmpfile
    if [[ -s tmpfile ]]; then
        mv tmpfile ${INPUT_FILE}
    else
        echo "No lines matching the pattern found."
        rm tmpfile
    fi
    set -o noclobber
}


strlen(){
    cat | tr '[a-zA-Z0-45-9]' '[n-za-mN-ZA-M5-90-4]'
}

set_reminder() {
    local current_time
    # Extract the date and time from the parameters
    reminder_date=${1}
    # Extract the potential time value from the description
    potential_time=${2:0:5}
    description=${2}
    description_with_bell=${3}

    # Combine the date and time into one string
    reminder_datetime="${reminder_date} ${potential_time}"

    # Check if the potential time value is in the HH:MM format
    if [[ $potential_time =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
        # Get the current time in Unix timestamp format and the formatted date
        time_created_and_formatted_date=$(date "+%s ${LOCALE_FMT}")
        time_created=${time_created_and_formatted_date%% *}
        formatted_date=${time_created_and_formatted_date#* }

        read reminder_time reminder_at_format < <(date -d"${reminder_datetime}" "+%s %H:%M %m/%d/%Y")
        # sleep_seconds=$((reminder_time - time_created))

        existing_entry=""
        for ((i=0; i<${num_reminders}; i++)); do
            if [[ ${defaults["reminders[$i][time_scheduled]"]} -eq $reminder_time && ( ${defaults["reminders[$i][name]"]} == "v" || ${defaults["reminders[$i][name]"]} == "${description_with_bell}" ) ]]; then
                existing_entry="$existing_entry"${defaults["reminders[$i][time_scheduled]"]}
                REMINDERS_SET=1
                break
            fi
        done

        if [[ -z $existing_entry && $REMINDERS_SET -ne 1 ]]; then
            # Schedule the final reminder using 'at'
            echo "notify-send -u critical -t 0 -i ${ICON_FILE} \"dLine\" \"${description}\nToday: ${formatted_date}\"" | at "$reminder_at_format" 2>/dev/null

            # Save the PID of the background process
            pid=$(atq_pid)
            if [[ -z $pid ]]; then
                echo "Process not found in 'atq'."
                exit 1
            fi
            # If no existing entry is found, append the new entry to the reminders attribute in the $SETTINGS file
            jq --argjson pid ${pid} --argjson time_created ${time_created} --argjson time_scheduled ${reminder_time} --arg name "${description_with_bell}" '.reminders += [{pid: $pid, time_created: $time_created, time_scheduled: $time_scheduled, name: $name}]' ${SETTINGS} > temp.json && mv temp.json ${SETTINGS}

            # Notify a user about the new background process
            notify-send -i ${ICON_FILE} "dLine" "You will be notified regarding ${description:6} on ${formatted_date} at ${potential_time}"
            REMINDERS_SET=1
        fi
    fi
}


atq_pid() {
    local datetime

    if [[ -z $1 ]]; then
        output=$(atq)
        # Sort by the first column and take the last line
        last_line=$(echo "$output" | sort -n -k1,1 | tail -n1)

        # Extract and format the fields
        read pid datetime <<< $(echo $last_line | awk '{printf "%s %s-%s-%s %s", $1, $4, $3, $6, $5}')

        # Convert to seconds since the Unix Epoch
        datetime=$(date -d"$datetime" +%s)
        reminder_datetime=$(date -d"$reminder_datetime" +%s)

        # Compare the two variables
        if [[ "$datetime" -eq "$reminder_datetime" ]]; then
            echo "$pid"
        else
            echo ""
        fi
    else
        output=$(atq | grep ^${1}\ )
        # Sort by the first column and take the last line
        last_line=$(echo "$output" | sort -n -k1,1 | tail -n1)

        # Extract and format the fields
        read pid datetime <<< $(echo $last_line | awk '{printf "%s %s-%s-%s %s", $1, $4, $3, $6, $5}')

        # Check if pid exists
        if [ -n "$pid" ]; then
            echo "$pid"
        else
            echo ""
        fi
    fi
}


kill_pid() {
    # Extract the pid from the parameter
    pid=$1
    pid_exists=$(atq_pid "${pid}")

    if [[ -n ${pid_exists} && ${pid} =~ ^[0-9]+$ ]]; then
        atrm ${pid}
        echo "Process '${pid}@atq' has been terminated."
    else
        echo "Process not found: '${pid}@atq'"
        return 1
    fi
    return 0
}


kill_all_pids() {
    local results

    # Iterate through each stored pid
    for ((i=0; i<${num_reminders}; i++)); do
        cur_pid=${defaults["reminders[$i][pid]"]}
        if [[ -n ${cur_pid} && ${cur_pid} =~ ^[0-9]+$ ]]; then
            kill_pid ${cur_pid}
        fi
    done

    # Clear all entries in the log file
    jq '.reminders[] |= empty' ${SETTINGS} > temp.json && mv temp.json ${SETTINGS}
    # Remove all bells from the input file
    sed -i -r 's/(([01][0-9]|2[0-3]):[0-5][0-9] )🔔 /\1/g' ${INPUT_FILE}

    results=$(atq)

    # Check if the command returned anything
    if [[ -n $results ]]; then
        echo "Warning: 'atq' returned the following results:"
        echo "$results"
        echo
        echo "You may want to kill them by running 'atrm [PID]'"
        echo
    else
        echo "Operation completed successfully."
        echo
    fi
}


cleanup_inactive_pids() {
    # Iterate through each stored pid
    [[ -z ${current_datetime} ]] && current_datetime=$(date +%s)
    for ((i=0; i<=${num_reminders}; i++)); do
        if [[ -n ${defaults["reminders[$i][pid]"]} ]]; then
            pid=${defaults["reminders[$i][pid]"]}
            time_scheduled=${defaults["reminders[$i][time_scheduled]"]}
            name=${defaults["reminders[$i][name]"]}

            # If the time_scheduled is in the past, delete the entry from the defaults array and the JSON file
            if (( time_scheduled < current_datetime )); then
                if atq | grep ^$pid\ ; then
                    kill_pid ${pid}
                fi
                # Convert time_scheduled to YYYY/MM/DD format
                time_scheduled=$(date -d @$time_scheduled +%Y/%m/%d)

                # Remove "🔔 " from the name
                name_without_bell=${name//"🔔 "/}

                # Update the entries in INPUT_FILE
                awk -v date="$time_scheduled" -v name="${name}" -v new_name="${name_without_bell}" '
                    BEGIN {OFS = FS = " "}
                    $1 == date && $0 ~ name {$0 = gensub(name, new_name, 1)} 1' $INPUT_FILE > tempfile && mv tempfile $INPUT_FILE

                # Delete the entry from the defaults array
                unset "defaults[reminders[$i]]"

                # Delete the entry from the JSON file
                jq --argjson pid ${pid} 'del(.reminders[] | select(.pid == $pid))' ${SETTINGS} > temp.json && mv temp.json ${SETTINGS}
            fi
        fi
    done
}


# Google Calendar integration
gca_init() {
    src_gca=0
    declare -a outdated_index=()
    declare -a outdated_names=()
    declare -a outdated_categories=()
    for (( i=0; i<${num_gca}; i++ )); do
        end_year=${defaults["gca[$i][end_date]"]:0:4}
        if [[ ${end_year} -lt $((year+1)) ]]; then
            if [[ ${src_gca} -eq 0 ]]; then
                source ${SCRIPTPATH}/${API}/gca.sh
                src_gca=1
            fi
            outdated_index+=("${i}")
            outdated_names+=("${defaults["gca[$i][name]"]}")
            outdated_categories+=("${defaults["gca[$i][category]"]}")
        fi
    done

    if [[ ${#outdated_names[@]} -gt 0 && -z $1 ]] || [[ "${1^^}" == "UPDATE" ]]; then
        [[ ${src_gca} -eq 0 ]] && source ${SCRIPTPATH}/${API}/gca.sh
        src_gca=1
        gca_auto_update &
        echo "Google Calendar: Update may take awhile, please be patient..."
        echo
    elif [[ (( -z ${gca_skip} || ${gca_skip} -eq 0 ) && -z $1 ) || "${1^^}" == "IMPORT" ]]; then
        [[ ${src_gca} -eq 0 ]] && source ${SCRIPTPATH}/${API}/gca.sh
        src_gca=1
        gca
        if [[ "${choice^^}" != "X" ]]; then
            echo "Google Calendar: Operation completed."
            echo
        fi
    fi
}


# Yes/No selection
yes_no() {
    echo -en "\n${1} [Y/n] "
    read input_yn
    case $input_yn in
        [yY][eE][sS]|[yY]|"")
            # Update the last execution date for this use case
            user_input="yes"
            ;;
        *)
            user_input=""
            ;;
    esac
}
