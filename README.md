# dline
Bash/zsh calendar that displays a deadline and calculates the time left

![2023-02-28_00-50](https://user-images.githubusercontent.com/411471/221715818-860d8173-d00e-49d0-9e50-8786c8e5dfe9.png)

## Usage:

**dline** is a simple yet powerful bash script that serves as a visual calendar. Compatible with both bash and zsh, this script can help you stay on top of your deadlines and keep track of your time effectively. The recommended workflow is to set your deadline using the command line: 

```bash
dline -s [year/month/day]
```

If the optional date argument is missing or invalid, interactive mode is called. This creates a file in the same directory your project resides and is called `.deadline` which stores your current deadline. Finally, run:

```bash
dline
```

anytime you want to display your calendar. Yes, it's that simple.

## Summary:

The script calculates the total number of days, including work days, until your deadline and shows the progress of the year in terms of days passed, week number, and percent. If there's no deadline set, the script counts the remaining days until the next New Year. The calendar is displayed in a minimalistic format, taking up only a few lines on the screen, making it easy to keep track of your time and deadlines.

You could even translate or change all the output strings to your desired language. Just create a new file `.dlinerc` then copy the associative array `$MSG` from the `calendar.sh` and modify it to your liking, e.g.:

```bash
MSG['progress']="Proteklo"
MSG['day']="Dan"
MSG['week']="Tjedan"
MSG['today']="Danas"
MSG['time']="Vrijeme"
MSG['day_singular']="dan"
MSG['day_plural']="dana"
MSG['days_until_the']="dana do"
MSG['new_year']="Nove Godine"
MSG['work_days_left']="preostalih radnih dana"
MSG['days_until_deadline']="dana do roka"
MSG['until_the']="do"
MSG['until_deadline']="do roka"
MSG['happy_new_year']="Sretan Božić! 🎄"
MSG['soon']="Požurimo! 😊"
MSG['overdue']="Prekoračeno (u danima)"
```

---

Visualizing time is crucial in making the most of every moment and reaching your goals efficiently.
