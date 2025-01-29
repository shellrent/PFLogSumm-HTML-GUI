#!/usr/bin/env bash
# Debug option - should be disabled unless required
#set -x
#=====================================================================================================================
#   DESCRIPTION  Generating a stand alone web report for postix log files, 
#                Runs on all Linux platforms with postfix installed
#   AUTHOR       Riaan Pretorius <pretorius.riaan@gmail.com>
#   IDIOCRACY    yes.. i know.. bash??? WTF was i thinking?? Well it works, runs every 
#                where and it is portable
#
#   https://en.wikipedia.org/wiki/MIT_License
#
#   LICENSE
#   MIT License
#
#   Copyright (c) 2025 Shellrent S.p.a.
#
#   Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
#   and associated documentation files  (the "Software"), to deal in the Software without restriction, 
#   including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, 
#   and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, 
#   subject to the following conditions:
#
#   The above copyright notice and this permission notice shall be included in all copies or substantial 
#   portions of the Software.
#
#   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT 
#   NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
#   IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
#   WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION  WITH THE SOFTWARE 
#   OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#=====================================================================================================================

#CONFIG FILE LOCATION
PFSYSCONFDIR="/etc"

#Create Blank Config File if it does not exist
if [ ! -f ${PFSYSCONFDIR}/"pflogsumui.conf" ]
then
tee ${PFSYSCONFDIR}/"pflogsumui.conf" <<EOF
#PFLOGSUMUI CONFIG

##  Postfix Log Location
LOGFILELOCATION="/var/log/maillog"

##  pflogsumm details
##  NOTE: DONT USE -d today - breaks the script
PFLOGSUMMOPTIONS=" --verbose_msg_detail --zero_fill "
PFLOGSUMMBIN="/usr/sbin/pflogsumm  "

##  HTML Output
HTMLOUTPUTDIR="/var/www/html/"
HTMLOUTPUT_INDEXDASHBOARD="index.html"

EOF
echo "DEFAULT configuration file writen to ${PFSYSCONFDIR}/pflogsumui.conf, Please verify the paths before you continue"
exit 0
fi

#Load Config File
# shellcheck source=/dev/null
. "${PFSYSCONFDIR}"/"pflogsumui.conf"


#Create the Cache Directory if it does not exist
if [ ! -d "$HTMLOUTPUTDIR"/data ]; then
  mkdir  "$HTMLOUTPUTDIR"/data;
fi

#TOOLS
ACTIVEHOSTNAME=$(cat /proc/sys/kernel/hostname)
MOVEF="/usr/bin/mv -f "

#Temporal Values
REPORTDATE=$(date '+%Y-%m-%d %H:%M:%S')
CURRENTYEAR=$(date +'%Y')
CURRENTMONTH=$(date +'%b')
CURRENTDAY=$(date +"%e")

# Absolute path to this script. /home/user/bin/foo.sh
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in. /home/user/bin
SCRIPTPATH=$(dirname "$SCRIPT")


# shellcheck disable=SC2086
$PFLOGSUMMBIN $PFLOGSUMMOPTIONS -e "$LOGFILELOCATION" > /tmp/mailreport


