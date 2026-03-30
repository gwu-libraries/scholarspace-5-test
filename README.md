# ScholarSpace

## Contributing

If you're working on a PR for this project, create a feature branch off of `main`.

## Production Environment

To deploy via Terraform on AWS, there are a few steps necessary:
- Configure the AWS CLI (https://docs.aws.amazon.com/cli/). Be sure to use an IAM identity that has permissions to manage resources in the given AWS region.
- Make a copy of `example.env` at `.env` and complete environment variables. 
- Store the values of your `.env` in AWS Secrets Manager. This can be done via CLI with:
  - `aws ssm put-parameter --region YOUR-AWS-REGION --name /YOUR/KEY/NAME --type SecureString --value .env --overwrite`
  - Adjust the `YOUR-AWS-REGION` and `/YOUR/KEY/NAME` with your AWS region and a name for the secure string, e.g. `/scholarspace/prod/env`. This value is pulled and decrypted as part of `user_data` script in `main.tf` on deployment.
- Make a copy of `terraform.tfvars.example` named `terraform.tfvars`. This is also where you can configure the EC2 instance type and root volume size. Other necessary variables to configure:
  - `public_key_path` - point to a `.pub` file you have stored locally. `key_name` is the name of the corresponding private key, but can just be name and not a file path. 
  - `ssh_allowed_cidrs` - Array of cidrs (like `10.0.0.0/16`) that will be able to access the EC2 instance via ssh.
  - `ssm_env_parameter_name` MUST be the same as the secure string stored in AWS (e.g. `/scholarspace/prod/env`)
  - `s3_bucket_name` - bucket name that will be used for Fedora repository in S3. 
- Install the Terraform CLI (https://developer.hashicorp.com/terraform/install).
- Run `terraform init` to create the terraform backend file. 
- Run `terraform plan` to see what changes will be applied, and if satisfied, run `terraform apply` to provision the AWS resources. The output should be the public IP for the EC2 instance, though it may take 10-20 minutes for full provisioning, building of docker images, etc. 

If deploying NOT with Terraform, configure `.env` file and your own server/cloud infrastructure, and run `bin/prod`. This should create and migrate the database and start the docker containers in production mode. 

Neither of these approaches seed the database with an admin user or required admin sets and collection types, so that will need to be done manually - see lines in `db/seed.rb` and replicate in a Rails console. 

## Development Environment

This is designed to run on Docker locally and ideally autorefresh when files are changed. 

- `bin/dev` 
  - creates and starts docker containers in development mode.
  - `db-init` runs database create/migrate/seed automatically before `rails` and `worker` start.
  - The app source is bind-mounted into containers, so code edits apply immediately without rebuilding images.

## Tests

`bin/test` if you want to end-to-end test or for CI runs, but this is *slow*, otherwise run development environment, attach to rails container, run `bundle exec rspec`

- Similarly to development environment, this uses a bind mount to sync local and container code.
- The `rspec` service in docker-compose-test.yml runs `RAILS_ENV=test bundle exec rails db:prepare` before `bundle exec rspec`.

