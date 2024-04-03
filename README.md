
# dLine

<img align="left" src="https://i.imgur.com/WbhVnb5.png" height="127" alt="Logo"> dLine is a versatile command-line tool that presents important data in the form of a calendar directly within your terminal. It monitors critical dates, simplifies event addition via APIs, and calculates timespans for various event types. 

Designed for developers, dLine streamlines event management and schedule navigation without requiring you to leave the terminal.

## Features

![Features](https://i.imgur.com/RphflCb.png)

- Dynamic View:
When you execute `dline` without any arguments, it promptly shows the events scheduled for the current month. Previous dates are shaded in blue, emphasizing future events. Event types are color-coded for easy identification, and icons provide visual cues. Additionally, you can swiftly hide specific categories to achieve a cleaner display—more details on this feature will follow. Events are neatly organized by week, with a clear separation between the first and second halves of the month.

It's the default View and is named for its automated processes that operate in the background, independent of user input.

- Static View:
When you run `dline -m yyyy/mm`, it enters Static View mode. Unlike the more dynamic counterpart, Static View remains stationary, making it ideal for users who simply require a monthly calendar. In this mode, the calendar displays events for the selected month, following the same configuration as Dynamic View. However, it stands out with a no-header design, omitting any additional embellishments. Notably, past dates are not shaded, ensuring a consistent and uninterrupted view of the entire month.

- Event Calculator View:
If you require a rapid day count, simply input `dline -w` along with your specified date range. This command spares you the monotony of manual finger counting. dLine streamlines your life by categorizing events into weekdays and weekends, subsequently providing a summarized total. It’s the sort of arithmetic that computers handle effortlessly, yet proves frustratingly time-consuming for us humans—especially when calculating sick days or determining the number of holidays you can relish without work.

- Administration:
Initiate File Management with a simple `dline -b` command. Think of "b" not just as "base", but as the branching point for your calendar configurations. Engage with the full spectrum of CRUD operations to craft and manage multiple calendar datasets. Whether you're part of an international team or freelancing across borders, switching contexts is seamless. And for those working globally, keeping track of Public Holidays across different countries is now just a few keystrokes away. Data Management in dLine is a suite of flags that enhance your control. Run `dline -h` to explore them. You'll find options to tackle overdue deadlines, initiate API imports, force updates, and manage your data with edit, delete, view, and clean commands. There's even a way to terminate all reminder processes.

On its initial launch, dLine will prompt you to select your subregion. This allows it to fetch Public and School Holidays specific to your area.

## Introduction on YouTube:
[![Introduction to dLine](https://i.imgur.com/fH5OK6P.png)](https://www.youtube.com/shorts/aZMAY2oSTks)

## Screenshots

Dynamic View
![Dynamic View](https://i.imgur.com/mtJPxxb.png)

Static View
![Static View](https://i.imgur.com/QdCaOBa.png)

Event Calculator View
![Event Calculator View](https://i.imgur.com/qsISzkF.png)

Admin
![File & Data Management](https://i.imgur.com/huT1gaL.png)

## Documentation

```
Usage:
 dline -a                                                     Add event (interactive mode)
 dline -a 2024/04/17 3 "11:30 Lunch with Lucy"                Add event directly
 dline                                                        Show current month calendar

Options:
 -a, --add [yyyy/mm/dd] [x] [desc]                            Add event. No args invokes interactive mode
 -b, --base                                                   Manage your data, as snapshots of your changes
                                                              (file management)
 -c, --clean                                                  Remove old entries
 -d, --delete [GCA|OHA|pattern]                               Delete imported calendars, or local matching entries.
 -e, --export                                                 Export calendar to TSV format
 -f, --filter [x] [x] ...                                     Toggle visibility of one or more categories
 -h, --help                                                   Show help
 -i, --import [TSV|GCA|OHA]                                   Import events from external sources
 -k, --kill                                                   Terminate pending reminders
 -l, --legend                                                 Toggle legend display
 -m, --month [yyyy/mm]                                        Show monthly calendar
 -o, --open                                                   Open data file in terminal editor
 -p, --print-details                                          Toggle calendar details
 -r, --resolve                                                Interactive dialogue to resolve deadlines
 -s, --school [0|1]                                           Set school holidays as work days (0) or holidays (1)
 -t, --test [yyyy/mm/dd]                                      Set "today" for testing
 -u, --update [GCA|OHA] | [pattern] [yyyy/mm/dd] [x] [desc]   Update from APIs or local matching entries
 -v, --version                                                Show version
 -w, --workdays [start_date] [end_date]                       Calculate workdays from optional start_date
                                                              (default: today) to end_date
 -x, --xdg-open                                               Open data file in GUI editor

Event categories [x]:
  1: Deadline
  2: Work
  3: Personal
  4: Birthday & Anniversary
  5: Public Holiday
  6: Vacation
  7: Sick Leave
  8: School Holiday
```

### Default View:

1. Automated Processes:
- The Dynamic View operates autonomously, continuously monitoring your calendar data.
- It doesn’t require explicit user input; hence, the name “Dynamic.”
2. Countdown to Deadlines:
- The background processes diligently search for the most relevant deadlines.
- It looks ahead into the foreseeable future, spanning up to 6 months or until the end of the current year (whichever is further), scanning for unresolved deadlines.
- Additionally, it scans the relevant past, reaching up to 1 month ago, searching for overdue deadlines.
- The goal? To present you with a countdown to the nearest most important unresolved event.
3. Foreseeable Events:
- Beyond deadlines, the Dynamic View also identifies other crucial events.
- It anticipates events that require your attention within a specific timeframe—up to 48 hours ahead.
- If such events exist, it creates a time trigger for pop-up notifications.
- Even if you restart your PC, these countdowns persist, thanks to the `at` command.
4. Maintenance and Updates:
- The Dynamic View handles routine maintenance tasks.
- Cleanups: Removing outdated or irrelevant data.
5. Automatic Updates: Fetching fresh calendar events from APIs.
- You can configure the timing and frequency of these processes through the `.dlinerc` file.
- User translations and custom color schemes are also supported, ensuring a personalized experience.

In summary, the Dynamic View is your new default, proactive calendar companion, silently managing deadlines, events, and data hygiene.

#### Categories Filtration:
Use `dline -f` and input the category codes you wish to view or hide (e.g. `dline -f 4 6 8`). This feature simplifies your calendar, allowing you to focus on the categories that matter most to you at any given time.

#### Config Files:

- `.dlinerc`: system-wide settings like user translations, color themes, cleanup frequencies
- `settings.json`: calendar-specific preferences

#### Data File:

- `events_data.txt`: Default data file, but upon creation of a new calendar, a file with a prefix is added. It's possible to switch between the existing calendars by `dline -b` > `Select`.
## Installation

#### Required Dependencies:
Clone the repository as usual and install the following projects prior to the very first run:

```
https://salsa.debian.org/debian/at
https://github.com/jqlang/jq
```

### Optional Dependencies (recommended):

```
https://github.com/insanum/gcalcli
https://github.com/junegunn/fzf
https://github.com/pyrho/hack-font-ligature-nerd-font
```
With the right setup, dLine could integrate with your Google Calendar. By aligning your calendar categories with dLine's system, you can import events directly, making your schedule accessible locally or via Google Calendar, according to your preference. [Important resolution of a relevant issue](https://github.com/insanum/gcalcli/issues/674#issuecomment-1890388400).

### Credits:

Holiday data based on [OpenHolidays API](https://www.openholidaysapi.org/)

## Usage/Examples

```bash
dline -a 2024/07/04 3 Buy milk
```
- Adding a new event (`yyyy/mm/dd x desc`), where `x` is the category code, `desc` is an arbitrary description with a special case where the description may start with `hh:mm` time format (which will eventually trigger a scheduled reminder as a popup) and may end with any hashtag (e.g. `#projectX`) for easier event handling related to a single topic.


```bash
dline -d "#projectX"
```
- Deleting all events tagged with `#projectX`.


```bash
dline -f 4 6 8
```
- Toggling visibility of events with codes 4 (Birthday & Anniversary), 6 (Vacation) and 8 (School Holiday).


```bash
dline -i GCA
```
- Triggers an import of calendar(s) from Google Calendar in interractive mode. Read the docs from the project `gcalcli` first. The same operation will be triggered during the very first run, so you may want to run it again if you need to import a new calendar.


```bash
dline -s 1
```
- In case you're a student, run this to make sure your School Holidays are shown as days off, not as work days.


```bash
dline -s 0
```
- If you’re a parent, use this command to view School Holidays in your region as regular work days. It serves as a reminder to stay informed about when your kids will be off from school.


```bash
dline -m 2024/10
```
- Displaying a static monthly calendar, without triggering any automatic background process.


```bash
dline -w 2024/01/01 2024/12/31
```
- Once you’ve added all your calendars to dLine, you can utilize the command above to assess a specific timespan. It helps you determine the number of distinct event categories within your specified time range. This feature proves especially useful for freelancers who charge based on workdays—allowing them to calculate holidays, sick days, weekends, and workdays before providing quotes to their clients.

## Appendix

Visualizing time is crucial in making the most of every moment and reaching your goals efficiently. Even small distractions derail productivity.

## Easter Egg Alert
Attention, curious devs! We’ve hidden a harmless Easter Egg surprise in this project. No backdoors, promise! Hunt it down and earn a spot in our "Hall of Fame". Happy coding! 🚀
