# Display of a simple calendar
dcal() {

    declare -A MSG

    # NOTE: Configuration settings
    # If you would like to translate the output to your own language
    # copy/paste the content below into the new file called `.dlinerc`
    # and place it into the same directory with this script.
    # The file will be ignored from git, so you could freely edit all the values
    # from the associative array $MSG within the `.dlinerc` file which will override 
    # all the default values below.

    MSG['progress']="Progress"
    MSG['day']="Day"
    MSG['week']="Week"
    MSG['today']="Today"
    MSG['time']="Time"
    MSG['day_singular']="day"
    MSG['day_plural']="days"
    MSG['days_until_the']="days until the"
    MSG['new_year']="New Year"
    MSG['workdays_left']="workdays left"
    MSG['days_until_deadline']="days until deadline"
    MSG['until_the']="until the"
    MSG['until_deadline']="until deadline"
    MSG['happy_new_year']="We made it! ☃️"
    MSG['soon']="Hurry up! 😊"
    MSG['overdue']="Time overdue (in days)"

    # Color configuration could be also altered within .dlinerc
    alert="\033[0;31m"               # Red
    color_past_dates="\033[1;34m"    # Light Blue
    color_today="\033[7;33;34m"      # Light Blue inverted
    color_future_dates="\033[0;30m"  # Dark gray
    color_weekends="\033[0;35m"      # Magenta
    color_deadline="\033[0;45m"      # Inverted Magenta
    color_current_month="\033[0;33m" # Yellow
    color_line="\033[0;30m"          # Dark gray
    reset="\033[0m"                  # Reset color

    # --- Don't modify anything below this line ---

    # Get the current path
    SCRIPTPATH="$(
        cd -- "$(dirname "$0")" >/dev/null 2>&1
        pwd -P
    )"

    # Check if the file .dlinerc exists and source it if possible
    I18N=${SCRIPTPATH}/.dlinerc
    if [ -f "$I18N" ]; then
        source ${I18N}
    fi

    IFS="/"
    original_tz=$TZ
    export TZ=UTC

    # NOTE: For testing purposes only:
    test_date=""  # Assign your test date here in the format "YYYY-MM-DD HH:MM" to set the current date

    if [[ -z "${test_date}" ]]; then
        output1=$(date "+%Y/%m/%d/%j/%U/%V/%A/%s/%X")
    else
        output1=$(date -d "${test_date}" "+%Y/%m/%d/%j/%U/%V/%A/%s/%X")
    fi
    # Use the read command to split the output into separate variables
    read year month day day_of_year current_week_ansi current_week_iso day_name start_timestamp current_time <<< "$output1"
    # Remove leading zeros from the variables
    month=${month#0}
    day=${day#0}

    if [[ -z "${test_date}" ]]; then
        output2=$(date -d "${year}/12/28" "+%s/%U/%V")
    else
        output2=$(date -d "$(date -d "${test_date}" "+%Y")/12/28" "+%s/%U/%V")
    fi
    read last_day_timestamp total_weeks_ansi total_weeks_iso <<< "$output2"
    unset IFS

    current_date="${year}/${month}/${day}"
    locale_fmt=$(locale -k LC_TIME | grep ^d_fmt | cut -d= -f2 | tr -d '"' | sed -e 's/y/Y/')
    first_weekday=$(locale -k LC_TIME | grep ^first_weekday | cut -d= -f2 | tr -d '"')
    if [[ -z "${test_date}" ]]; then
        current_date_formatted=$(date "+${locale_fmt}")
    else
        current_date_formatted=$(date -d "${test_date}" "+${locale_fmt}")
    fi

    if [[ ! -e ${SCRIPTPATH}/.deadline ]]; then
        touch ${SCRIPTPATH}/.deadline
    fi
    end_date_input=$(head -n 1 ${SCRIPTPATH}/.deadline)
    if ! [[ $end_date_input =~ ^[0-9]{4}\/[0-9]{2}\/[0-9]{2}$ ]]; then
        end_date_input="$((year + 1))/01/01"
        end_date_formatted="New Year $((year + 1))"
    else
        end_date_formatted=$(date -d "$end_date_input" "+${locale_fmt}")
    fi

    # Get the total number of days in the current year
    if [ "$(date -d "${year}-02-29" +%Y-%m-%d 2>/dev/null)" = "${year}-02-29" ]; then
        total_days=366
    else
        total_days=365
    fi

    if [ $first_weekday -eq 2 ]; then
        total_weeks=${total_weeks_iso}
        if [[ "${month}" == "1" && "${day}" -le 3 && "$(date -d "${year}/01/01" "+%V")" != "01" ]]; then
            current_week=0
        elif [[ "${month}" == "12" && "$(date -d "${year}/${month}/${day}" "+%V")" == "01" ]]; then
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
    percent=$((100 * $((10#$day_of_year)) / $total_days))

    # Print the required information
    printf "${color_current_month}${MSG['progress']}: %s%%    ${MSG['day']}: %s/%03d    ${MSG['week']}: %s/%02d    ${MSG['today']}: %s, %s    ${MSG['time']}: %s${reset}\n" "$percent" $day_of_year $total_days $current_week $total_weeks $day_name "$current_date_formatted" "$current_time"

    end_timestamp=$(date -d "$end_date_input" +%s)

    passed_due_date=0
    start_date=$current_date
    end_date=$end_date_input

    # First day of the month (timestamp)
    s=$((start_timestamp - (10#$day-1) * 86400))

    # Check if the start date is before the end date
    if [[ $start_timestamp-$end_timestamp -gt 86400 ]]; then
        passed_due_date=1
        start=$start_timestamp
        start_timestamp=$end_timestamp+86400
        end_timestamp=$start
        start_date=$end_date_input
        end_date=$current_date
    fi

    days=$(((end_timestamp - start_timestamp + 86399) / 86400))

    # Checking a proper use of singular vs. plural: day(s)
    sp=${MSG['day_plural']}
    if [[ $days -eq 1 ]]; then
        sp=${MSG['day_singular']}
    fi

    start_dow=$(date -d "$start_date" +%u)
    end_dow=$(date -d "$end_date" +%u)

    weekends=$(((days + $start_dow - 1) / 7 * 2))

    # Check if the start date is a weekend day
    if [ $start_dow -eq 7 ]; then
        weekends=$((weekends - 2))
    elif [ $start_dow -eq 6 ]; then
        weekends=$((weekends - 1))
    fi

    # Check if the end date is a weekend day
    if [ $end_dow -eq 7 ]; then
        weekends=$((weekends + 2))
    elif [ $end_dow -eq 6 ]; then
        weekends=$((weekends + 1))
    fi

    workdays=$((days - weekends))

    if [[ $passed_due_date -eq 0 ]]; then
        if [[ "$workdays" -ne "$days" ]]; then
            if [[ "$end_date_formatted" == *"New Year"* ]]; then
                printf "%s ${MSG['days_until_the']} %s  ·  %s ${MSG['workdays_left']}\n" $days "$end_date_formatted" $workdays
            else
                printf "%s ${MSG['days_until_deadline']} (%s)  ·  %s ${MSG['workdays_left']}\n" $days "$end_date_formatted" $workdays
            fi
        else
            if [[ "$end_date_formatted" == *"New Year"* ]]; then
                printf "%s %s ${MSG['until_the']} %s  ·  ${MSG['happy_new_year']}\n" $workdays $sp "$end_date_formatted"
            else
                printf "%s %s ${MSG['until_deadline']} (%s)  ·  ${MSG['soon']}\n" $workdays $sp "$end_date_formatted"
            fi
        fi
    else
        printf "${alert}${MSG['overdue']}: %s${reset}\n" "$days"
    fi

    # Split end_date into year, month, and day
    IFS="/" read end_year end_month end_day <<< "$end_date"

    # Add leading zeros to month and day if they are single digits
    printf -v end_month '%02d' "$end_month"
    printf -v end_day '%02d' "$end_day"

    # Combine year, month, and day into the new end_date
    end_date="${end_year}/${end_month}/${end_day}"

    # Straight line
    echo -ne "$color_line"
    printf '%.s─' $(seq 1 $(tput cols))
    echo -e "$reset"

    printf -v month_zero '%02d' "$month"

    l0= l1= l2=

    IFS=";"
    # Declare the array "months" (locale names)
    declare -a months
    months=($(locale -k LC_TIME | grep ^abmon | cut -d= -f2 | tr -d '"'))
    unset IFS

    weekend_days=$(cal -m | awk 'NF==7{print $(NF-1),$NF}')
    weekend_days=${weekend_days//[![:alpha:]]}

    while
      for field in a d m; do printf -v "$field" "%(%-$field)T" "$s"; done
      ((month == m))
    do
      if [[ $d -lt 13 ]]; then
        if [[ $d -lt $month ]]; then
            printf -v l0 "%s${color_past_dates}%-8s${reset}" "$l0" "${months[$d-1]}"
        elif [[ $d -gt $month ]]; then
            printf -v l0 "%s${color_future_dates}%-8s${reset}" "$l0" "${months[$d-1]}"
        else
            printf -v l0 "%s${color_current_month}%-8s${reset}" "$l0" "${months[$d-1]}"
        fi
      fi

      (( ${#a} > 2 )) && a="${a:0:2}"
      printf -v d_zero '%02d' "$d"

      if [[ 10#$d -lt 10#$day ]]; then
        printf -v l1 "%s${color_past_dates}%-2s${reset} " "$l1" "$a"
        printf -v l2 "%s${color_past_dates}%+2s${reset} " "$l2" "$d"
      elif [[ 10#$d -gt 10#$day ]]; then
        if [[ "$weekend_days" == *"$a"* ]]; then
          if [[ -n $end_date ]] && [[ "$end_date" == "$year/$month_zero/$d_zero" ]]; then
            printf -v l1 "%s${color_deadline}%-2s${reset} " "$l1" "$a"
            printf -v l2 "%s${color_deadline}%+2s${reset} " "$l2" "$d"
          else
            printf -v l1 "%s${color_weekends}%-2s${reset} " "$l1" "$a"
            printf -v l2 "%s${color_weekends}%+2s${reset} " "$l2" "$d"
          fi
        elif [[ -n $end_date ]] && [[ "$end_date" == "$year/$month_zero/$d_zero" ]]; then
          printf -v l1 "%s${color_deadline}%-2s${reset} " "$l1" "$a"
          printf -v l2 "%s${color_deadline}%+2s${reset} " "$l2" "$d"
        else
          printf -v l1 '%s%-2s ' "$l1" "$a"
          printf -v l2 '%s%+2s ' "$l2" "$d"
        fi
      else
        if [[ -n $end_date ]] && [[ "$end_date" == "$year/$month_zero/$d_zero" ]]; then
          printf -v l1 "%s${color_deadline}%-2s${reset} " "$l1" "$a"
          printf -v l2 "%s${color_deadline}%+2s${reset} " "$l2" "$d"
        else
          printf -v l1 "%s${color_today}%-2s${reset} " "$l1" "$a"
          printf -v l2 "%s${color_today}%+2s${reset} " "$l2" "$d"
        fi
      fi
      ((s += 86400))
    done

    # Print the calendar
    printf '%s\n%s\n%s\n' "$l0" "$l1" "$l2"
    export TZ=$original_tz
}

# Set the deadline in the following format: YYYY/MM/DD
# NOTE: The value is validated then stored in `./.deadline`
set_dcal() {
    YELLOW="\033[0;33m"
    NC="\033[0m"
    SCRIPTPATH="$(
        cd -- "$(dirname "$0")" >/dev/null 2>&1
        pwd -P
    )"
    deadline=$(head -n 1 ${SCRIPTPATH}/.deadline)
    prompt_bash="Enter a new deadline"
    sample="YYYY/MM/DD"
    prompt_bash2="or '${YELLOW}none${NC}'"
    prompt_zsh="Enter a new deadline [%B%F{yellow}${sample}%f or '%B%F{yellow}none%f']: "
    if [[ ! $deadline =~ ^[0-9]{4}\/[0-9]{2}\/[0-9]{2}$ ]]; then
        deadline=""
    fi

    confirmed_date=${1}
    if [ -n "$confirmed_date" ]; then
        DEADLINE="${confirmed_date}"
    else
        if [ -n "$BASH_VERSION" ]; then
            echo -ne "$prompt_bash"
            read -ei "$deadline" -p " [$(echo -e "${YELLOW}${sample}${NC} ${prompt_bash2}")]: " DEADLINE
        else
            vared -ep "${prompt_zsh}" deadline
            DEADLINE=$deadline
        fi
    fi

    DEADLINE=${DEADLINE:-"$deadline"}


    if [[ $DEADLINE =~ ^[0-9]{4}\/[0-9]{2}\/[0-9]{2}$ ]]; then
        if ! date -d "$DEADLINE" &> /dev/null; then
            echo -ne "Invalid date format: ${DEADLINE}\n"
            exit 1
        else
            locale_fmt=$(locale -k LC_TIME | grep ^d_fmt | cut -d= -f2 | tr -d '"' | sed -e 's/y/Y/')
            DEADLINE_FMT=$(date -d $DEADLINE "+${locale_fmt}")
            echo $(expr '(' $(date -d $DEADLINE +%s) - $(date +%s) + 86399 ')' / 86400) " days until deadline ($DEADLINE_FMT)"
            set +o noclobber
            echo $DEADLINE >${SCRIPTPATH}/.deadline
            set -o noclobber
        fi
    elif [[ "$DEADLINE" == "none" ]]; then
        set +o noclobber
        echo "" >${SCRIPTPATH}/.deadline
        set -o noclobber
        echo -ne "No deadline.\n"
    else
        echo -ne "Invalid date format: ${DEADLINE}\n"
        exit 1
    fi
}
