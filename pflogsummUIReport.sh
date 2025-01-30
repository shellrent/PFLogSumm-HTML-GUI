#!/usr/bin/env bash
# Debug option - should be disabled unless required
#set -x
#=====================================================================================================================
#   DESCRIPTION         Generating a stand alone web report for postix log files, 
#                       Runs on all Linux platforms with postfix installed
#   ORIGINAL AUTHOR     Riaan Pretorius <pretorius.riaan@gmail.com>
#   EDITED              BY Shellrent S.p.a.
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

#=====================================================================================================================
# FUNCTIONS
#=====================================================================================================================
function CleanupTemp() {
  # funzione di cleanup dei file temporanei
  [[ "$DEBUG" -eq 0 ]] && logger "[DEBUG] Delete $(find "$TEMPDIR" -type f | wc -l) temp files from $TEMPDIR"
  rm -rf "$TEMPDIR"
}

function InitScript(){
    #CONFIG FILE LOCATION
    PFSYSCONFDIR="/etc"

    #Create Blank Config File if it does not exist
    if [ ! -f ${PFSYSCONFDIR}/"pflogsumui.conf" ]
    then
    tee ${PFSYSCONFDIR}/"pflogsumui.conf" <<EOF
#PFLOGSUMUI CONFIG

# DEBUG
DEBUG=0
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

    # Create tmp_dir
    TEMPDIR=$(mktemp -d)
    readonly TEMPDIR

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

    #======================================================
    # Single PAGE INDEX HTML TEMPLATE
    # Using embedded HTML makes the script highly portable
    # SED search and replace tags to fill the content
    #======================================================

    INDEXDASHBOARD="$HTMLOUTPUTDIR/$HTMLOUTPUT_INDEXDASHBOARD"

    cp "$SCRIPTPATH/Templates/index_dashboard_template.html" "$INDEXDASHBOARD"

    CURRENTREPORT="$HTMLOUTPUTDIR"data/"$CURRENTYEAR"-"$CURRENTMONTH"-"$CURRENTDAY".html

    cp "$SCRIPTPATH/Templates/Report_Template.html" "$CURRENTREPORT"

}

