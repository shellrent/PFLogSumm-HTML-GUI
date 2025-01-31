
# PFLogSumm-HTML-GUI

Bash shell script to Generate POSTFIX statistics HTML report using pflogsumm as the backend

The script processes the pflogsumm output to an easy to view HTML report

## Screenshots of the web interface

![Screenshot1](https://github.com/shellrent/PFLogSumm-HTML-GUI/blob/master/Screenshots/Screenshot1.png)

![Screenshot2](https://github.com/shellrent/PFLogSumm-HTML-GUI/blob/master/Screenshots/Screenshot2.png)

## Requirements

*pflogsumm* needs to be installed

For RedHat based operating systems

```bash
yum -y install postfix-perl-scripts 
```

For Ubuntu/Debian based operating systems

```bash
apt-get -y install pflogsumm 
```

## Script installation

You can clone or download the script direct to a location of your choice. Here is an example setup:

```bash
cd /opt
git clone https://github.com/RiaanPretoriusSA/PFLogSumm-HTML-GUI.git
```

## Script updates

If you want to update to the latest version you can run this (provided you used GIT to install)

```bash
cd /opt/PFLogSumm-HTML-GUI
git pull
```

That will ensure the latest version

## Configuration

On first time run the script will automatically  create the default configuration file: /etc/pflogsumui.conf

```text
#PFLOGSUMUI CONFIG

##  Postfix Log Location
LOGFILELOCATION="/var/log/maillog"

##  pflogsumm details
PFLOGSUMMOPTIONS=" --verbose_msg_detail --zero_fill "
PFLOGSUMMBIN="/usr/sbin/pflogsumm  "

##  HTML Output
HTMLOUTPUTDIR="/var/www/html/"
HTMLOUTPUT_INDEXDASHBOARD="index.html"

```

The parts that might need changing according to your environment  is:

LOGFILELOCATION and HTMLOUTPUTDIR

The default locations are REDHAT/CENTOS based operating systems

## Create a crontab

The script needs to run once a day to update the reports using CRON. Note, the scripts need access to the maillog as root or a SUDO user with access to the maillog and web directories.

### Example crontab entry for 11:50 PM

Because we want the report for the previous day, we run this report one minute before midnight

```text
50 11 * * * /opt/PFLogSumm-HTML-GUI/pflogsummUIReport.sh >/dev/null 2>&1
```

## Note about ZIMBRA (if you are using it)

Zimbra: The World's Leading Open Source Email Collaboration Solution

Zimbra installs its own pflogsumm script. If you want to use that script instead you can create a symlink to fix the script paths

```bash
ln -s /opt/zimbra/common/bin/pflogsumm.pl /usr/sbin/pflogsumm
```

# WARNING: The reports expose user email accounts. You MUST password protect the directory you are hosting the files in
