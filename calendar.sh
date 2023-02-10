# Display of a simple calendar
dcal() {
    # Get the current date
    SCRIPTPATH="$(
        cd -- "$(dirname "$0")" >/dev/null 2>&1
        pwd -P
    )"
    current_date=$(date +"%Y/%m/%d")
    current_date_formatted=$(date -d "$current_date" +%d.%m.%Y)

    # Get the current Unix timestamp
    timestamp=$(date +%s)

    # Split the current date into year, month and day
    year=$(date -d @$timestamp +%Y)
    month=$(date -d @$timestamp +%m)
    day=$(date -d @$timestamp +%d)

    # Define colors for past, present, and future
    alert="\033[0;31m"               # Red
    color_past_dates="\033[1;34m"    # Light Blue
    color_today="\033[7;33;34m"      # Light Blue inverted
    color_future_dates=""            # Default terminal color
    color_weekends="\033[0;35m"      # Magenta
    color_deadline="\033[0;45m"      # Inverted Magenta
    color_current_month="\033[0;33m" # Yellow
    reset="\033[0m"                  # Reset color

    # Initialize the lists of the names of all 12 monts
    l0=("Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec")
    # List of all names of the days of the current month
    l1=""

    # List of all dates of the current month
    l2=($(seq 1 $(cal "$month" "$year" | awk 'NF {DAYS = $NF}; END {print DAYS}')))
    # List of all formatted dates of the current month, marked with proper colors
    l2_fmt=""

    if [[ ! -e ${SCRIPTPATH}/.deadline ]]; then
        touch ${SCRIPTPATH}/.deadline
    fi
    end_date_input=$(head -n 1 ${SCRIPTPATH}/.deadline)
    if ! [[ $end_date_input =~ ^[0-9]{4}\/[0-9]{2}\/[0-9]{2}$ ]]; then
        end_date_input="$((year + 1))/01/01"
    else
        end_date_formatted=$(date -d "$end_date_input" +%d.%m.%Y)
    fi

    # Get the current day of the year
    # day_of_year=$(date -d "$current_date" +%j)
    day_of_year=$(date -d @$timestamp +%j)

    # Get the total number of days in the current year
    if [ "$(date -d "${year}-02-29" +%Y-%m-%d 2>/dev/null)" = "${year}-02-29" ]; then
        total_days=366
    else
        total_days=365
    fi

    # Get the progress of the current year (values with leading zeros in bash are treated like octal numbers)
    percent=$((100 * $((10#$day_of_year)) / $total_days))

    # Get the current week number
    current_week=$(date -d @$timestamp +%V)

    # Get the timestamp of the last day of the current year
    last_day_timestamp=$(date -d "${year}/12/31" +%s)

    # Get the week number of the last day of the current year
    total_weeks=$(date -d @$last_day_timestamp +%V)

    # Get the full name of the current day
    day_name=$(date -d "$current_date" +%A)

    # Get the current time
    current_time=$(date +%X)

    # Print the required information
    printf "${color_current_month}Progress: %s%%    Day: %s/%03d    Week: %s/%02d    Date: %s %s    Time: %s${reset}\n" "$percent" $day_of_year $total_days $current_week $total_weeks $day_name "$current_date_formatted" "$current_time"

    start_timestamp=$(date -d "$current_date" +%s)
    end_timestamp=$(date -d "$end_date_input" +%s)

    passed_due_date=0
    start_date=$current_date
    end_date=$end_date_input
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

    weekends=$(((days + $(date -d "$start_date" +%u) - 1) / 7 * 2))

    # Check if the start date is a weekend day
    if [ $(date -d "$start_date" +%u) -eq 7 ]; then
        weekends=$((weekends - 2))
    elif [ $(date -d "$start_date" +%u) -eq 6 ]; then
        weekends=$((weekends - 1))
    fi

    # Check if the end date is a weekend day
    if [ $(date -d "$end_date" +%u) -eq 7 ]; then
        weekends=$((weekends + 2))
    elif [ $(date -d "$end_date" +%u) -eq 6 ]; then
        weekends=$((weekends + 1))
    fi

    work_days=$((days - weekends))

    if [[ $passed_due_date -eq 0 ]]; then
        if [[ "$work_days" -ne "$days" ]]; then
            printf "%s days until deadline (%s)  ·  %s work days left\n" $days $end_date_formatted $work_days
        else
            printf "%s %s until deadline (%s)  ·  Hurry up! 😊\n" $work_days $sp $end_date_formatted
        fi
    else
        printf "${alert}Time overdue (in days): %s${reset}\n" "$days"
    fi

    # Straight line
    printf '%.s─' $(seq 1 $(tput cols))

    # Loop over the days of the month and add their names to l1
    i=0
    current_date_seconds=$(date -d "$current_date" +%s)

    for ((i = 1; i <= ${#l2[@]}; i++)); do
        date_of_month="$year-$month-$(printf "%02d" "$i")"
        iteration_date=$(date -d "$date_of_month" +"%Y/%m/%d")
        iteration_date_seconds=$(date -d "$date_of_month" +%s)
        name_of_day=$(date -d "$date_of_month" +"%a")
        iteration_dow=$(date -d "$date_of_month" +%u)

        if [ $((10#${l2[1]} - 1)) -le $((10#$i)) ] && [ $((10#$i)) -lt $((10#$day)) ]; then
            l1="${l1}${color_past_dates}${name_of_day:0:2}${reset} "
            if [ $i -lt 10 ]; then
                l2_fmt="${l2_fmt} ${color_past_dates}${i}${reset} "
            else
                l2_fmt="${l2_fmt}${color_past_dates}${i}${reset} "
            fi
        elif [[ "$iteration_date" == "$end_date_input" ]]; then
            l1="${l1}${color_deadline}${name_of_day:0:2}${reset} "
            if [ $i -lt 10 ]; then
                l2_fmt="${l2_fmt} ${color_deadline}${i}${reset} "
            else
                l2_fmt="${l2_fmt}${color_deadline}${i}${reset} "
            fi
        elif [ $((10#$i)) -eq $((10#$day)) ]; then
            l1="${l1}${color_today}${name_of_day:0:2}${reset} "
            if [ $i -lt 10 ]; then
                l2_fmt="${l2_fmt}${color_today} ${i}${reset} "
            else
                l2_fmt="${l2_fmt}${color_today}${i}${reset} "
            fi
        elif [[ $iteration_date_seconds -gt $current_date_seconds ]] && [[ $iteration_dow -gt 5 ]]; then
            l1="${l1}${color_weekends}${name_of_day:0:2}${reset} "
            if [ $i -lt 10 ]; then
                l2_fmt="${l2_fmt} ${color_weekends}${i}${reset} "
            else
                l2_fmt="${l2_fmt}${color_weekends}${i}${reset} "
            fi
        else
            l1="${l1}${color_future_dates}${name_of_day:0:2}${reset} "
            if [ $i -lt 10 ]; then
                l2_fmt="${l2_fmt} ${color_future_dates}${i}$reset "
            else
                l2_fmt="${l2_fmt}${color_future_dates}${i}$reset "
            fi
        fi
    done

    # Arrays in zsh are indexed starting 1, unlike bash who index them starting 0
    if ! [[ $l0[0] ]]; then
        min=1
        max=12
    else
        min=0
        max=11
        month=$((month - 1))
    fi

    # Print the calendar: list of months
    for ((i = ${min}; i <= ${max}; i++)); do
        if [[ $i -lt $month ]]; then
            printf "$color_past_dates%s%4s$reset " "${l0[$i]}" ""
        elif [[ $i -eq $month ]]; then
            printf "$color_current_month%s%4s$reset " "${l0[$i]}" ""
        else
            printf "$color_future_dates%s%4s$reset " "${l0[$i]}" ""
        fi
    done

    l1="\n${l1}\n"
    l2_fmt="${l2_fmt}\n"

    # Print the dates of the current month
    echo -e "$l1$l2_fmt"
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
    prompt_zsh="Enter a new deadline [%B%F{yellow}${sample}%f]: "
    if [[ ! $deadline =~ ^[0-9]{4}\/[0-9]{2}\/[0-9]{2}$ ]]; then
        deadline=""
    fi
    if [ -n "$BASH_VERSION" ]; then
        echo -ne "$prompt_bash"
        read -ei "$deadline" -p " [$(echo -e "${YELLOW}${sample}${NC}")]: " DEADLINE
    else
        vared -ep "${prompt_zsh}" deadline
        DEADLINE=$deadline
    fi
    DEADLINE=${DEADLINE:-"$deadline"}

    if [[ $DEADLINE =~ ^[0-9]{4}\/[0-9]{2}\/[0-9]{2}$ ]]; then
        {
            DEADLINE_FMT=$(date -d $DEADLINE +"%d.%m.%Y")
            echo $(expr '(' $(date -d $DEADLINE +%s) - $(date +%s) + 86399 ')' / 86400) " days until deadline ($DEADLINE_FMT)"
            set +o noclobber
            echo $DEADLINE >${SCRIPTPATH}/.deadline
            set -o noclobber
        }
    else
        {
            set +o noclobber
            echo '' >${SCRIPTPATH}/.deadline
            set -o noclobber
            echo "No deadline."
        }
    fi
}
