import {
  to = oci_objectstorage_bucket.backups
  id = "n/frlsvddoxbrh/b/backups-marcelwalder-prod"
}

import {
  to = oci_objectstorage_bucket.tfstate
  id = "n/frlsvddoxbrh/b/tfstate-marcelwalder-prod"
}

import {
  to = module.network.oci_core_vcn.this
  id = "ocid1.vcn.oc1.eu-frankfurt-1.amaaaaaabti2z6aakmxnik4chwcn7dlay5wbnyvnf2cichzrdstvr66mfbya"
}

import {
  to = module.network.oci_core_internet_gateway.this
  id = "ocid1.internetgateway.oc1.eu-frankfurt-1.aaaaaaaapkh2ptauvhuowqo36rvvbtickhfww757pkv6xdodvjporsw5hqja"
}

import {
  to = module.network.oci_core_default_route_table.this
  id = "ocid1.routetable.oc1.eu-frankfurt-1.aaaaaaaayopvzlgzq3q4zitjilwz65zm4nlki3mr2xg5ijrhseoclxg25rfq"
}

import {
  to = module.network.oci_core_default_security_list.this
  id = "ocid1.securitylist.oc1.eu-frankfurt-1.aaaaaaaar2oaym6xdveuminwilwizp237oucnfjtdge23g555c2bwcd6zmka"
}

import {
  to = module.network.oci_core_subnet.this["public"]
  id = "ocid1.subnet.oc1.eu-frankfurt-1.aaaaaaaaho4ynl73lo6whdchghz6wuur6mlac4ns4bv6x42mjsusf26g2xtq"
}

import {
  to = module.compute.oci_core_instance.this["mail"]
  id = "ocid1.instance.oc1.eu-frankfurt-1.antheljrbti2z6acbas6m7tpxxagfurhksxiavcqj6q7zfvwctdf5jvrje7a"
}

import {
  to = module.compute.oci_core_public_ip.reserved["mail"]
  id = "ocid1.publicip.oc1.eu-frankfurt-1.amaaaaaabti2z6aa4vqpu6i6r6trajv5fv52cr65ee7enjt7zbnaxh6kenxq"
}

import {
  to = oci_core_volume_backup_policy.mail
  id = "ocid1.volumebackuppolicy.oc1.eu-frankfurt-1.amaaaaaabti2z6aa3wiqc7z2lungduc66csxgzhddkuiqqaxewjpkeksaqpa"
}

import {
  to = oci_core_volume_backup_policy_assignment.mail_boot
  id = "ocid1.volumebackuppolicyassign.oc1.eu-frankfurt-1.abtheljrey667ty35ggnmtdatao7ihzonwd4i37hhb53jq7bx4267kahicaq"
}

import {
  to = oci_email_email_domain.marcelwalder_eu
  id = "ocid1.emaildomain.oc1.eu-frankfurt-1.amaaaaaabti2z6aajhoyeyovwggwaw7jozutfoxtccg6cyr3bvz3wwsi3p4q"
}

import {
  to = oci_email_dkim.dkim1
  id = "ocid1.emaildkim.oc1.eu-frankfurt-1.amaaaaaabti2z6aa3g3gdqeh5dp5s2k5dmklhokosp4vphrsdwfv7ia5vxxa"
}

import {
  to = oci_email_sender.this["info"]
  id = "ocid1.emailsender.oc1.eu-frankfurt-1.amaaaaaabti2z6aamgrtuv7zea6fyqgyjrd4eien5kgpddozxuwnknj5a7kq"
}

import {
  to = oci_email_sender.this["postmaster"]
  id = "ocid1.emailsender.oc1.eu-frankfurt-1.amaaaaaabti2z6aaeqvusyh656tlixtugmk2tpcsr7zzkocqzz5gmacl6uka"
}

import {
  to = oci_email_sender.this["wildcard"]
  id = "ocid1.emailsender.oc1.eu-frankfurt-1.amaaaaaabti2z6aaoptelwclwemvwe632o42bwgxjzck76clkilt2bkrlbpa"
}

