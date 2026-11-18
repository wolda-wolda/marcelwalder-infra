require ["fileinto", "mailbox", "envelope", "subaddress"];

# Automatically route DMARC and TLS reports into a dedicated DMARC folder
if anyof (
    envelope :is "to" "dmarc@marcelwalder.eu",
    header :contains "To" "dmarc@marcelwalder.eu",
    header :contains "Subject" "Report Domain: marcelwalder.eu",
    header :contains "Subject" "DMARC Report",
    header :contains "Subject" "TLS-RPT",
    header :contains "Subject" "Report-Domain: marcelwalder.eu"
) {
    fileinto :create "DMARC";
    stop;
}