#Extract Sections from PFLOGSUMM
sed -n '/^Grand Totals/,/^Per-Hour/p;/^Per-Hour/q' /tmp/mailreport | sed -e '1,4d' | sed -e :a -e '$d;N;2,3ba' -e 'P;D' | sed '/^$/d' > /tmp/GrandTotals
sed -n '/^Per-Day Traffic Summary/,/^Per-Hour/p;/^Per-Hour/q' /tmp/mailreport | sed -e '1,4d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D'  > /tmp/PerDayTrafficSummary
sed -n '/^Per-Hour Traffic Daily Average/,/^Host\//p;/^Host\//q' /tmp/mailreport | sed -e '1,4d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D'  > /tmp/PerHourTrafficDailyAverage
sed -n '/^Host\/Domain Summary\: Message Delivery/,/^Host\/Domain Summary\: Messages Received/p;/^Host\/Domain Summary\: Messages Received/q' /tmp/mailreport | sed -e '1,4d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D'  > /tmp/HostDomainSummaryMessageDelivery
sed -n '/^Host\/Domain Summary\: Messages Received/,/^Senders by message count/p;/^Senders by message count/q' /tmp/mailreport | sed -e '1,4d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D'  > /tmp/HostDomainSummaryMessagesReceived
sed -n '/^Senders by message count/,/^Recipients by message count/p;/^Recipients by message count/q' /tmp/mailreport | sed -e '1,2d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D' | sed '/^$/d' > /tmp/Sendersbymessagecount
sed -n '/^Recipients by message count/,/^Senders by message size/p;/^Senders by message size/q' /tmp/mailreport | sed -e '1,2d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D' | sed '/^$/d' > /tmp/Recipientsbymessagecount
sed -n '/^Senders by message size/,/^Recipients by message size/p;/^Recipients by message size/q' /tmp/mailreport | sed -e '1,2d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D' | sed '/^$/d' > /tmp/Sendersbymessagesize
sed -n '/^Recipients by message size/,/^Messages with no size data/p;/^Messages with no size data/q' /tmp/mailreport | sed -e '1,2d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D' | sed '/^$/d' > /tmp/Recipientsbymessagesize
sed -n '/^Messages with no size data/,/^message deferral detail/p;/^message deferral detail/q' /tmp/mailreport | sed -e '1,2d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D' | sed '/^$/d' > /tmp/Messageswithnosizedata
sed -n '/^message deferral detail/,/^message bounce detail (by relay)/p;/^message bounce detail (by relay)/q' /tmp/mailreport | sed -e '1,2d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D' | sed '/^$/d' > /tmp/messagedeferraldetail
sed -n '/^message bounce detail (by relay)/,/^message reject detail/p;/^message reject detail/q' /tmp/mailreport | sed -e '1,2d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D' | sed '/^$/d' > /tmp/messagebouncedetaibyrelay
sed -n '/^Warnings/,/^Fatal Errors/p;/^Fatal Errors/q' /tmp/mailreport | sed -e '1,2d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D' | sed '/^$/d' > /tmp/warnings

sed -n '/^Fatal Errors/,/^Master daemon messages/p;/^Master daemon messages/q' /tmp/mailreport | sed -e '1,2d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D' | sed '/^$/d' > /tmp/FatalErrors


#======================================================
# Extract Information into variables -> Grand Totals
#======================================================
ReceivedEmail=$(awk '$2=="received" {print $1}'  /tmp/GrandTotals)
DeliveredEmail=$(awk '$2=="delivered" {print $1}'  /tmp/GrandTotals)
ForwardedEmail=$(awk '$2=="forwarded" {print $1}'  /tmp/GrandTotals)
DeferredEmailCount=$(awk '$2=="deferred" {print $1}'  /tmp/GrandTotals)
DeferredEmailDeferralsCount=$(awk '$2=="deferred" {print $3" "$4}'  /tmp/GrandTotals)
BouncedEmail=$(awk '$2=="bounced" {print $1}'  /tmp/GrandTotals)
RejectedEmailCount=$(awk '$2=="rejected" {print $1}'  /tmp/GrandTotals)
RejectedEmailPercentage=$(awk '$2=="rejected" {print $3}'  /tmp/GrandTotals)
RejectedWarningsEmail=$(sed 's/reject warnings/rejectwarnings/' /tmp/GrandTotals | awk '$2=="rejectwarnings" {print $1}')
HeldEmail=$(awk '$2=="held" {print $1}'  /tmp/GrandTotals)
DiscardedEmailCount=$(awk '$2=="discarded" {print $1}'  /tmp/GrandTotals)
DiscardedEmailPercentage=$(awk '$2=="discarded" {print $3}'  /tmp/GrandTotals)
BytesReceivedEmail=$(sed 's/bytes received/bytesreceived/' /tmp/GrandTotals | awk '$2=="bytesreceived" {print $1}'|sed 's/[^0-9]*//g' )
BytesDeliveredEmail=$(sed 's/bytes delivered/bytesdelivered/' /tmp/GrandTotals | awk '$2=="bytesdelivered" {print $1}'|sed 's/[^0-9]*//g')
SendersEmail=$(awk '$2=="senders" {print $1}'  /tmp/GrandTotals)
SendingHostsDomainsEmail=$(sed 's/sending hosts\/domains/sendinghostsdomains/' /tmp/GrandTotals | awk '$2=="sendinghostsdomains" {print $1}')
RecipientsEmail=$(awk '$2=="recipients" {print $1}'  /tmp/GrandTotals)
RecipientHostsDomainsEmail=$(sed 's/recipient hosts\/domains/recipienthostsdomains/' /tmp/GrandTotals | awk '$2=="recipienthostsdomains" {print $1}')