import {
  to = oci_ons_notification_topic.quota_alerts
  id = "ocid1.onstopic.oc1.eu-frankfurt-1.amaaaaaabti2z6aagafzsvvvkknlsvjapbbnxulrnjrltsg4z5rn6wpymcta"
}

import {
  to = oci_ons_subscription.quota_alerts_email
  id = "ocid1.onssubscription.oc1.eu-frankfurt-1.aaaaaaaanxp6q3fd5hfqmlcdab7xrumhuzvfjdqnaqw2mfmdd7ryh6bhyzha"
}

import {
  to = oci_events_rule.mail_backup_notification
  id = "ocid1.eventrule.oc1.eu-frankfurt-1.amaaaaaabti2z6aacso64e4cjdjta4bc4hgpnuxb2u2fg5oora3nupektena"
}

import {
  to = oci_monitoring_alarm.instance_down_guard
  id = "ocid1.alarm.oc1.eu-frankfurt-1.amaaaaaabti2z6aats4ia4cylfn4y2wqz5sxzemg47b7odpk3vnaovlv76ba"
}

import {
  to = oci_monitoring_alarm.idle_reclaim_guard_memory
  id = "ocid1.alarm.oc1.eu-frankfurt-1.amaaaaaabti2z6aa3ehuswsuyfyvuzu5dhh7dm3ibi22pjmbhfdrgtznvknq"
}

import {
  to = oci_budget_budget.zero_spend_guard
  id = "ocid1.budget.oc1.eu-frankfurt-1.amaaaaaabti2z6aa3i24bgwyf6hrqavxzxzmpgdfhgw5ehdrriglu5p7pwxa"
}

import {
  to = oci_budget_alert_rule.this["actual_70"]
  id = "budgets/ocid1.budget.oc1.eu-frankfurt-1.amaaaaaabti2z6aa3i24bgwyf6hrqavxzxzmpgdfhgw5ehdrriglu5p7pwxa/alertRules/ocid1.alertrule.oc1.eu-frankfurt-1.amaaaaaabti2z6aau6xbs3wynwbfe37pfy2yzxjosqruck5hrgoxskzdsbsq"
}

import {
  to = oci_budget_alert_rule.this["actual_90"]
  id = "budgets/ocid1.budget.oc1.eu-frankfurt-1.amaaaaaabti2z6aa3i24bgwyf6hrqavxzxzmpgdfhgw5ehdrriglu5p7pwxa/alertRules/ocid1.alertrule.oc1.eu-frankfurt-1.amaaaaaabti2z6aa47lzmj2vukuelcpxgsyb2zf6rgexff72amx36rrqbjea"
}

import {
  to = oci_budget_alert_rule.this["forecast_70"]
  id = "budgets/ocid1.budget.oc1.eu-frankfurt-1.amaaaaaabti2z6aa3i24bgwyf6hrqavxzxzmpgdfhgw5ehdrriglu5p7pwxa/alertRules/ocid1.alertrule.oc1.eu-frankfurt-1.amaaaaaabti2z6aasbm3f5btoujj26fsguxt4rp4jxj3g3zakum6xcilz6ra"
}

import {
  to = oci_budget_alert_rule.this["forecast_90"]
  id = "budgets/ocid1.budget.oc1.eu-frankfurt-1.amaaaaaabti2z6aa3i24bgwyf6hrqavxzxzmpgdfhgw5ehdrriglu5p7pwxa/alertRules/ocid1.alertrule.oc1.eu-frankfurt-1.amaaaaaabti2z6aadoqkdr3oz6jnira7wyupny3stdgfpjl6nfvuaz4jzd3a"
}

import {
  to = oci_identity_policy.tenant_admin
  id = "ocid1.policy.oc1..aaaaaaaae77bsoyr4atpexeqkw4eyozt2rs3zsxhsnx72qerdzadhpxn7uua"
}
