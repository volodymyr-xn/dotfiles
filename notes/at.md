```bash
at 9:00 AM
at> sh backup.sh
at> ^d
job 3 at 2013-03-23 09:00
```
or

```bash
echo "sh backup.sh" | at 9:00 AM
```

```bash
at -f myjobs.txt now + 1 hour
```

In the following example, let us run a new at job using queue “z”:
```bash
at -q z -f /root/myjobs.txt now + 1 hour
```

`atq` - list of scheduled jobs
`atrm` - remove scheduled job by job id
`at -c 5` - check the content

```bash
at 10:00 AM Sun
at 10:00 AM July 25
at 10:00 AM 6/22/2015
at 10:00 AM 6.22.2015
at 10:00 AM next month
at 10:00 AM tomorrow

at now + 1 hour
at now + 30 minutes

at now + 1 week
at now + 2 weeks

at midnight
```