#======================================================
# Extract Information into variable -> Per-Day Traffic Summary
#======================================================
while IFS= read -r var
do
    PerDayTrafficSummaryTable=""
    PerDayTrafficSummaryTable+="<tr>"
    PerDayTrafficSummaryTable+=$(echo "$var" | awk '{print "<td>"$1" "$2" "$3"</td>""<td>"$4"</td>""<td>"$5"</td>""<td>"$6"</td>""<td>"$7"</td>""<td>"$8"</td>"}')
    PerDayTrafficSummaryTable+="</tr>"
    echo "$PerDayTrafficSummaryTable" >> /tmp/PerDayTrafficSummary_tmp
done < /tmp/PerDayTrafficSummary
$MOVEF  /tmp/PerDayTrafficSummary_tmp /tmp/PerDayTrafficSummary &> /dev/null

#======================================================
# Extract Information into variable -> Per-Hour Traffic Daily Average
#======================================================
while IFS= read -r var
do
    PerHourTrafficDailyAverageTable=""
    PerHourTrafficDailyAverageTable+="<tr>"
    PerHourTrafficDailyAverageTable+=$(echo "$var" | awk '{print "<td>"$1"</td>""<td>"$2"</td>""<td>"$3"</td>""<td>"$4"</td>""<td>"$5"</td>""<td>"$6"</td>"}')
    PerHourTrafficDailyAverageTable+="</tr>"
    echo "$PerHourTrafficDailyAverageTable" >> /tmp/PerHourTrafficDailyAverage_tmp
done < /tmp/PerHourTrafficDailyAverage
$MOVEF /tmp/PerHourTrafficDailyAverage_tmp /tmp/PerHourTrafficDailyAverage &> /dev/null


#======================================================
# Extract Information into variable -> Per-Hour Traffic Daily Average
#======================================================
while IFS= read -r var
do
    HostDomainSummaryMessageDeliveryTable=""
    HostDomainSummaryMessageDeliveryTable+="<tr>"
    HostDomainSummaryMessageDeliveryTable+=$(echo "$var" | awk '{print "<td>"$1"</td>""<td>"$2"</td>""<td>"$3"</td>""<td>"$4" "$5"</td>""<td>"$6" "$7"</td>""<td>"$8"</td>" }')
    HostDomainSummaryMessageDeliveryTable+="</tr>"
    echo "$HostDomainSummaryMessageDeliveryTable" >> /tmp/HostDomainSummaryMessageDelivery_tmp
done < /tmp/HostDomainSummaryMessageDelivery
$MOVEF /tmp/HostDomainSummaryMessageDelivery_tmp /tmp/HostDomainSummaryMessageDelivery &> /dev/null


#======================================================
# Extract Information into variable -> Host Domain Summary Messages Received
#======================================================
while IFS= read -r var
do
    HostDomainSummaryMessagesReceivedTable=""
    HostDomainSummaryMessagesReceivedTable+="<tr>"
    HostDomainSummaryMessagesReceivedTable+=$(echo "$var" | awk '{print "<td>"$1"</td>""<td>"$2"</td>""<td>"$3"</td>"}')
    HostDomainSummaryMessagesReceivedTable+="</tr>"
    echo "$HostDomainSummaryMessagesReceivedTable" >> /tmp/HostDomainSummaryMessagesReceived_tmp
done < /tmp/HostDomainSummaryMessagesReceived
$MOVEF /tmp/HostDomainSummaryMessagesReceived_tmp /tmp/HostDomainSummaryMessagesReceived &> /dev/null


#======================================================
# Extract Information into variable -> Host Domain Summary Messages Received
#======================================================
while IFS= read -r var
do
    SendersbymessagecountTable=""
    SendersbymessagecountTable+="<tr>"
    SendersbymessagecountTable+=$(echo "$var" | awk '{print "<td>"$1"</td>""<td>"$2"</td>"}')
    SendersbymessagecountTable+="</tr>"
    echo "$SendersbymessagecountTable" >> /tmp/Sendersbymessagecount_tmp
