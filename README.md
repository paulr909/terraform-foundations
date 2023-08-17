# your-project-name-terraform-foundations

This code is the foundational layer for an AWS account. This will build basic networking
capability, and attach a transit gateway for intra-account networking. It will also
build IAM Roles for assumption from the 'security' layer.

The main consideration for using this is the CIDR range implemented, at the moment this
should continuous /16 blocks within the 10.16.0.0/16 range for engineering and data
science purposes.

 - Apply against workspace
 - Fail to make routing table
 - log into accepter account and accept ram share in console
 - Log into root account & go to VPC -> Transit gateway attachments
 - Confirm acceptance
 - rerun terraform apply
 - ???
 - Profit