function ExtractData(){
    #Extract Sections from PFLOGSUMM
    if grep -q -E '^Per-Day' "$TEMPDIR/mailreport"; then
        sed -n '/^Grand Totals/,/^Per-Day/p;/^Per-Day/q' "$TEMPDIR/mailreport" | sed -e '1,4d' | sed -e :a -e '$d;N;2,3ba' -e 'P;D' | sed '/^$/d' > "$TEMPDIR/GrandTotals"
    else
        sed -n '/^Grand Totals/,/^Per-Hour/p;/^Per-Hour/q' "$TEMPDIR/mailreport" | sed -e '1,4d' | sed -e :a -e '$d;N;2,3ba' -e 'P;D' | sed '/^$/d' > "$TEMPDIR/GrandTotals"
    fi

    sed -n '/^Per-Day Traffic Summary/,/^Per-Hour/p;/^Per-Hour/q' "$TEMPDIR/mailreport" | sed -e '1,4d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D'  > "$TEMPDIR/PerDayTrafficSummary"
    sed -n '/^Per-Hour Traffic Summary/,/^Host\//p;/^Host\//q' "$TEMPDIR/mailreport" | sed -e '1,4d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D'  > "$TEMPDIR/PerHourTrafficDailyAverage"

    sed -n '/^Host\/Domain Summary\: Message Delivery/,/^Host\/Domain Summary\: Messages Received/p;/^Host\/Domain Summary\: Messages Received/q' "$TEMPDIR/mailreport" | sed -e '1,4d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D'  > "$TEMPDIR/HostDomainSummaryMessageDelivery"
    sed -n '/^Host\/Domain Summary\: Messages Received/,/^Senders by message count/p;/^Senders by message count/q' "$TEMPDIR/mailreport" | sed -e '1,4d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D'  > "$TEMPDIR/HostDomainSummaryMessagesReceived"
    sed -n '/^Senders by message count/,/^Recipients by message count/p;/^Recipients by message count/q' "$TEMPDIR/mailreport" | sed -e '1,2d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D' | sed '/^$/d' > "$TEMPDIR/Sendersbymessagecount"
    sed -n '/^Recipients by message count/,/^Senders by message size/p;/^Senders by message size/q' "$TEMPDIR/mailreport" | sed -e '1,2d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D' | sed '/^$/d' > "$TEMPDIR/Recipientsbymessagecount"
    sed -n '/^Senders by message size/,/^Recipients by message size/p;/^Recipients by message size/q' "$TEMPDIR/mailreport" | sed -e '1,2d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D' | sed '/^$/d' > "$TEMPDIR/Sendersbymessagesize"

    if grep -q -E '^Messages with no size data' "$TEMPDIR/mailreport"; then
        sed -n '/^Recipients by message size/,/^Messages with no size data/p;/^Messages with no size data/q' "$TEMPDIR/mailreport" | sed -e '1,2d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D' | sed '/^$/d' > "$TEMPDIR/Recipientsbymessagesize"
        sed -n '/^Messages with no size data/,/^message deferral detail/p;/^message deferral detail/q' "$TEMPDIR/mailreport" | sed -e '1,2d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D' | sed '/^$/d' > "$TEMPDIR/Messageswithnosizedata"
    else
        sed -n '/^Recipients by message size/,/^message deferral detail/p;/^message deferral detail/q' "$TEMPDIR/mailreport" | sed -e '1,2d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D' | sed '/^$/d' > "$TEMPDIR/Recipientsbymessagesize"
        touch "$TEMPDIR/Messageswithnosizedata"
    fi

    sed -n '/^message deferral detail/,/^message bounce detail (by relay)/p;/^message bounce detail (by relay)/q' "$TEMPDIR/mailreport" | sed -e '1,2d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D' | sed '/^$/d' > "$TEMPDIR/messagedeferraldetail"
    if ! grep -q '[^[:space:]]' "$TEMPDIR/messagedeferraldetail"; then
        echo "none" > "$TEMPDIR/messagedeferraldetail"
    fi
    sed -n '/^message bounce detail (by relay)/,/^message reject detail/p;/^message reject detail/q' "$TEMPDIR/mailreport" | sed -e '1,2d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D' | sed '/^$/d' > "$TEMPDIR/messagebouncedetaibyrelay"
    if ! grep -q '[^[:space:]]' "$TEMPDIR/messagebouncedetaibyrelay"; then
        echo "none" > "$TEMPDIR/messagebouncedetaibyrelay"
    fi
    sed -n '/^Warnings/,/^Fatal Errors/p;/^Fatal Errors/q' "$TEMPDIR/mailreport" | sed -e '1,2d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D' | sed '/^$/d' > "$TEMPDIR/warnings"
    if ! grep -q '[^[:space:]]' "$TEMPDIR/warnings"; then
        echo "none" > "$TEMPDIR/warnings"
    fi

    sed -n '/^Fatal Errors/,/^Master daemon messages/p;/^Master daemon messages/q' "$TEMPDIR/mailreport" | sed -e '1,2d' | sed -e :a -e '$d;N;2,2ba' -e 'P;D' | sed '/^$/d' > "$TEMPDIR/FatalErrors"
    if ! grep -q '[^[:space:]]' "$TEMPDIR/FatalErrors"; then
        echo "none" > "$TEMPDIR/FatalErrors"
    fi

    #======================================================
    # Extract Information into variables -> Grand Totals
    #======================================================
    ReceivedEmail=$(awk '$2=="received" {print $1}'  "$TEMPDIR/GrandTotals")
    DeliveredEmail=$(awk '$2=="delivered" {print $1}'  "$TEMPDIR/GrandTotals")
    ForwardedEmail=$(awk '$2=="forwarded" {print $1}'  "$TEMPDIR/GrandTotals")
    DeferredEmailCount=$(awk '$2=="deferred" {print $1}'  "$TEMPDIR/GrandTotals")
    DeferredEmailDeferralsCount=$(awk '$2=="deferred" {print $3" "$4}'  "$TEMPDIR/GrandTotals")
    BouncedEmail=$(awk '$2=="bounced" {print $1}'  "$TEMPDIR/GrandTotals")
    RejectedEmailCount=$(awk '$2=="rejected" {print $1}'  "$TEMPDIR/GrandTotals")
    RejectedEmailPercentage=$(awk '$2=="rejected" {print $3}'  "$TEMPDIR/GrandTotals")
    RejectedWarningsEmail=$(sed 's/reject warnings/rejectwarnings/' "$TEMPDIR/GrandTotals" | awk '$2=="rejectwarnings" {print $1}')
    HeldEmail=$(awk '$2=="held" {print $1}'  "$TEMPDIR/GrandTotals")
    DiscardedEmailCount=$(awk '$2=="discarded" {print $1}'  "$TEMPDIR/GrandTotals")
    DiscardedEmailPercentage=$(awk '$2=="discarded" {print $3}'  "$TEMPDIR/GrandTotals")
    BytesReceivedEmail=$(sed 's/bytes received/bytesreceived/' "$TEMPDIR/GrandTotals" | awk '$2=="bytesreceived" {print $1}'|sed 's/[^0-9]*//g' )
    BytesDeliveredEmail=$(sed 's/bytes delivered/bytesdelivered/' "$TEMPDIR/GrandTotals" | awk '$2=="bytesdelivered" {print $1}'|sed 's/[^0-9]*//g')
    SendersEmail=$(awk '$2=="senders" {print $1}'  "$TEMPDIR/GrandTotals")
    SendingHostsDomainsEmail=$(sed 's/sending hosts\/domains/sendinghostsdomains/' "$TEMPDIR/GrandTotals" | awk '$2=="sendinghostsdomains" {print $1}')
    RecipientsEmail=$(awk '$2=="recipients" {print $1}'  "$TEMPDIR/GrandTotals")
    RecipientHostsDomainsEmail=$(sed 's/recipient hosts\/domains/recipienthostsdomains/' "$TEMPDIR/GrandTotals" | awk '$2=="recipienthostsdomains" {print $1}')


    #======================================================
    # Extract Information into variable -> Per-Day Traffic Summary
    #======================================================
    while IFS= read -r var
    do
        PerDayTrafficSummaryTable=""
        PerDayTrafficSummaryTable+="<tr>"
        PerDayTrafficSummaryTable+=$(echo "$var" | awk '{print "<td>"$1" "$2" "$3"</td>""<td>"$4"</td>""<td>"$5"</td>""<td>"$6"</td>""<td>"$7"</td>""<td>"$8"</td>"}')
        PerDayTrafficSummaryTable+="</tr>"
        echo "$PerDayTrafficSummaryTable" >> "$TEMPDIR/PerDayTrafficSummary_tmp"
    done < "$TEMPDIR/PerDayTrafficSummary"
    if ! grep -q '[^[:space:]]' "$TEMPDIR/PerDayTrafficSummary"; then
        PerDayTrafficSummaryTable=""
        PerDayTrafficSummaryTable+="<tr>"
        PerDayTrafficSummaryTable+="<td>0 0 0</td>""<td>0</td>""<td>0</td>""<td>0</td>""<td>0</td>""<td>0</td>"
        PerDayTrafficSummaryTable+="</tr>"
        echo "$PerDayTrafficSummaryTable" >> "$TEMPDIR/PerDayTrafficSummary_tmp"
    fi

    $MOVEF  "$TEMPDIR/PerDayTrafficSummary_tmp" "$TEMPDIR/PerDayTrafficSummary" &> /dev/null

    #======================================================
    # Extract Information into variable -> Per-Hour Traffic Daily Average
    #======================================================
    while IFS= read -r var
    do
        PerHourTrafficDailyAverageTable=""
        PerHourTrafficDailyAverageTable+="<tr>"
        PerHourTrafficDailyAverageTable+=$(echo "$var" | awk '{print "<td>"$1"</td>""<td>"$2"</td>""<td>"$3"</td>""<td>"$4"</td>""<td>"$5"</td>""<td>"$6"</td>"}')
        PerHourTrafficDailyAverageTable+="</tr>"
        echo "$PerHourTrafficDailyAverageTable" >> "$TEMPDIR/PerHourTrafficDailyAverage_tmp"
    done < "$TEMPDIR/PerHourTrafficDailyAverage"
    if ! grep -q '[^[:space:]]' "$TEMPDIR/PerHourTrafficDailyAverage"; then
        PerHourTrafficDailyAverageTable=""
        PerHourTrafficDailyAverageTable+="<tr>"
        PerHourTrafficDailyAverageTable+="<td>0</td>""<td>0</td>""<td>0</td>""<td>0</td>""<td>0</td>""<td>0</td>"
        PerHourTrafficDailyAverageTable+="</tr>"
    fi
    $MOVEF "$TEMPDIR/PerHourTrafficDailyAverage_tmp" "$TEMPDIR/PerHourTrafficDailyAverage" &> /dev/null


    #======================================================
    # Extract Information into variable -> Per-Hour Traffic Daily Average
    #======================================================
    while IFS= read -r var
    do
        HostDomainSummaryMessageDeliveryTable=""
        HostDomainSummaryMessageDeliveryTable+="<tr>"
        HostDomainSummaryMessageDeliveryTable+=$(echo "$var" | awk '{print "<td>"$1"</td>""<td>"$2"</td>""<td>"$3"</td>""<td>"$4" "$5"</td>""<td>"$6" "$7"</td>""<td>"$8"</td>" }')
        HostDomainSummaryMessageDeliveryTable+="</tr>"
        echo "$HostDomainSummaryMessageDeliveryTable" >> "$TEMPDIR/HostDomainSummaryMessageDelivery_tmp"
    done < "$TEMPDIR/HostDomainSummaryMessageDelivery"
    if ! grep -q '[^[:space:]]' "$TEMPDIR/HostDomainSummaryMessageDelivery"; then
        HostDomainSummaryMessageDeliveryTable=""
        HostDomainSummaryMessageDeliveryTable+="<tr>"
        HostDomainSummaryMessageDeliveryTable+="<td>0</td>""<td>0</td>""<td>0</td>""<td>0 0</td>""<td>0 0</td>""<td>0</td>"
        HostDomainSummaryMessageDeliveryTable+="</tr>"
        echo "$HostDomainSummaryMessageDeliveryTable" >> "$TEMPDIR/HostDomainSummaryMessageDelivery_tmp"
    fi
    $MOVEF "$TEMPDIR/HostDomainSummaryMessageDelivery_tmp" "$TEMPDIR/HostDomainSummaryMessageDelivery" &> /dev/null


    #======================================================
    # Extract Information into variable -> Host Domain Summary Messages Received
    #======================================================
    while IFS= read -r var
    do
        HostDomainSummaryMessagesReceivedTable=""
        HostDomainSummaryMessagesReceivedTable+="<tr>"
        HostDomainSummaryMessagesReceivedTable+=$(echo "$var" | awk '{print "<td>"$1"</td>""<td>"$2"</td>""<td>"$3"</td>"}')
        HostDomainSummaryMessagesReceivedTable+="</tr>"
        echo "$HostDomainSummaryMessagesReceivedTable" >> "$TEMPDIR/HostDomainSummaryMessagesReceived_tmp"
    done < "$TEMPDIR/HostDomainSummaryMessagesReceived"
    if ! grep -q '[^[:space:]]' "$TEMPDIR/HostDomainSummaryMessagesReceived"; then
        HostDomainSummaryMessagesReceivedTable=""
        HostDomainSummaryMessagesReceivedTable+="<tr>"
        HostDomainSummaryMessagesReceivedTable+="<td>0</td>""<td>0</td>""<td>none</td>"
        HostDomainSummaryMessagesReceivedTable+="</tr>"
        echo "$HostDomainSummaryMessagesReceivedTable" >> "$TEMPDIR/HostDomainSummaryMessagesReceived_tmp"
    fi
    $MOVEF "$TEMPDIR/HostDomainSummaryMessagesReceived_tmp" "$TEMPDIR/HostDomainSummaryMessagesReceived" &> /dev/null


    #======================================================
    # Extract Information into variable -> Host Domain Summary Messages Received
    #======================================================
    while IFS= read -r var
    do
        SendersbymessagecountTable=""
        SendersbymessagecountTable+="<tr>"
        SendersbymessagecountTable+=$(echo "$var" | awk '{print "<td>"$1"</td>""<td>"$2"</td>"}')
        SendersbymessagecountTable+="</tr>"
        echo "$SendersbymessagecountTable" >> "$TEMPDIR/Sendersbymessagecount_tmp"
    done < "$TEMPDIR/Sendersbymessagecount"
    if ! grep -q '[^[:space:]]' "$TEMPDIR/Sendersbymessagecount"; then
        SendersbymessagecountTable=""
        SendersbymessagecountTable+="<tr>"
        SendersbymessagecountTable+="<td>0</td>""<td>none</td>"
        SendersbymessagecountTable+="</tr>"
        echo "$SendersbymessagecountTable" >> "$TEMPDIR/Sendersbymessagecount_tmp"
    fi
    $MOVEF  "$TEMPDIR/Sendersbymessagecount_tmp" "$TEMPDIR/Sendersbymessagecount" &> /dev/null

    #======================================================
    # Extract Information into variable -> Recipients by message count
    #======================================================
    while IFS= read -r var
    do
        RecipientsbymessagecountTable=""
        RecipientsbymessagecountTable+="<tr>"
        RecipientsbymessagecountTable+=$(echo "$var" | awk '{print "<td>"$1"</td>""<td>"$2"</td>"}')
        RecipientsbymessagecountTable+="</tr>"
        echo "$RecipientsbymessagecountTable" >> "$TEMPDIR/Recipientsbymessagecount_tmp"
    done < "$TEMPDIR/Recipientsbymessagecount"
    if ! grep -q '[^[:space:]]' "$TEMPDIR/Recipientsbymessagecount"; then
        RecipientsbymessagecountTable=""
        RecipientsbymessagecountTable+="<tr>"
        RecipientsbymessagecountTable+="<td>0</td>""<td>none</td>"
        RecipientsbymessagecountTable+="</tr>"
        echo "$RecipientsbymessagecountTable" >> "$TEMPDIR/Recipientsbymessagecount_tmp"
    fi
    $MOVEF "$TEMPDIR/Recipientsbymessagecount_tmp" "$TEMPDIR/Recipientsbymessagecount" &> /dev/null


    #======================================================
    # Extract Information into variable -> Senders by message size
    #======================================================
    while IFS= read -r var
    do
        SendersbymessagesizeTable=""
        SendersbymessagesizeTable+="<tr>"
        SendersbymessagesizeTable+=$(echo "$var" | awk '{print "<td>"$1"</td>""<td>"$2"</td>"}')
        SendersbymessagesizeTable+="</tr>"
        echo "$SendersbymessagesizeTable" >> "$TEMPDIR/Sendersbymessagesize_tmp"
    done < "$TEMPDIR/Sendersbymessagesize"
    if ! grep -q '[^[:space:]]' "$TEMPDIR/Sendersbymessagesize"; then
        SendersbymessagesizeTable=""
        SendersbymessagesizeTable+="<tr>"
        SendersbymessagesizeTable+="<td>0</td>""<td>none</td>"
        SendersbymessagesizeTable+="</tr>"
        echo "$SendersbymessagesizeTable" >> "$TEMPDIR/Sendersbymessagesize_tmp"
    fi
    $MOVEF "$TEMPDIR/Sendersbymessagesize_tmp" "$TEMPDIR/Sendersbymessagesize" &> /dev/null


    #======================================================
    # Extract Information into variable -> Recipients by messagesize Table
    #======================================================
    while IFS= read -r var
    do
        RecipientsbymessagesizeTable=""
        RecipientsbymessagesizeTable+="<tr>"
        RecipientsbymessagesizeTable+=$(echo "$var" | awk '{print "<td>"$1"</td>""<td>"$2"</td>"}')
        RecipientsbymessagesizeTable+="</tr>"
        echo "$RecipientsbymessagesizeTable" >> "$TEMPDIR/Recipientsbymessagesize_tmp"
    done < "$TEMPDIR/Recipientsbymessagesize"
    if ! grep -q '[^[:space:]]' "$TEMPDIR/Recipientsbymessagesize"; then
        RecipientsbymessagesizeTable=""
        RecipientsbymessagesizeTable+="<tr>"
        RecipientsbymessagesizeTable+="<td>0</td>""<td>none</td>"
        RecipientsbymessagesizeTable+="</tr>"
        echo "$RecipientsbymessagesizeTable" >> "$TEMPDIR/Recipientsbymessagesize_tmp"
    fi
    $MOVEF "$TEMPDIR/Recipientsbymessagesize_tmp" "$TEMPDIR/Recipientsbymessagesize" &> /dev/null

    #======================================================
    # Extract Information into variable -> Recipients by messagesize Table
    #======================================================
    while IFS= read -r var
    do
        MessageswithnosizedataTable=""
        MessageswithnosizedataTable+="<tr>"
        MessageswithnosizedataTable+=$(echo "$var" | awk '{print "<td>"$1"</td>""<td>"$2"</td>"}')
        MessageswithnosizedataTable+="</tr>"
        echo "$MessageswithnosizedataTable" >> "$TEMPDIR/Messageswithnosizedata_tmp"
    done < "$TEMPDIR/Messageswithnosizedata"
    if ! grep -q '[^[:space:]]' "$TEMPDIR/Messageswithnosizedata"; then
        MessageswithnosizedataTable=""
        MessageswithnosizedataTable+="<tr>"
        MessageswithnosizedataTable+="<td>0</td>""<td>none</td>"
        MessageswithnosizedataTable+="</tr>"
        echo "$MessageswithnosizedataTable" >> "$TEMPDIR/Messageswithnosizedata_tmp"
    fi
    $MOVEF  "$TEMPDIR/Messageswithnosizedata_tmp" "$TEMPDIR/Messageswithnosizedata"  &> /dev/null
}