done < /tmp/Sendersbymessagecount
$MOVEF  /tmp/Sendersbymessagecount_tmp /tmp/Sendersbymessagecount &> /dev/null

#======================================================
# Extract Information into variable -> Recipients by message count
#======================================================
 while IFS= read -r var
do
    RecipientsbymessagecountTable=""
    RecipientsbymessagecountTable+="<tr>"
    RecipientsbymessagecountTable+=$(echo "$var" | awk '{print "<td>"$1"</td>""<td>"$2"</td>"}')
    RecipientsbymessagecountTable+="</tr>"
    echo "$RecipientsbymessagecountTable" >> /tmp/Recipientsbymessagecount_tmp
done < /tmp/Recipientsbymessagecount
$MOVEF /tmp/Recipientsbymessagecount_tmp /tmp/Recipientsbymessagecount &> /dev/null


#======================================================
# Extract Information into variable -> Senders by message size
#======================================================
 while IFS= read -r var
do
    SendersbymessagesizeTable=""
    SendersbymessagesizeTable+="<tr>"
    SendersbymessagesizeTable+=$(echo "$var" | awk '{print "<td>"$1"</td>""<td>"$2"</td>"}')
    SendersbymessagesizeTable+="</tr>"
    echo "$SendersbymessagesizeTable" >> /tmp/Sendersbymessagesize_tmp
done < /tmp/Sendersbymessagesize
$MOVEF /tmp/Sendersbymessagesize_tmp /tmp/Sendersbymessagesize &> /dev/null


#======================================================
# Extract Information into variable -> Recipients by messagesize Table
#======================================================
while IFS= read -r var
do
    RecipientsbymessagesizeTable=""
    RecipientsbymessagesizeTable+="<tr>"
    RecipientsbymessagesizeTable+=$(echo "$var" | awk '{print "<td>"$1"</td>""<td>"$2"</td>"}')
    RecipientsbymessagesizeTable+="</tr>"
    echo "$RecipientsbymessagesizeTable" >> /tmp/Recipientsbymessagesize_tmp
done < /tmp/Recipientsbymessagesize
$MOVEF /tmp/Recipientsbymessagesize_tmp /tmp/Recipientsbymessagesize &> /dev/null

#======================================================
# Extract Information into variable -> Recipients by messagesize Table
#======================================================
while IFS= read -r var
do
    MessageswithnosizedataTable=""
    MessageswithnosizedataTable+="<tr>"
    MessageswithnosizedataTable+=$(echo "$var" | awk '{print "<td>"$1"</td>""<td>"$2"</td>"}')
    MessageswithnosizedataTable+="</tr>"
    echo "$MessageswithnosizedataTable" >> /tmp/Messageswithnosizedata_tmp
    echo "$MessageswithnosizedataTable"
done < /tmp/Messageswithnosizedata
$MOVEF  /tmp/Messageswithnosizedata_tmp /tmp/Messageswithnosizedata  &> /dev/null

#======================================================
# Single PAGE INDEX HTML TEMPLATE
# Using embedded HTML makes the script highly portable
# SED search and replace tags to fill the content
#======================================================

INDEXDASHBOARD="$HTMLOUTPUTDIR/$HTMLOUTPUT_INDEXDASHBOARD"

cp "$SCRIPTPATH/Templates/index_dashboard_template.html" "$INDEXDASHBOARD"

CURRENTREPORT="$HTMLOUTPUTDIR"data/"$CURRENTYEAR"-"$CURRENTMONTH"-"$CURRENTDAY".html

cp "$SCRIPTPATH/Templates/Report_Template.html" "$CURRENTREPORT"

