# About the project
People are becoming interested day by day to cloud platform & planning to run their business or application on it for it's scalability & cost effectivity. Most often you find customer wanting their monolithic application to be migrated from on-prem to aws cloud. ***This project can be a good pick-n-drop tool for this !!!.***

## What it does?
It's written for migrating a laravel based project to aws cloud. So the server related configs are based on laravel platform. To do so all you need to do is to run ***terraform init*** and ***terraform apply*** in the terraform root directory. then it performs the following:
- It prompts db name, db user, db password & email address for sns notification on server scale-IN/OUT
- It clones code base from private git repo
- Deploys laravel application on ec2 
- All application servers will be launched under private subnet & be controlled by auto-scaling group
- Servers will be automatically scaled out or scaled in depending on load by autoscaling group
- It launches RDS instance as db service in private subnet
- App servers will be behind an internet-facing Load balancer(ALB) 
- Application will be hosted for a predefined Domain taken from variable & ACM issued SSL certificate will be attached to ALB 443 listener. 
- User will get notified when servers are scaled-out or scaled-in through a SNS notification mail 
- After provisiong the entire infrastructure You need to point/map the ***ALB endpoint*** with ***Domain*** on domain's control panel. 

## System Requirements
### Followings  are needed to be available on your local system:
- aws cli
- terraform
## What to Do?
Create an aws connection profile using aws-cli: 

- ` aws configure set  profile <name> `
- ` aws configure set aws_access_key_id <access_key> --profile <profilename> `
- ` aws configure set aws_secret_access_key <secret_key> --profile <profilename> `
- mention the <*connection name*> in provider block in main.tf file of root module. 
