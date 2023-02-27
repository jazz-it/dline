# Display of a simple calendar
dcal() {
    # Get the current date
    SCRIPTPATH="$(
        cd -- "$(dirname "$0")" >/dev/null 2>&1
        pwd -P
    )"

    IFS="/"
    output1=$(date "+%Y/%m/%d/%j/%V/%A/%s/%X")
    # Use the read command to split the output into separate variables
    read year month day day_of_year current_week day_name start_timestamp current_time <<< "$output1"

    output2=$(date -d "${year}/12/31" "+%s/%V")
    read last_day_timestamp total_weeks <<< "$output2"
    unset IFS

    current_date="${year}/${month}/${day}"
    current_date_formatted=$(date "+$(locale -k LC_TIME | grep ^d_fmt | cut -d= -f2 | tr -d '"' | sed -e 's/y/Y/')")
    
    # Define colors for past, present, and future
    alert="\033[0;31m"               # Red
    color_past_dates="\033[1;34m"    # Light Blue
    color_today="\033[7;33;34m"      # Light Blue inverted
    color_future_dates=""            # Default terminal color
    color_weekends="\033[0;35m"      # Magenta
    color_deadline="\033[0;45m"      # Inverted Magenta
    color_current_month="\033[0;33m" # Yellow
    color_line="\033[0;30m"          # Dark gray
    reset="\033[0m"                  # Reset color

    if [[ ! -e ${SCRIPTPATH}/.deadline ]]; then
        touch ${SCRIPTPATH}/.deadline
    fi
    end_date_input=$(head -n 1 ${SCRIPTPATH}/.deadline)
    if ! [[ $end_date_input =~ ^[0-9]{4}\/[0-9]{2}\/[0-9]{2}$ ]]; then
        end_date_input="$((year + 1))/01/01"
        end_date_formatted="New Year $((year + 1))"
    else
        end_date_formatted=$(date -d "$end_date_input" "+$(locale -k LC_TIME | grep ^d_fmt | cut -d= -f2 | tr -d '"' | sed -e 's/y/Y/')")
    fi

    # Get the total number of days in the current year
    if [ "$(date -d "${year}-02-29" +%Y-%m-%d 2>/dev/null)" = "${year}-02-29" ]; then
        total_days=366
    else
        total_days=365
    fi

    # Get the progress of the current year (values with leading zeros in bash are treated like octal numbers)
    percent=$((100 * $((10#$day_of_year)) / $total_days))

    # Print the required information
    printf "${color_current_month}Progress: %s%%    Day: %s/%03d    Week: %s/%02d    Date: %s %s    Time: %s${reset}\n" "$percent" $day_of_year $total_days $current_week $total_weeks $day_name "$current_date_formatted" "$current_time"

    end_timestamp=$(date -d "$end_date_input" +%s)

    passed_due_date=0
    start_date=$current_date
    end_date=$end_date_input
    
    # First day of the month (timestamp)
    s=$((start_timestamp - (day-1) * 86400))

    # Check if the start date is before the end date
    if [[ "$start_timestamp" -gt "$end_timestamp" ]]; then
        passed_due_date=1
        start=$start_timestamp
        start_timestamp=$end_timestamp
        end_timestamp=$start
        start_date=$end_date_input
        end_date=$current_date
    fi

    days=$(((end_timestamp - start_timestamp) / 86400))

    # Checking a proper use of singular vs. plural: day(s)
    sp="days"
    if [[ $days -eq 1 ]]; then
        sp="day"
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

    work_days=$((days - weekends))

    if [[ $passed_due_date -eq 0 ]]; then
        if [[ "$work_days" -ne "$days" ]]; then
            if [[ "$end_date_formatted" == *"New Year"* ]]; then
                printf "%s days until the %s  ·  %s work days left\n" $days "$end_date_formatted" $work_days
            else
                printf "%s days until deadline (%s)  ·  %s work days left\n" $days "$end_date_formatted" $work_days
            fi
        else
            if [[ "$end_date_formatted" == *"New Year"* ]]; then
                printf "%s %s until the %s  ·  Yaaaay! 😊\n" $work_days $sp "$end_date_formatted"
            else
                printf "%s %s until deadline (%s)  ·  Hurry up! 😊\n" $work_days $sp "$end_date_formatted"
            fi
        fi
    else
        printf "${alert}Time overdue (in days): %s${reset}\n" "$days"
    fi

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
            printf -v l0 '%s%-8s' "$l0" "${months[$d-1]}"
        else
            printf -v l0 "%s${color_current_month}%-8s${reset}" "$l0" "${months[$d-1]}"
        fi
      fi

      (( ${#a} > 2 )) && a="${a:0:2}"
      printf -v d_zero '%02d' "$d"

      if [[ $d -lt $day ]]; then
        printf -v l1 "%s${color_past_dates}%-2s${reset} " "$l1" "$a"
        printf -v l2 "%s${color_past_dates}%+2s${reset} " "$l2" "$d"
      elif [[ $d -gt $day ]]; then
        if [[ "$weekend_days" == *"$a"* ]]; then
          if [[ endDate_exists -eq 1 ]] && [[ $endDate == "$year/$month_zero/$d_zero" ]]; then
            printf -v l1 "%s${color_deadline}%-2s${reset} " "$l1" "$a"
            printf -v l2 "%s${color_deadline}%+2s${reset} " "$l2" "$d"
          else
            printf -v l1 "%s${color_weekends}%-2s${reset} " "$l1" "$a"
            printf -v l2 "%s${color_weekends}%+2s${reset} " "$l2" "$d"
          fi
        elif [[ endDate_exists -eq 1 ]] && [[ $endDate == "$year/$month_zero/$d_zero" ]]; then
          printf -v l1 "%s${color_deadline}%-2s${reset} " "$l1" "$a"
          printf -v l2 "%s${color_deadline}%+2s${reset} " "$l2" "$d"
        else
          printf -v l1 '%s%-2s ' "$l1" "$a"
          printf -v l2 '%s%+2s ' "$l2" "$d"
        fi
      else
        if [[ endDate_exists -eq 1 ]] && [[ $endDate == "$year/$month_zero/$d_zero" ]]; then
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
    sample="YYYY/MM/DD"
    prompt_bash="Enter a new deadline"
    prompt_bash2="or 'none'"
    prompt_zsh="Enter a new deadline [%B%F{yellow}${sample}%f] or 'none': "
    if [[ ! $deadline =~ ^[0-9]{4}\/[0-9]{2}\/[0-9]{2}$ ]]; then
        deadline=""
    fi

    confirmed_date=${1}
    if [ -n "$confirmed_date" ]; then
        DEADLINE="${confirmed_date}"
    else
        if [ -n "$BASH_VERSION" ]; then
            echo -ne "$prompt_bash"
            read -ei "$deadline" -p " [$(echo -e "${YELLOW}${sample}${NC}")] ${prompt_bash2}: " DEADLINE
        else
            vared -ep "${prompt_zsh}" deadline
            DEADLINE=$deadline
        fi
    fi

    DEADLINE=${DEADLINE:-"$deadline"}

    if [[ $DEADLINE =~ ^[0-9]{4}\/[0-9]{2}\/[0-9]{2}$ ]]; then
        DEADLINE_FMT=$(date -d $DEADLINE +"%d.%m.%Y")
        echo $(expr '(' $(date -d $DEADLINE +%s) - $(date +%s) + 86399 ')' / 86400) " days until deadline ($DEADLINE_FMT)"
        set +o noclobber
        echo $DEADLINE >${SCRIPTPATH}/.deadline
        set -o noclobber
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
