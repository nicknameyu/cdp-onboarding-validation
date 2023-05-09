# Issues

## AWS
### ignored issues
- Rule for `dynamodb.*.amazonaws.com` can't be created, but as tt can be replaced by VPC endpoint, not a big problem.
- Rule for `*.*.rds.amazonaws.com` can't be created, but as tt can be replaced by VPC endpoint, not a big problem.
- Rule for `api.ecr.*.amazonaws.com` can't be created, but as tt can be replaced by VPC endpoint, not a big problem.
- Rule for `*.dkr.ecr.*.amazonaws.com` can't be created, but as tt can be replaced by VPC endpoint, not a big problem.
- Rule for `ec2.*.amazonaws.com` can't be created, but as tt can be replaced by VPC endpoint, not a big problem.
- Rule for `elasticfilesystem.*.amazonaws.com` can't be created, but as tt can be replaced by VPC endpoint, not a big problem.
- Rule for `elasticloadbalancing.*.amazonaws.com` can't be created, but as tt can be replaced by VPC endpoint, not a big problem.

### outstanding issues: 
- `eks.*.amazonaws.com`: AWS does not support EKS VPC endpoints at this time. How should customer do with eks services?
- `cloudformation.*.amazonaws.com`: Can be made internal with VPC endpoints. But it is in the provisioning procedure that cloudformation is required. Customer cannot create VPC endpoint during the provisioning for a resource that is created in the provisioning procedure.
- `autoscaling.*.amazonaws.com` Can be made internal with VPC endpoints. But it is in the provisioning procedure that ASG is required. Customer cannot create VPC endpoint during the provisioning for a resource that is created in the provisioning procedure.
- `rds.*.amazonaws.com` AWS does not support RDS API VPC endpoints at this time. This requirement is under further evaluation. Data Warehouse uses Amazon RDS for PostgreSQL.
- `servicequotas.*.amazonaws.com` AWS does not support Service Quota via VPC endpoints. Used to check limits and warn prior to hitting the limits.
- `pricing.*.amazonaws.com` AWS Price List Service uses us-east-1 or ap-south-1 as the region.

## Azure
### Outstanding issues:
- Below rules can't be created cause they have wild card
  - `*.agentsvc.azure-automation.net`
  - `*.ods.opinsights.azure.com`
  - `*.oms.opinsights.azure.com`
  - `*.blob.core.windows.net`