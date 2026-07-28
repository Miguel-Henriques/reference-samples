# AWS Bootstrap - TLS Certificates

> This configuration is for domains whose authoritative DNS must remain
> outside Route 53. This includes domains registered with Cloudflare
> Registrar, which does not permit replacing the Cloudflare nameservers.

This Terraform stack creates an AWS Certificate Manager (ACM) certificate
while Cloudflare remains the authoritative DNS provider.

## Usage

### 1. Create the certificate

Copy the example variables and set `domain_name` to your domain:

```shell
cd aws-bootstrap/infra/certs
cp terraform.tfvars.example terraform.tfvars
```

The certificate includes the domain and, by default, its direct wildcard. For
example, `example.com` also includes `*.example.com`.

Initialize Terraform, create the pending certificate, and display the DNS
validation records:

```shell
terraform init
terraform apply
terraform output dns_validation_records
```

### 2. Register the validation records in Cloudflare

1. Open the Cloudflare dashboard and select the registered domain.
2. Open **DNS** and then **Records**.
3. Select **Add record**.
4. Choose type **CNAME**.
5. Copy `name` from a `dns_validation_records` item into **Name**.
6. Copy its `value` into **Target**.
7. Set **Proxy status** to **DNS only**.
8. Repeat for every item and save the records.

Cloudflare may display the record names without the domain suffix. This is
normal.

Set `wait_for_certificate_validation` to `true` in `terraform.tfvars` and run:

```shell
terraform apply
terraform output certificate_status
terraform output validated_certificate_arn
```

Keep the CNAME records in Cloudflare after validation. ACM uses them for
automatic certificate renewal.

### 3. Reference the certificate in your applications

Get the certificate ARN:

```shell
terraform output certificate_arn
```

Pass this ARN to AWS resources that support ACM certificates, such as:

- CloudFront
- Application Load Balancers
- API Gateway custom domains

Certificates are regional. CloudFront requires a certificate in `us-east-1`;
regional services require a certificate in the same region as the resource.

Finally, create the appropriate DNS record in Cloudflare that points your
application hostname to the AWS resource.