#======================================================
# Replace Placeholders with values - GrandTotals
#======================================================
sed -i "s/##REPORTDATE##/$REPORTDATE/g" "$CURRENTREPORT"
sed -i "s/##ACTIVEHOSTNAME##/$ACTIVEHOSTNAME/g" "$CURRENTREPORT"
sed -i "s/##ReceivedEmail##/$ReceivedEmail/g" "$CURRENTREPORT"
sed -i "s/##DeliveredEmail##/$DeliveredEmail/g" "$CURRENTREPORT"
sed -i "s/##ForwardedEmail##/$ForwardedEmail/g" "$CURRENTREPORT"
sed -i "s/##DeferredEmailCount##/$DeferredEmailCount/g" "$CURRENTREPORT"
sed -i "s/##DeferredEmailDeferralsCount##/$DeferredEmailDeferralsCount/g" "$CURRENTREPORT"
sed -i "s/##BouncedEmail##/$BouncedEmail/g" "$CURRENTREPORT"
sed -i "s/##RejectedEmailCount##/$RejectedEmailCount/g" "$CURRENTREPORT"
sed -i "s/##RejectedEmailPercentage##/$RejectedEmailPercentage/g" "$CURRENTREPORT"
sed -i "s/##RejectedWarningsEmail##/$RejectedWarningsEmail/g" "$CURRENTREPORT"
sed -i "s/##HeldEmail##/$HeldEmail/g" "$CURRENTREPORT"
sed -i "s/##DiscardedEmailCount##/$DiscardedEmailCount/g" "$CURRENTREPORT"
sed -i "s/##DiscardedEmailPercentage##/$DiscardedEmailPercentage/g" "$CURRENTREPORT"
sed -i "s/##BytesReceivedEmail##/$BytesReceivedEmail/g" "$CURRENTREPORT"
sed -i "s/##BytesDeliveredEmail##/$BytesDeliveredEmail/g" "$CURRENTREPORT"
sed -i "s/##SendersEmail##/$SendersEmail/g" "$CURRENTREPORT"
sed -i "s/##SendingHostsDomainsEmail##/$SendingHostsDomainsEmail/g" "$CURRENTREPORT"
sed -i "s/##RecipientsEmail##/$RecipientsEmail/g" "$CURRENTREPORT"
sed -i "s/##RecipientHostsDomainsEmail##/$RecipientHostsDomainsEmail/g" "$CURRENTREPORT"

#======================================================
# Replace Placeholders with values - Table PerDayTrafficSummaryTable
#======================================================
sed -i '/##PerDayTrafficSummaryTable##/ {
r /tmp/PerDayTrafficSummary
d
}' "$CURRENTREPORT" 


#======================================================
# Replace Placeholders with values - Table PerHourTrafficDailyAverageTable
#======================================================
sed -i '/##PerHourTrafficDailyAverageTable##/ {
r /tmp/PerHourTrafficDailyAverage
d
}' "$CURRENTREPORT" 


#======================================================
# Replace Placeholders with values - Table HostDomainSummaryMessageDelivery
#======================================================
sed -i '/##HostDomainSummaryMessageDelivery##/ {
r /tmp/HostDomainSummaryMessageDelivery
d
}' "$CURRENTREPORT" 

#======================================================
# Replace Placeholders with values - Table HostDomainSummaryMessagesReceived
#======================================================
sed -i '/##HostDomainSummaryMessagesReceived##/ {
r /tmp/HostDomainSummaryMessagesReceived
d
}' "$CURRENTREPORT" 

#======================================================
# Replace Placeholders with values - Table Sendersbymessagecount
#======================================================
sed -i '/##Sendersbymessagecount##/ {
r /tmp/Sendersbymessagecount
d
}' "$CURRENTREPORT" 

#======================================================
# Replace Placeholders with values - Table RecipientsbyMessageCount
#======================================================
sed -i '/##RecipientsbyMessageCount##/ {
r /tmp/Recipientsbymessagecount
d
}' "$CURRENTREPORT" 

#======================================================
# Replace Placeholders with values - Table SendersbyMessageSize
#======================================================
sed -i '/##SendersbyMessageSize##/ {
r /tmp/Sendersbymessagesize
d
}' "$CURRENTREPORT" 

#======================================================
# Replace Placeholders with values - Table Recipientsbymessagesize
#======================================================
sed -i '/##Recipientsbymessagesize##/ {
r /tmp/Recipientsbymessagesize
d
}' "$CURRENTREPORT" 

#======================================================
# Replace Placeholders with values - Table Messageswithnosizedata
#======================================================
sed -i '/##Messageswithnosizedata##/ {
r /tmp/Messageswithnosizedata
d
}' "$CURRENTREPORT" 


