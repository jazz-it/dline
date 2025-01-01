#!/usr/bin/env bash

# Display a simple calendar
dcal() {
    # Positioning the current date to arbitrary value
    case "${2}" in
        $ENFORCE)
            # Resolve Overdue Deadlines Mode
            test_date="${1}"
            enforce_resolve="${2}"
            mode=$ENFORCE
            ;;
        $CUSTOM_RANGE_KEY)
            # Calendar Calculator View
            start_end_date="${1}"
            range_key="${2}"
            test_date="${start_end_date%% *}"
            mode=$CUSTOM_RANGE_KEY
            if [[ $test_date == $TODAY ]]; then
                test_date=""
            else
                MSG['today']="From"
                MSG['until_deadline']="until target"
                MSG['days_until_deadline']="days ${MSG['until_deadline']}"
            fi
            end_date="${start_end_date#* }"
            ;;
        *)
            # Just continue
            test_date="${1}"
            ;;
    esac
    test_year=""
    # Display month without showing the current date
    display_month=0
    if ! test_year=$(date -d "$test_date" +%Y 2>/dev/null); then
      if [[ $test_date =~ ^[0-9]{4}\/[0-9]{2}$ ]]; then
        test_date="${test_date}/01"
        display_month=1
      else
        test_date=""
      fi
    fi

    IFS="/"
    if [[ -z "${test_date}" ]]; then
        formatted_date=$(date "+%Y/%m/%d/%b/%j/%U/%V/%A/%u/%X/${LOCALE_FMT}")
        start_timestamp=$(date -d "12:00 PM" "+%s")
    else
        local test_ts
        formatted_date=$(date -d "${test_date}" "+%Y/%m/%d/%b/%j/%U/%V/%A/%u/%X/${LOCALE_FMT}")
        [[ $test_date == *":"* ]] && test_ts=${test_date:0:-6} || test_ts=${test_date}
        start_timestamp=$(date -d "${test_ts} 12:00 PM" "+%s")
    fi

    # Use the read command to split the output into separate variables
    read year month day month_name day_of_year current_week_ansi current_week_iso day_name start_dow current_time current_date_formatted <<< "$formatted_date"

    output2=$(date -d "${year}/12/28" "+%U/%V")
    read total_weeks_ansi total_weeks_iso <<< "$output2"
    unset IFS

    current_date="${year}/${month}/${day}"
    current_date_dd="${current_date////-}"
    first_weekday=$(locale -k LC_TIME | grep ^first_weekday | cut -d= -f2 | tr -d '"')

    if [[ $display_month -ne 1 ]]; then
        if [[ -z ${oha_last_imported} ]] || [[ ${oha_last_imported} == "" ]] || [[ ${oha_last_imported:0:4} < $year ]] || [[ ${current_date_dd} > "${year}-08-31" && ${oha_last_imported} < "${year}-08-31" ]]; then
            source ${SCRIPTPATH}/${API}/oha.sh
            oha
            update_api_date_log
            if [[ ${oha_country_iso^^} != "X" ]]; then
                sort_input
            fi
        fi

        if [[ $gca_skip -ne 1 ]]; then
            gca_init
        fi
    fi

    # Determine the scenario of running the function
    # If the $CUSTOM_RANGE_KEY is set, it means we're just calculating custom date range
    if [[ ${2} == $CUSTOM_RANGE_KEY ]]; then
        # Mode: Calendar Calculator View
        # read end_timestamp end_date_input end_date_formatted workdays days end_dow description <<< $(get_next_deadline "${current_date}" "${end_date}")
        count_group_events "${current_date}" "${end_date}"
        if [[ "${month_name^^}" != "${end_date_month^^}" ]]; then
            month_name="${month_name^^} - ${end_date_month^^}"
        fi
    else
        # read end_timestamp end_date_input end_date_formatted workdays days end_dow description <<< $(get_next_deadline)
        get_next_deadline
    fi

    # Remove leading zeros from the variables
    month=${month#0}
    day=${day#0}

    # Get the total number of days in the current year (leap year detection)
    if [ "$(date -d "${year}-02-29" +%Y-%m-%d 2>/dev/null)" = "${year}-02-29" ]; then
        days=366
    else
        days=365
    fi

    if [ $first_weekday -eq 2 ]; then
        total_weeks=${total_weeks_iso}
        if [[ "${month}" == "1" && "${day}" -le 3 && "$(date -d "${year}/01/01" "+%V")" != "01" ]]; then
            current_week=0
        elif [[ "${month}" == "12" && "${current_week_iso}" == "01" ]]; then
            current_week=$((total_weeks + 1))
        else
            current_week=${current_week_iso}
        fi
        # Check if December 31 is in the first week of the next year and adjust the week number accordingly
        if [[ "$(date -d "${year}/12/31" "+%V")" == "01" ]]; then
            total_weeks=$((total_weeks + 1))
        fi
    else
        current_week=${current_week_ansi}
        total_weeks=${total_weeks_ansi}
    fi
    # Get the progress of the current year (values with leading zeros in bash are treated like octal numbers)
    percent=$((100 * $((10#$day_of_year)) / $days))

    if [[ $display_month -eq 0 ]]; then
      print_month_line
      # Print the required information
      printf "${color_header}${MSG['progress']}: %s%%    ${MSG['day']}: %s/%03d    ${MSG['week']}: %s/%02d    ${MSG['today']}: %s, %s    ${MSG['time']}: %s${reset}\n" "$percent" $day_of_year $days $current_week $total_weeks $day_name "$current_date_formatted" "$current_time"
    fi

    passed_due_date=0
    start_date=$current_date
    end_date=$end_date_input

    # First day of the month (timestamp)
    s=$((start_timestamp - (10#$day-1) * 86400))

    # Check if the start date is before the end date
    if [[ $start_timestamp-$end_date_timestamp -gt 86400 ]]; then
        passed_due_date=1
        start=$start_timestamp
        start_timestamp=$((end_date_timestamp+86400))
        end_date_timestamp=$start
        start_date=$end_date_input
        end_date=$current_date
    fi

    # Checking a proper use of singular vs. plural: day(s)
    sp=${MSG['day_plural']}
    if [[ $total_days -eq 1 ]]; then
        sp=${MSG['day_singular']}
    fi

    if [[ $display_month -eq 0 ]]; then
        if [[ $passed_due_date -eq 0 ]]; then
            if [[ "$workdays" -ne "$total_days" ]]; then
                if [[ "$end_date_formatted" == *"New Year"* ]]; then
                    printf "%s ${MSG['days_until_the']} %s  ·  %s ${MSG['workdays_left']}\n" $total_days "$end_date_formatted" $workdays
                else
                    # Capture the output of printf into a variable
                    output=$(printf "%s ${MSG['days_until_deadline']} (%s)  ·  %s ${MSG['workdays_left']}  ·  \n" $total_days "$end_date_formatted" $workdays)

                    # Measure the visible length of the output
                    length=$(visible_length "$output")
                    trunc_desc "${description}"

                    # Print the output and its length
                    printf "%s ${MSG['days_until_deadline']} (%s)  ·  %s ${MSG['workdays_left']}  ·  %s\n" $total_days "$end_date_formatted" $workdays "$desc_truncated"
                fi
            else
                if [[ "$end_date_formatted" == *"New Year"* ]]; then
                    printf "%s %s ${MSG['until_the']} %s  ·  ${MSG['happy_new_year']}\n" $workdays $sp "$end_date_formatted"
                else
                    # Capture the output of printf into a variable
                    output=$(printf "%s %s ${MSG['until_deadline']} (%s)  ·  ${MSG['soon']}  ·  \n" $workdays $sp "$end_date_formatted")

                    # Measure the visible length of the output
                    length=$(visible_length "$output")
                    trunc_desc "${description}"

                    # Print the output and its length
                    printf "%s %s ${MSG['until_deadline']} (%s)  ·  ${MSG['soon']}  ·  %s\n" $workdays $sp "$end_date_formatted" "$desc_truncated"
                fi
            fi
        else
            # Capture the output of printf into a variable
            output=$(printf "${alert}${MSG['overdue']}: %s${reset}  ·  \n" "$total_days")

            # Measure the visible length of the output
            length=$(visible_length "$output")
            trunc_desc "${description}"

            # Print the output and its length
            printf "${alert}${MSG['overdue']}: %s${reset}  ·  %s\n" "$total_days" "$desc_truncated"
        fi
    fi

    check_max_width

    # If we've reached to this point and have the $CUSTOM_RANGE_KEY set, terminate the execution
    if [[ ${2} == $CUSTOM_RANGE_KEY ]]; then
        # Mode: Calendar Calculator View
        view_report
        echo
        exit 0
    fi

    # Split end_date into year, month, and day
    IFS="/" read end_year end_month end_day <<< "$end_date"

    # Add leading zeros to month and day if they are single digits
    printf -v end_month '%02d' "$((10#$end_month))"
    printf -v end_day '%02d' "$((10#$end_day))"

    # Combine year, month, and day into the new end_date
    end_date="${end_year}/${end_month}/${end_day}"

    # Horizontal line
    print_line

    printf -v month_zero '%02d' "$((10#$month))"
    printf -v day_zero '%02d' "$((10#$day))"

    l0= l1= l2=

    IFS=";"

    # Declare the array "months" (locale names)
    declare -a months
    months=($(locale -k LC_TIME | grep ^abmon | cut -d= -f2 | tr -d '"'))
    unset IFS

    # Get the 2-letter abbreviations for Saturday and Sunday
    sat=$(LC_TIME=C date -dSaturday +%a)
    sun=$(LC_TIME=C date -dSunday +%a)

    # Combine the abbreviations
    weekend_days="$sat$sun"

    last_date=""
    last_day=""
    multi_event_day=""
    # old_day="$day"
    # old_end_date="$end_date"
    # Read the deadlines into an array
    # mapfile -t deadlines < <(statuses_in_month)
    local date_pattern="^$year/$month_zero/"
    local monthly_sorted_lines="$(echo "${sorted_lines}" | grep "${date_pattern}")"
    mapfile -t deadlines <<<"${monthly_sorted_lines}"

    if [[ ${#defaults[@]} -eq 0 ]]; then
        echo "Internal error: JSON file can not be parsed."
        exit 1
    fi

    # s - first day of the month (timestamp)
    # a - name of a day
    # d - date
    # m - month
    while
    for field in a d m; do printf -v "$field" "%(%-$field)T" "$s"; done
    ((month == m))
    do
        if [[ $d -lt 13 ]]; then
            if [[ $d -lt $month ]]; then
                color="${color_past_months}"
            elif [[ $d -gt $month ]]; then
                color="${color_future_dates}"
            else
                color="${color_current_month}"
            fi
            printf -v l0 "%s${color}%-8s${reset}" "$l0" "${months[$d-1]}"
        fi

        (( ${#a} > 2 )) && a="${a:0:2}"
        printf -v d_zero '%02d' "$((10#$d))"
        # If the day and date have already been processed due to DST, skip the rest of the loop
        if [[ "$last_day" == "$a" && "$last_date" == "$d" ]]; then
            ((s += 86400))
            continue
        fi

        if [[ $display_month -eq 1 ]]; then
            day=0
            end_date="1970/01/01"
        fi
        if [[ 10#$d -lt 10#$day ]]; then
            color="${color_past_dates}"
        elif [[ 10#$d -gt 10#$day ]]; then
            # Check if the deadline should be rendered for a given month
            extract_status
            if [[ $display_month -eq 1 ]] && [[ "$end_date_input" == "$year/$month_zero/$d_zero" || ( $status == "1" && ${defaults["categories[1][show]"]} -eq 1 ) ]]; then
                color="${color_deadline_cal}"
            fi
            if [[ "$weekend_days" == *"$a"* ]]; then
                [[ "$multi_event_day" == "$d_zero" ]] && continue
                if [[ -n $end_date ]] && [[ "$end_date" == "$year/$month_zero/$d_zero" || ( $status == "1" && ${defaults["categories[1][show]"]} -eq 1 ) ]]; then
                    color=$(get_bg_color "${color_deadline_cal}")
                elif [[ -n $end_date ]] && [[ "$end_date" == "$year/$month_zero/$d_zero" || ( $status == "5" && ${defaults["categories[5][show]"]} -eq 1 ) ]]; then
                    color="${color_public_holiday_cal}"
                    multi_event_day="$d_zero"
                elif [[ -n $end_date ]] && [[ "$end_date" == "$year/$month_zero/$d_zero" || ( $status == "2" && ${defaults["categories[2][show]"]} -eq 1 ) ]]; then
                    color=$(get_bg_color "${color_work_cal}")
                elif [[ -n $end_date ]] && [[ "$end_date" == "$year/$month_zero/$d_zero" || ( $status == "3" && ${defaults["categories[3][show]"]} -eq 1 ) ]]; then
                    color=$(get_bg_color "${color_personal_cal}")
                elif [[ -n $end_date ]] && [[ "$end_date" == "$year/$month_zero/$d_zero" || ( $status == "4" && ${defaults["categories[4][show]"]} -eq 1 ) ]]; then
                    color=$(get_bg_color "${color_birthday_cal}")
                elif [[ -n $end_date ]] && [[ "$end_date" == "$year/$month_zero/$d_zero" || ( $status == "0" && ${defaults["categories[0][show]"]} -eq 1 ) ]]; then
                    color=$(get_bg_color "${color_resolved_cal}")
                else
                    color="${color_weekends}"
                fi
            elif [[ -n $end_date ]] && [[ "$end_date" == "$year/$month_zero/$d_zero" || ( $status == "1" && ${defaults["categories[1][show]"]} -eq 1 ) ]]; then
                color="${color_deadline_cal}"
            elif [[ $passed_due_date -eq 0 ]] && [[ "$TODAY" == "$year/$month_zero/$d_zero" ]]; then
                color="${color_today}"
            elif [[ -n $end_date ]] && [[ "$end_date" == "$year/$month_zero/$d_zero" || ( $status == "5" && ${defaults["categories[5][show]"]} -eq 1 ) ]]; then
                color="${color_public_holiday_cal}"
            elif [[ -n $end_date ]] && [[ "$end_date" == "$year/$month_zero/$d_zero" || ( $status == "2" && ${defaults["categories[2][show]"]} -eq 1 ) ]]; then
                color="${color_work_cal}"
            elif [[ -n $end_date ]] && [[ "$end_date" == "$year/$month_zero/$d_zero" || ( $status == "3" && ${defaults["categories[3][show]"]} -eq 1 ) ]]; then
                color="${color_personal_cal}"
            elif [[ -n $end_date ]] && [[ "$end_date" == "$year/$month_zero/$d_zero" || ( $status == "4" && ${defaults["categories[4][show]"]} -eq 1 ) ]]; then
                color="${color_birthday_cal}"
            elif [[ -n $end_date ]] && [[ "$end_date" == "$year/$month_zero/$d_zero" || ( $status == "6" && ${defaults["categories[6][show]"]} -eq 1 ) ]]; then
                color="${color_vacation_cal}"
            elif [[ -n $end_date ]] && [[ "$end_date" == "$year/$month_zero/$d_zero" || ( $status == "7" && ${defaults["categories[7][show]"]} -eq 1 ) ]]; then
                color="${color_sick_leave_cal}"
            elif [[ -n $end_date ]] && [[ "$end_date" == "$year/$month_zero/$d_zero" || ( $status == "8" && ${defaults["categories[8][show]"]} -eq 1 ) ]]; then
                if [[ $school -eq 1 ]]; then
                    color="${color_school_holiday_cal}"
                else
                    color="${color_school_holiday_cal_parent}"
                fi
            elif [[ -n $end_date ]] && [[ "$end_date" == "$year/$month_zero/$d_zero" || ( $status == "0" && ${defaults["categories[0][show]"]} -eq 1 ) ]]; then
                color="${color_resolved_cal}"
            else
                color=""
            fi
        else
            if [[ $passed_due_date -eq 1 && ${defaults["categories[1][show]"]} -eq 1 ]]; then
                color="${color_deadline_cal}"
            else
                color="${color_today}"
            fi
        fi
        printf -v l1 "%s${color}%-2s${reset} " "$l1" "$a"
        printf -v l2 "%s${color}%+2s${reset} " "$l2" "$d"
        ((s += 86400))
        last_day="$a"
        last_date="$d"
    done

    if [[ $display_month -eq 1 ]]; then
        # Mode: Static Calendar View
        view_calendar
        exit 0
    fi

    # Mode: Dynamic Calendar View (DEFAULT)
    # Read the overdues into an array
    mapfile -t overdues < <(get_overdue_deadlines)
    # If the INPUT_FILE hasn't been touched for more than 24h, ask the user about overdue deadlines
    given_time="${year}/${month_zero}/${day_zero} $current_time"
    given_time_in_seconds=$(date -d "$given_time" +%s)

    # Check if the last scheduled cleanup date exists
    if [[ -n $last_scheduled_date ]]; then
        # Calculate seconds in DEFAULT_CLEANUP_FREQUENCY months
        seconds_in_months=$((DEFAULT_CLEANUP_FREQUENCY * 30 * 24 * 60 * 60))

        # Calculate default_cleanup_date
        if (( $seconds_in_months == 0 )); then
            # Setting: never perform an automatic cleanup
            default_cleanup_date=$((start_timestamp + 60))
        else
            default_cleanup_date=$((last_scheduled_date + seconds_in_months))
        fi

        view_calendar

        if [[ $enforce_resolve == $ENFORCE ]] || [[ $enforce_resolve != $ENFORCE && $last_overdue_date -le $(( given_time_in_seconds-24*60*60 )) && $display_month -ne 1 ]]; then
            process_overdues
            cleanup_inactive_pids
        fi
    else
        view_calendar
        # The last execution date for scheduled backup doesn't exist, so we assume this is the first run
        last_scheduled_date=0
        # Initiate additional checks
        process_overdues
        cleanup_inactive_pids
    fi

    # Check if the current date (start_timestamp) is later than the default_cleanup_date
    if [[ $start_timestamp -gt $default_cleanup_date ]]; then
        expired_lines
        # If expired_lines found any expired events stored in $lines
        if [[ -n $lines ]]; then
            scheduled_cleanup
        fi
    fi
}


view_legend() {
    # Check if legend is 1
    if [[ $legend -eq 1 ]]; then
        print_legend_line
        print_legend | sed 's/^/ /'
    else
        if [[ -n $verbose ]]; then
            echo
        fi
    fi
}


view_calendar() {
    # Print the calendar
    n=$(( ($MAX_LINE_LENGTH - $last_date*3)/$last_date ))
    m=$(( ($MAX_LINE_LENGTH - (12*8-4))/12 )); (( m > 2 )) && m=$((m-3));
    spaces=$(printf "%${n}s" " ")
    spaces_m=$(printf "%${m}s")
    # echo "$l0" | cat -v

    # Replace all occurrences of "\033[0m " with "\033[0m $spaces" in $l1
    l0=$(echo -e "$l0" | sed "s/$(echo -e '\033')\[0m/$(echo -e '\033')\[0m$spaces_m/g")
    l1=$(echo -e "$l1" | sed "s/$(echo -e '\033')\[0m /$(echo -e '\033')\[0m$spaces/g")
    l2=$(echo -e "$l2" | sed "s/$(echo -e '\033')\[0m /$(echo -e '\033')\[0m$spaces/g")

    # Remove all trailing spaces
    l0=$(echo "$l0" | sed 's/[ \t]*$//')
    l1=$(echo "$l1" | sed 's/[ \t]*$//')
    l2=$(echo "$l2" | sed 's/[ \t]*$//')

    # Print the results
    printf '%s\n%s\n%s\n' "$l0" "$l1" "$l2"

    if [[ $verbose -eq 1 ]]; then
        view_monthly_events_details
        view_legend
    else
        echo
    fi
}


print_line() {
    # Straight line
    local total_cols
    local highlight_cols
    if [[ $display_month -eq 1 ]]; then
        print_month_line
    else
        total_cols=$(tput cols)
        highlight_cols=$((total_cols * $percent / 100))  # Calculate the number of columns to highlight
        echo -ne "$color_line_highlight"
        printf '%.s─' $(seq 1 "$highlight_cols")
        echo -ne "$color_line"
        printf '%.s─' $(seq "$((highlight_cols + 1))" "$total_cols")
        echo -e "$reset"
    fi
}


print_report_line() {
    # Straight line
    echo -ne "$color_line$(spaces $(( $leading_spaces - 2 )))"
    printf '%.s─' $(seq 1 $(( ${MAX_LINE_LENGTH} - 2*$leading_spaces + 4 )))
    echo -e "$reset"
}


print_month_line() {
    local len_month=${#month_name}
    local total_cols=$(tput cols)
    local max_total_cols=$((total_cols - len_month - 1))
    local highlight_cols=$((total_cols * $percent / 100))  # Calculate the number of columns to highlight

    [[ $highlight_cols -gt $(( max_total_cols )) ]] && highlight_cols=$max_total_cols

    # Print the highlighted part
    echo -ne "$color_line_highlight"
    printf '%.s─' $(seq 1 "$highlight_cols")

    # Print the remaining part in the original color
    echo -ne "$color_line"
    [[ $highlight_cols -lt $(( max_total_cols )) ]] && printf '%.s─' $(seq "$((highlight_cols + 1))" "$((max_total_cols - 1))")

    # Print the month name
    echo -e "${reset} ${month_name^^}"
}


print_legend_line() {
    # Straight line
    echo -ne "$color_line"
    printf '%.s─' $(seq 1 $(( $(tput cols) - 7 )))
    echo -ne " ᴸᴱᴳᴱᴺᴰ"
    echo -e "$reset"
}


print_legend() {
    # Parse the JSON data into an array using jq only once
    # parse_json
    declare -a entries
    # Calculate the number of categories
    for ((i=0; i<=${num_categories}; i++)); do
        name=${defaults["categories[$i][name]"]}
        # Skip if no category name is returned
        if [[ -n $name ]]; then
            if [[ "${i}" == "8" && ${school} -ne 1 ]]; then
                color="color_school_holiday_cal_parent"
            else
                color=${defaults["categories[$i][color]"]}
            fi
            bullet=${defaults["categories[$i][bullet]"]}
            show=${defaults["categories[$i][show]"]}
            # Skip category 0
            if [[ $i != 0 ]]; then
                entries+=("$i" "$name" "$color" "$bullet" "$show")
            fi
        fi
    done

    # Calculate the available space for each item
    item_space=$(( MAX_LINE_LENGTH / 4))
    # Total number of category items
    total_items=$((${#entries[@]} / 5))
    # Maximum number of rows
    total_rows=$(( ${total_items} / 4 ))

    # Prepare a variable to hold the output
    output=""

    # Initialize an array to store the maximum length for each column
    max_lengths=(-1 -1 -1 -1)

    # Iterate over each row
    for ((row=0; row<${total_rows}; row++)); do
        # Iterate over each column
        for ((col=0; col<4; col++)); do
            # Calculate the index of the name in the entries array
            index=$((row * 20 + col * 5 + 1))
            # Check if the index exists in the entries array
            if [[ -v entries[index] ]]; then
                # Get the name
                name=${entries[index]}
                # Get the length of the name
                length=${#name}
                # Update the maximum length for the column if necessary
                if (( length > max_lengths[col] )); then
                    max_lengths[col]=$length
                fi
            fi
        done
    done

    # Calculate the sum of all max_lengths values
    sum_max_lengths=$(IFS=+; echo "$((${max_lengths[*]}))")
    if [[ $sum_max_lengths < $MAX_LINE_LENGTH ]]; then
        single_space=$(( (MAX_LINE_LENGTH-sum_max_lengths)/3 ))
    fi

    # Prepare the names and keys in two lines and four columns
    for ((i=0; i<${#entries[@]}; i+=5)); do
        # Get the color and bullet using variable indirection
        name=${entries[i+1]}
        color=${!entries[i+2]}
        bullet=${!entries[i+3]}
        show=${entries[i+4]}
        # Calculate the number of spaces needed to reach item_space
        bullet_visible=$(visible_length "${bullet}")

        # Truncate the name if necessary and append an ellipsis
        if [[ -z ${single_space} ]]; then
            if (( ${#name} + ${#entries[i]} + bullet_visible + 1 > item_space )); then
                name=${name:0:$((item_space - ${#name} - ${#entries[i]} - bullet_visible - 1))}"…"
            fi
        fi
        crossed=""
        if [[ $show -ne 1 ]]; then
            crossed="${effect_crossed_out}"
            color="${color_resolved}"
        fi
        # Add the color, bullet, name, key, and reset to the output
        line="${color}${bullet} ${crossed}${name}${reset}${color}$(tiny_text ${entries[i]})${reset}"
        output+="$line"
        # Add a new line after the fourth column
        if (( (i / 5 + 1) % 4 == 0 )); then
            output+="\n"
        else
            if [[ -n ${single_space} ]]; then
                cols=$(( (i/5)%4 ))
                spaces_needed=$((${max_lengths[cols]} + ${single_space} - ${#name} - ${#entries[i]} - bullet_visible - 1))
                # Add the spaces to the output
            else
                spaces_needed=$((item_space - ${#name} - ${#entries[i]} - bullet_visible - 1))
                # Add the spaces to the output
            fi
                output+=$(printf "%${spaces_needed}s")
        fi
    done

    # Print the output
    echo -e "${output}"
}


view_report() {
    local categories=()
    local numbers_workday=()
    local numbers_weekend=()
    local count_workday_events=0
    local count_weekend_events=0

    for ((i=0; i<=${num_categories}; i++)); do
        name=${defaults["categories[$i][name]"]}
        # Skip if no category name is returned
        if [[ -n $name ]]; then
            color=${defaults["categories[$i][color]"]}
            if [[ $i -eq 8 && $school -ne 1 ]]; then
                categories+=("${color_school_holiday_cal_parent}${name}${reset}")
                numbers_workday+=("${color_school_holiday_cal_parent}$(add_thousand_separators ${report_workday[$i]:-0})${reset}")
                numbers_weekend+=("${color_school_holiday_cal_parent}$(add_thousand_separators ${report_weekend[$i]:-0})${reset}")
                continue
            fi
            categories+=("${!color}${name}${reset}")
            numbers_workday+=("${!color}$(add_thousand_separators ${report_workday[$i]:-0})${reset}")
            numbers_weekend+=("${!color}$(add_thousand_separators ${report_weekend[$i]:-0})${reset}")
        fi
    done
    # Add an element to the start of the index array
    categories+=("No Events")
    numbers_workday+=("$(add_thousand_separators $(( ${workdays:-0} + ${non_working_days:-0} - ${weekdays_with_events:-0} )))")
    numbers_weekend+=("$(add_thousand_separators $(( ${weekends:-0} - ${weekends_with_events:-0} )))")
    categories+=("Total")
    numbers_workday+=("$(add_thousand_separators $(( ${workdays:-0} + ${non_working_days:-0} )))")
    numbers_weekend+=("$(add_thousand_separators ${weekends:-0})")
    categories+=("")
    numbers_workday+=("On-duty")
    numbers_weekend+=("Off-duty")
    categories+=("Weekdays")
    numbers_workday+=("$(add_thousand_separators ${workdays:-0})")
    numbers_weekend+=("$(add_thousand_separators ${non_working_days:-0})")
    categories+=("${color_weekends}Weekends${reset}")
    numbers_workday+=("${color_weekends}$(add_thousand_separators ${working_days:-0})${reset}")
    numbers_weekend+=("${color_weekends}$(add_thousand_separators $(( ${weekends:-0} - ${working_days:-0} )))${reset}")
    categories+=("CUMULATIVE")
    numbers_workday+=("$(add_thousand_separators $(( ${working_days:-0} + ${workdays:-0} )))")
    numbers_weekend+=("$(add_thousand_separators $(( ${weekends:-0} - ${working_days:-0} + ${non_working_days:-0} )))")

    # Define headers
    header_text="Event Category"
    header_num1="Weekdays"
    header_num2="Weekends"


    # Find the length of the longest string in each column
    maxlen_text=${#header_text}
    maxlen_num1=$(( ${#header_num1}+var ))
    maxlen_num2=$(( ${#header_num2}+var ))

    # Calculate the maximum length of the items in each column, including the headers
    max_length_column1=$(max_length "${header_text}" "${categories[@]}")
    max_length_column2=$(max_length "${header_num1}" "${numbers_workday[@]}")
    max_length_column3=$(max_length "${header_num2}" "${numbers_weekend[@]}")

    # Calculate the space between columns
    leading_spaces=8
    local max_length=$((MAX_LINE_LENGTH < 92 ? MAX_LINE_LENGTH-leading_spaces+4 : 92-leading_spaces+4))

    space=$(( (max_length - leading_spaces -max_length_column1 - max_length_column2 - max_length_column3) / 2 ))

    echo
    echo
    # Print the header
    echo -e "$(spaces $leading_spaces)${header_text}$(spaces $((space + max_length_column1 - $(strip_escape_codes "${header_text}" | wc -m))))${header_num1}$(spaces $((space + max_length_column2 - $(strip_escape_codes "${header_num1}" | wc -m))))${header_num2}"

    # Print the elements of the arrays
    for ((i=0; i<${#categories[@]}; i++)); do
        # Calculate the number of spaces needed to align the columns
        spaces1=$(( space + max_length_column1 - $(strip_escape_codes "${categories[$i]}" | wc -m) + max_length_column2 - $(strip_escape_codes "${numbers_workday[$i]}" | wc -m )))
        spaces2=$((max_length_column3 - $(strip_escape_codes "${numbers_weekend[$i]}" | wc -m) + space))

        if [[ $i -eq 0 || $i -eq $((${#categories[@]}-5)) || $i -eq $((${#categories[@]}-3)) || $i -eq $((${#categories[@]}-1)) ]]; then
            print_report_line
        elif [[ $i -eq $((${#categories[@]}-4))  ]]; then
            echo
            echo
        fi
        # Print the items with the calculated spaces
        echo -e "$(spaces $leading_spaces)${categories[$i]}$(spaces $spaces1)${numbers_workday[$i]}$(spaces $spaces2)${numbers_weekend[$i]}"
    done
    echo
}


# Prints all the different categories of events
view_categories() {
    # Calculate the number of categories
    for ((i=0; i<=${num_categories}; i++)); do
        name=${defaults["categories[$i][name]"]}
        # Skip if no category name is returned
        if [[ -n $name ]]; then
            color=${defaults["categories[$i][color]"]}
            bullet=${defaults["categories[$i][bullet]"]}
            show=${defaults["categories[$i][show]"]}
            # Skip category 0
            if [[ $i != 0 ]]; then
                echo " $i: $name"
            fi
        fi
    done
    echo
}


view_monthly_events_details() {
    # Get all events for the given month
    local lines=$(events_in_month)
    local date
    local status
    local description

    # Split the lines into two arrays based on the date
    local first_half=()
    local second_half=()

    # Variables to track the start of the week
    local week_start=$(date "+%u")

    # Needed in 'validate_reminder' (inside the while loop)
    current_date="${year}/${month_zero}/${day_zero}"
    next_date=$(date -d "+1 day" "+%Y/%m/%d")
    current_datetime=$(date +%s)

    # Define description length
    desc_length=$(( MAX_LINE_LENGTH/2-9 ))

    # Parse the JSON file into an associative array
    declare -A show_values
    # while IFS=$'\t' read -r key show; do
    #     show_values[$key]=$show
    # done < <(jq -r '.categories | to_entries[] | [.key, .value.show] | @tsv' $SETTINGS)

    prev_week_number=-1
    while IFS= read -r line; do

        # Check if there's any data
        if [[ -z $line ]]; then
            echo
            continue
        fi

        # Extract the date and status from the line
        local date=${line:0:10}
        local date_y=${line:0:4}
        local date_m=$((10#${line:5:2}))
        local date_d=$((10#${line:8:2}))
        local status=${line:11:1}
        local description=${line:13}
        local show=${defaults["categories[$status][show]"]}

        # Check if the date is valid
        if [[ -z $line || -z $date || -z $status || -z $description ]] || [[ ! $date =~ ${date_regex} ]]; then
            echo
            continue
        fi

        # Check if the event is today or tomorrow and has a valid time at the start of the description
        [[ $display_month -ne 1 ]] && validate_reminder "${date}" "$status" "${description}"

        if [[ ${show} -eq 1 ]]; then
            # Check if the date is in the first or second half of the month
            if (( ${date_d} <= 15 )); then
                # Check if a new week has started
                # week_number=10#$(date -d "$date" "+%V")

                # Calculate the week number (refactored)
                week_number=$(get_week_number $date_d)

                if (( week_number > prev_week_number )); then
                    first_half+=("")
                    prev_week_number=$week_number
                fi
                if [[ -n $REMINDER_DESC ]]; then
                    line="${line:0:13}${REMINDER_DESC}"
                    unset REMINDER_DESC
                fi
                first_half+=("$line")
            else
                # Check if a new week has started
                # week_number=10#$(date -d "$date" "+%V")

                # Calculate the week number (refactored)
                week_number=$(get_week_number $date_d)

                if (( week_number > prev_week_number )); then
                    second_half+=("")
                    prev_week_number=$week_number
                fi
                if [[ -n $REMINDER_DESC ]]; then
                    line="${line:0:13}${REMINDER_DESC}"
                    unset REMINDER_DESC
                fi
                second_half+=("$line")
            fi
        fi
    done <<< "$(echo -e "$lines")"

    # Trim leading and trailing new lines from first_half and second_half
    while [[ ${first_half[0]} == "" && ${#first_half[@]} -gt 1 ]]; do
        first_half=("${first_half[@]:1}")
    done
    while [[ ${#first_half[@]} -gt 1 && ${first_half[-1]} == "" ]]; do
        unset 'first_half[${#first_half[@]}-1]'
    done
    while [[ ${second_half[0]} == "" && ${#second_half[@]} -gt 1 ]]; do
        second_half=("${second_half[@]:1}")
    done
    while [[ ${#second_half[@]} -gt 1 && ${second_half[-1]} == "" ]]; do
        unset 'second_half[${#second_half[@]}-1]'
    done
    # Calculate the number of lines in each column
    local num_lines=$(( (${#first_half[@]} > ${#second_half[@]} ? ${#first_half[@]} : ${#second_half[@]}) ))

    local description
    local day
    local bullet

    # Print the lines in two columns
    for (( i=0; i<$num_lines; i++ )); do
        # Get the line for the current row in each column
        local first_line=${first_half[$i]% #gc}
        first_line=${first_line% #oh}
        first_line=${first_line:-""}
        local second_line=${second_half[$i]% #gc}
        second_line=${second_line% #oh}
        second_line=${second_line:-""}

        # Inject ANSI codes into first_line and second_line
        if [[ -n "$first_line" ]]; then
            description=${first_line:13}
            # Truncate the lines if they are too long
            if (( ${#description} > $desc_length )); then
                if [[ $description == *"🔔 "* ]]; then
                    description="${description:0:$(( $desc_length-2 ))}…"
                else
                    description="${description:0:$(( $desc_length-1 ))}…"
                fi
            fi
            day=${first_line:8:2}
            # Read the output of get_bullet into an array
            mapfile -t bullet < <(get_bullet ${first_line:0:10} ${first_line:11:1})
            if (( ${bullet[2]} == 1 )); then
                color_title="${bullet[1]}"
            else
                color_title="${reset}"
            fi
            if [[ -z ${bullet[3]} ]]; then
                color_date="${color_title}"
            else
                color_date="${bullet[3]}"
            fi
            first_line=" ${bullet[0]} ${color_line}[${reset}${color_date}$day${reset}${color_line}] ${color_title}${description}${reset}"
        fi
        if [[ -n "$second_line" ]]; then
            description=${second_line:13}
            # Truncate the lines if they are too long
            if (( ${#description} > $desc_length )); then
                if [[ $description == *"🔔 "* ]]; then
                    description="${description:0:$(( $desc_length-2 ))}…"
                else
                    description="${description:0:$(( $desc_length-1 ))}…"
                fi
            fi
            day=${second_line:8:2}
            # Read the output of get_bullet into an array
            mapfile -t bullet < <(get_bullet ${second_line:0:10} ${second_line:11:1})
            if (( ${bullet[2]} == 1 )); then
                color_title="${bullet[1]}"
            else
                color_title="${reset}"
            fi
            if [[ -z ${bullet[3]} ]]; then
                color_date="${color_title}"
            else
                color_date="${bullet[3]}"
            fi
            second_line=" ${bullet[0]} ${color_line}[${reset}${color_date}$day${reset}${color_line}] ${color_title}${description}${reset}"
        fi

        # Calculate the length of the visible characters
        local length_first=$(visible_length "$first_line")
        local length_second=$(visible_length "$second_line")

        # Adjust the width argument to printf
        local width_first=$((MAX_LINE_LENGTH/2 - length_first))
        local width_second=$((MAX_LINE_LENGTH/2 - length_second))

        if [[ $i -eq 0 && ( -n $first_line || -n $second_line ) ]]; then
            echo
        fi

        # Add spaces before second_line when first_line is empty
        if [[ -z "$first_line" ]]; then
            printf "%-${width_first}s %b\n" " " "$second_line"
        else
            if (( width_first <= 0 )); then
                if [[ ${bell} -eq 0 ]]; then
                    printf "%b %b\n" "$first_line" "$second_line"
                else
                    printf "%b%b\n" "$first_line" "$second_line"
                fi
            else
                printf "%b%-${width_first}s %b\n" "$first_line" " " "$second_line"
            fi
        fi
    done
}