function UpdateCourrentReport() {

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
    sed -i "/##PerDayTrafficSummaryTable##/r $TEMPDIR/PerDayTrafficSummary" "$CURRENTREPORT"
    sed -i "/##PerDayTrafficSummaryTable##/d" "$CURRENTREPORT"

    #======================================================
    # Replace Placeholders with values - Table PerHourTrafficDailyAverageTable
    #======================================================
    sed -i "/##PerHourTrafficDailyAverageTable##/r $TEMPDIR/PerHourTrafficDailyAverage" "$CURRENTREPORT"
    sed -i "/##PerHourTrafficDailyAverageTable##/d" "$CURRENTREPORT"

    #======================================================
    # Replace Placeholders with values - Table HostDomainSummaryMessageDelivery
    #======================================================
    sed -i "/##HostDomainSummaryMessageDelivery##/r $TEMPDIR/HostDomainSummaryMessageDelivery" "$CURRENTREPORT"
    sed -i "/##HostDomainSummaryMessageDelivery##/d" "$CURRENTREPORT"

    #======================================================
    # Replace Placeholders with values - Table HostDomainSummaryMessagesReceived
    #======================================================
    sed -i "/##HostDomainSummaryMessagesReceived##/r $TEMPDIR/HostDomainSummaryMessagesReceived" "$CURRENTREPORT"
    sed -i "/##HostDomainSummaryMessagesReceived##/d" "$CURRENTREPORT"

    #======================================================
    # Replace Placeholders with values - Table Sendersbymessagecount
    #======================================================
    sed -i "/##Sendersbymessagecount##/r $TEMPDIR/Sendersbymessagecount" "$CURRENTREPORT"
    sed -i "/##Sendersbymessagecount##/d" "$CURRENTREPORT"

    #======================================================
    # Replace Placeholders with values - Table RecipientsbyMessageCount
    #======================================================
    sed -i "/##RecipientsbyMessageCount##/r $TEMPDIR/Recipientsbymessagecount" "$CURRENTREPORT"
    sed -i "/##RecipientsbyMessageCount##/d" "$CURRENTREPORT"

    #======================================================
    # Replace Placeholders with values - Table SendersbyMessageSize
    #======================================================
    sed -i "/##SendersbyMessageSize##/r $TEMPDIR/Sendersbymessagesize" "$CURRENTREPORT"
    sed -i "/##SendersbyMessageSize##/d" "$CURRENTREPORT"

    #======================================================
    # Replace Placeholders with values - Table Recipientsbymessagesize
    #======================================================
    sed -i "/##Recipientsbymessagesize##/r $TEMPDIR/Recipientsbymessagesize" "$CURRENTREPORT"
    sed -i "/##Recipientsbymessagesize##/d" "$CURRENTREPORT"

    #======================================================
    # Replace Placeholders with values - Table Messageswithnosizedata
    #======================================================
    sed -i "/##Messageswithnosizedata##/r $TEMPDIR/Messageswithnosizedata" "$CURRENTREPORT"
    sed -i "/##Messageswithnosizedata##/d" "$CURRENTREPORT"

    #======================================================
    # Replace Placeholders with values -  MessageDeferralDetail
    #======================================================
    sed -i "/##MessageDeferralDetail##/r $TEMPDIR/messagedeferraldetail" "$CURRENTREPORT"
    sed -i "/##MessageDeferralDetail##/d" "$CURRENTREPORT"

    #======================================================
    # Replace Placeholders with values -  MessageBounceDetailbyrelay
    #======================================================
    sed -i "/##MessageBounceDetailbyrelay##/r $TEMPDIR/messagebouncedetaibyrelay" "$CURRENTREPORT"
    sed -i "/##MessageBounceDetailbyrelay##/d" "$CURRENTREPORT"

    #======================================================
    # Replace Placeholders with values - warnings
    #======================================================
    sed -i "/##MailWarnings##/r $TEMPDIR/warnings" "$CURRENTREPORT"
    sed -i "/##MailWarnings##/d" "$CURRENTREPORT"

    #======================================================
    # Replace Placeholders with values - FatalErrors
    #======================================================
    sed -i "/##MailFatalErrors##/r $TEMPDIR/FatalErrors" "$CURRENTREPORT"
    sed -i "/##MailFatalErrors##/d" "$CURRENTREPORT"

}

function UpdateIndexBoard(){
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
}

#======================================================
# All script
#======================================================
InitScript
# Generate report
# shellcheck disable=SC2086
$PFLOGSUMMBIN $PFLOGSUMMOPTIONS -e "$LOGFILELOCATION" > $TEMPDIR/mailreport

ExtractData
UpdateCourrentReport
UpdateIndexBoard
CleanupTemp