#======================================================
# Replace Placeholders with values -  MessageDeferralDetail
#======================================================
sed -i '/##MessageDeferralDetail##/ {
r /tmp/messagedeferraldetail
d
}' "$CURRENTREPORT" 

#======================================================
# Replace Placeholders with values -  MessageBounceDetailbyrelay
#======================================================
sed -i '/##MessageBounceDetailbyrelay##/ {
r /tmp/messagebouncedetaibyrelay
d
}' "$CURRENTREPORT" 


#======================================================
# Replace Placeholders with values - warnings
#======================================================
sed -i '/##MailWarnings##/ {
r /tmp/warnings
d
}' "$CURRENTREPORT" 


#======================================================
# Replace Placeholders with values - FatalErrors
#======================================================
sed -i '/##MailFatalErrors##/ {
r /tmp/FatalErrors
d
}' "$CURRENTREPORT" 






#======================================================
# Count Existing Reports - For Dashboard Display
#======================================================
JanRPTCount=$(find "$HTMLOUTPUTDIR/data"  -maxdepth 1 -type f -name "$CURRENTYEAR-Jan*.html" | wc -l)
FebRPTCount=$(find "$HTMLOUTPUTDIR/data"  -maxdepth 1 -type f -name "$CURRENTYEAR-Feb*.html" | wc -l)
MarRPTCount=$(find "$HTMLOUTPUTDIR/data"  -maxdepth 1 -type f -name "$CURRENTYEAR-Mar*.html" | wc -l)
AprRPTCount=$(find "$HTMLOUTPUTDIR/data"  -maxdepth 1 -type f -name "$CURRENTYEAR-Apr*.html" | wc -l)
MayRPTCount=$(find "$HTMLOUTPUTDIR/data"  -maxdepth 1 -type f -name "$CURRENTYEAR-May*.html" | wc -l)
JunRPTCount=$(find "$HTMLOUTPUTDIR/data"  -maxdepth 1 -type f -name "$CURRENTYEAR-Jun*.html" | wc -l)
JulRPTCount=$(find "$HTMLOUTPUTDIR/data"  -maxdepth 1 -type f -name "$CURRENTYEAR-Jul*.html" | wc -l)
AugRPTCount=$(find "$HTMLOUTPUTDIR/data"  -maxdepth 1 -type f -name "$CURRENTYEAR-Aug*.html" | wc -l)
SepRPTCount=$(find "$HTMLOUTPUTDIR/data"  -maxdepth 1 -type f -name "$CURRENTYEAR-Sep*.html" | wc -l)
OctRPTCount=$(find "$HTMLOUTPUTDIR/data"  -maxdepth 1 -type f -name "$CURRENTYEAR-Oct*.html" | wc -l)
NovRPTCount=$(find "$HTMLOUTPUTDIR/data"  -maxdepth 1 -type f -name "$CURRENTYEAR-Nov*.html" | wc -l)
DecRPTCount=$(find "$HTMLOUTPUTDIR/data"  -maxdepth 1 -type f -name "$CURRENTYEAR-Dec*.html" | wc -l)


#======================================================
# Replace Report Totals for Report - Index
#======================================================
sed -i "s/##JanuaryCount##/$JanRPTCount/g" "$INDEXDASHBOARD"
sed -i "s/##FebruaryCount##/$FebRPTCount/g" "$INDEXDASHBOARD"
sed -i "s/##MarchCount##/$MarRPTCount/g" "$INDEXDASHBOARD"
sed -i "s/##AprilCount##/$AprRPTCount/g" "$INDEXDASHBOARD"
sed -i "s/##MayCount##/$MayRPTCount/g" "$INDEXDASHBOARD"
sed -i "s/##JuneCount##/$JunRPTCount/g" "$INDEXDASHBOARD"
sed -i "s/##JulyCount##/$JulRPTCount/g" "$INDEXDASHBOARD"
sed -i "s/##AugustCount##/$AugRPTCount/g" "$INDEXDASHBOARD"
sed -i "s/##SeptemberCount##/$SepRPTCount/g" "$INDEXDASHBOARD"
sed -i "s/##OctoberCount##/$OctRPTCount/g" "$INDEXDASHBOARD"
sed -i "s/##NovemberCount##/$NovRPTCount/g" "$INDEXDASHBOARD"
sed -i "s/##DecemberCount##/$DecRPTCount/g" "$INDEXDASHBOARD"

