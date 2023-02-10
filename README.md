# dline
Bash/zsh calendar that displays a deadline and calculates the time left

![dline2](https://user-images.githubusercontent.com/411471/217948366-1549e86d-e679-424e-956d-c0285ad24f8a.png)

## Usage:

**dline** is a simple yet powerful bash script that serves as a visual calendar. Compatible with both bash and zsh, this script can help you stay on top of your deadlines and keep track of your time effectively. The recommended workflow is to set your deadline using the command line: 

```zsh
dline --set
```

followed by entering the targeted date in "YYYY/MM/DD" format. This creates a file in the same directory your project resides and is called `.deadline` which stores your current deadline. Finally, run:

```zsh
dline
```

anytime you want to display your calendar. Yes, it's that simple.

## Summary:

The script calculates the total number of days, including work days, until your deadline and shows the progress of the year in terms of days passed, week number, and percent. If there's no deadline set, the script counts the remaining days until the next New Year. The calendar is displayed in a minimalistic format, taking up only a few lines on the screen, making it easy to keep track of your time and deadlines.

---

Visualizing time is crucial in making the most of every moment and reaching your goals efficiently.