sed -i "s/##REPORTDATE##/$REPORTDATE/g" "$INDEXDASHBOARD"
sed -i "s/##ACTIVEHOSTNAME##/$ACTIVEHOSTNAME/g" "$INDEXDASHBOARD"


#======================================================
# Update Clickable Index Files (imported dynamicly)
#======================================================

#Delete Exisitng File Indexs
rm -fr "$HTMLOUTPUTDIR"/data/*_rpt.html

#Get List of report files
for filename in "$HTMLOUTPUTDIR"/data/*.html; do
    filenameWithExtOnly="${filename##*/}"
    filenameWithoutExtension="${filenameWithExtOnly%.*}"
 
    case $filenameWithExtOnly in
        *Jan* )  
        echo "<a href=\"data/${filenameWithoutExtension}.html\" class=\"list-group-item list-group-item-action\">$filenameWithoutExtension</a>" >> "$HTMLOUTPUTDIR"/data/jan_rpt.html
        ;;

        *Feb* )  
        echo "<a href=\"data/${filenameWithoutExtension}.html\" class=\"list-group-item list-group-item-action\">$filenameWithoutExtension</a>" >> "$HTMLOUTPUTDIR"/data/feb_rpt.html
        ;;

        *Mar* )  
        echo "<a href=\"data/${filenameWithoutExtension}.html\" class=\"list-group-item list-group-item-action\">$filenameWithoutExtension</a>" >> "$HTMLOUTPUTDIR"/data/mar_rpt.html
        ;;

        *Apr* )  
        echo "<a href=\"data/${filenameWithoutExtension}.html\" class=\"list-group-item list-group-item-action\">$filenameWithoutExtension</a>" >> "$HTMLOUTPUTDIR"/data/apr_rpt.html
        ;;

        *May* )  
        echo "<a href=\"data/${filenameWithoutExtension}.html\" class=\"list-group-item list-group-item-action\">$filenameWithoutExtension</a>" >> "$HTMLOUTPUTDIR"/data/may_rpt.html
        ;;

        *Jun* )  
        echo "<a href=\"data/${filenameWithoutExtension}.html\" class=\"list-group-item list-group-item-action\">$filenameWithoutExtension</a>" >> "$HTMLOUTPUTDIR"/data/jun_rpt.html
        ;;                                        

        *Jul* )  
        echo "<a href=\"data/${filenameWithoutExtension}.html\" class=\"list-group-item list-group-item-action\">$filenameWithoutExtension</a>" >> "$HTMLOUTPUTDIR"/data/jul_rpt.html
        ;;

        *Aug* )  
        echo "<a href=\"data/${filenameWithoutExtension}.html\" class=\"list-group-item list-group-item-action\">$filenameWithoutExtension</a>" >> "$HTMLOUTPUTDIR"/data/aug_rpt.html
        ;;

        *Sep* )  
        echo "<a href=\"data/${filenameWithoutExtension}.html\" class=\"list-group-item list-group-item-action\">$filenameWithoutExtension</a>" >> "$HTMLOUTPUTDIR"/data/sep_rpt.html
        ;;

        *Oct* )  
        echo "<a href=\"data/${filenameWithoutExtension}.html\" class=\"list-group-item list-group-item-action\">$filenameWithoutExtension</a>" >> "$HTMLOUTPUTDIR"/data/oct_rpt.html
        ;;        

        *Nov* )  
        echo "<a href=\"data/${filenameWithoutExtension}.html\" class=\"list-group-item list-group-item-action\">$filenameWithoutExtension</a>" >> "$HTMLOUTPUTDIR"/data/nov_rpt.html
        ;;      

        *Dec* )  
        echo "<a href=\"data/${filenameWithoutExtension}.html\" class=\"list-group-item list-group-item-action\">$filenameWithoutExtension</a>" >> "$HTMLOUTPUTDIR"/data/dec_rpt.html
        ;;          
    esac  
done


#======================================================
# Clean UP
#======================================================
