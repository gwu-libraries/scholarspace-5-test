# ScholarSpace

## Contributing

If you're working on a PR for this project, create a feature branch off of `main`.

## Deployment, Development, Testing

### Production Environment

Currently slow because docker images are building on deployment instead of pulling from image repository! Needs to be fixed.

To deploy via Terraform on AWS, there are a few steps necessary:
- Configure the AWS CLI (https://docs.aws.amazon.com/cli/). Be sure to use an IAM identity that has permissions to manage resources in the given AWS region.
- Make a copy of `example.env` at `.env` and complete environment variables. 
- Ensure Fedora credentials are configured for Valkyrie ingest in `FEDORA_USER` and `FEDORA_PASSWORD`.
- Terraform now manages the SSM SecureString value directly from your local `.env` on each `terraform apply`.
  - Set `ssm_env_parameter_name` in `terraform.tfvars` (e.g. `/scholarspace/prod/env`).
  - Optional: set `ssm_env_file_path` (default is `../.env` when running from `terraform/`).
  - No separate `aws ssm put-parameter` step is required for normal deploys.
- Make a copy of `terraform.tfvars.example` named `terraform.tfvars`. This is also where you can configure the EC2 instance type and root volume size. Other necessary variables to configure:
  - `public_key_path` - point to a `.pub` file you have stored locally. `key_name` is the name of the corresponding private key, but can just be name and not a file path. 
  - `ssh_allowed_cidrs` - Array of cidrs (like `10.0.0.0/16`) that will be able to access the EC2 instance via ssh.
  - `ssm_env_parameter_name` MUST be the same as the secure string stored in AWS (e.g. `/scholarspace/prod/env`)
  - `s3_bucket_name` - bucket name that will be used for Fedora repository in S3. 
- Install the Terraform CLI (https://developer.hashicorp.com/terraform/install).
- All Terraform files live in the `terraform/` subdirectory. Run commands from there: `cd terraform`.
- Run `terraform init` to create the terraform backend file. 
- Run `terraform plan` to see what changes will be applied, and if satisfied, run `terraform apply` to provision the AWS resources. The output should be the public IP for the EC2 instance, though it may take 10-20 minutes for full provisioning, building of docker images, etc. 

#### Security Group Rule Migration (Import Existing Rules)

If you convert inline `aws_security_group` ingress blocks to standalone `aws_security_group_rule` resources, AWS rules that already exist can cause duplicate-rule errors on apply. Use this import workflow to migrate without downtime:

1. Add the target `aws_security_group_rule` resources in Terraform code.
2. Run `terraform plan` and confirm Terraform wants to create rules that already exist in AWS.
3. Import each existing rule into state before apply.
4. Re-run `terraform plan` and verify there is no duplicate create for those rules.
5. Run `terraform apply`.

Example imports (replace IDs with your environment values):

```bash
cd terraform

# HTTP from ALB SG to app host SG
terraform import \
  aws_security_group_rule.web_server_http_from_alb \
  "sg-APPHOST_ingress_tcp_80_80_sg-ALB"

# SSH from a single CIDR to app host SG
terraform import \
  'aws_security_group_rule.web_server_ssh_from_cidrs[0]' \
  "sg-APPHOST_ingress_tcp_22_22_203.0.113.10/32"
```

Notes:
- Import ID format for security group rules is: `<sg-id>_<type>_<protocol>_<from-port>_<to-port>_<source>`
- If SSH uses multiple CIDRs, model/import each rule individually (for example, `for_each` by CIDR) instead of one resource with many CIDRs.
- If state and AWS diverge during migration, avoid `terraform destroy`; use targeted `terraform import`, `terraform state rm`, and re-plan until convergence.

### Sidekiq On ECS (Production)

Production Terraform now runs web and workers on ECS/Fargate and keeps only backing services on EC2:
- EC2 bootstraps backing services (`postgres`, `redis`, `fedora`, `solr`, `memcached`, `fits`) via `bin/prod`.
- Terraform provisions ECS/Fargate services for Rails web and Sidekiq (`default` and `whisper`) with autoscaling policies.
- Terraform also provisions ECR repositories for both web and worker images.

To enable ECS workloads:
1. Apply Terraform once to create infrastructure and retrieve `web_ecr_repository_url` and `sidekiq_ecr_repository_url`.
2. Build and push images to those repositories (or set `web_image` / `sidekiq_image` to other registry URIs).
3. Set desired counts and autoscaling limits in `terraform.tfvars`:
  - `web_desired_count`, `web_min_capacity`, `web_max_capacity`
  - `sidekiq_default_desired_count`, `sidekiq_default_min_capacity`, `sidekiq_default_max_capacity`
  - `sidekiq_whisper_desired_count`, `sidekiq_whisper_min_capacity`, `sidekiq_whisper_max_capacity`
  - Optional log-based scaling knobs:
    - `sidekiq_enable_log_based_autoscaling`
    - `sidekiq_log_autoscaling_pattern`
    - `sidekiq_log_autoscaling_threshold`
    - `sidekiq_log_scale_out_adjustment`
4. Re-apply Terraform.

Important notes:
- The ECS task command reads the existing secure-string `.env` content from SSM using `ssm_env_parameter_name` and exports it before running Sidekiq.
- Because database/redis/fedora/solr/fits/memcached still run on EC2 in this setup, ECS tasks are configured to connect to the EC2 private IP.
- Sidekiq desired counts in Terraform default to `0` to avoid failed ECS deployments before an image is published.
- Rails web traffic is served by ALB -> ECS tasks directly (no Nginx container required on EC2).
- Sidekiq logs are written to CloudWatch per service (`/ecs/<site_prefix>/sidekiq/default` and `/ecs/<site_prefix>/sidekiq/whisper`).
- If log-based autoscaling is enabled, Terraform creates log metric filters and CloudWatch alarms that trigger step scale-out policies. The filter pattern must match real Sidekiq queue pressure log lines in your environment.

If you would like to monitor the docker build process on deployment, you can `tail -f /var/log/cloud-init-output.log`. 

If deploying NOT with Terraform, configure `.env` file and your own server/cloud infrastructure, and run `bin/prod`. This should create and migrate the database and start the docker containers in production mode. 

Neither of these approaches seed the database with an admin user or required admin sets and collection types, so that will need to be done manually - see lines in `db/seed.rb` and replicate in a Rails console. 

### Development Environment

This is designed to run on Docker locally and ideally autorefresh when files are changed. 

- `bin/dev` 
  - creates and starts docker containers in development mode.
  - `db-init` runs database create/migrate/seed automatically before `rails` and `worker` start.
  - The app source is bind-mounted into containers, so code edits apply immediately without rebuilding images.

### Tests

`bin/test` if you want to end-to-end test or for CI runs, but this is *slow*, otherwise run development environment, attach to rails container, run `bundle exec rspec`

- Similarly to development environment, this uses a bind mount to sync local and container code.
- The `rspec` service in docker-compose-test.yml runs `RAILS_ENV=test bundle exec rails db:prepare` before `bundle exec rspec`.

# Customizations/Deviations from Hyrax

## Solr Indexing with HOCR

We are utilizing the [Solr OCR Highlighting](https://github.com/dbmdz/solr-ocrhighlighting/) plugin, which allows for indexing of bounding boxes that can be utilized in IIIF content search. See `app/indexers/concerns/ocr_text_indexable.rb` for information on how this indexing process works.

## Derivatives

We are not utilizing the Hyrax derivative pipeline, and instead opting to only generate the derivatives we need for display purposes. The purpose of this change is to:
1. Persist derivatives in Fedora. Service files - including HOCR, VTT, and thumbnail images - may be created or edited by archivists and librarians and we want to ensure that their work is preserved. This adds to the repository size, thus the desire to limit the number of derivatives generated to only necessary ones, but also preserves a record of how files should be presented to end users. 
2. Provide a workflow for admin/content-admin users to modify these service files, primarily for correction of machine generated transcriptions of A/V content or OCR extraction, and have these changes reflected in the display. 
3. Provide some more customizability to our pipeline, such as using Whisper for generating VTT files. 

Derivatives we are generating:


| Derivative | Scenario | Purpose |
| -------- | -------- | -------- |
| .vtt file | On deposit of audio/visual content | These are machine generated transcripts using whispercpp with the base model. To configure the model used to generate the transcription, see `app/services/scholarspace_derivatives_services/concerns/vtt_generatable.rb` and adjust the `Whisper::Context.new('base')` line (This should be extracted to a config setting). These are used for rendering video transcripts in RAMP media player. |
| REPRESENTATIVE_THUMBNAIL.jpeg    | Generated for images, PDFs and video content. | To adjust the thumbnail that is used for a work, update this file. (We do not have auto resizing set up for when the thumbnail is updated, only when created. For now, please be kind and use a small image if you upload a new one!) |
| *_THUMBNAIL.jpg    | Generated for images. | Used for individual image thumbnail bar in Clover |
| .pdf file | On deposit of a collection of images | In the situation where a user has a collection of scanned images representing pages of text, they can upload a series of images for OCR extraction and joining into a PDF for rendering as a text document. |
| *_HOCR.hocr | On deposit of a PDF without preembedded text, and on deposit of images or collections of images. | These files are used for several display and accessibility purposes. For PDF files without embedded text, this is used for overlaying text on top of PDF. For images, this is used for OCR extraction, text indexing of image content, and IIIF search via Clover. This modification is so users can edit HOCR files and have the changes reflected in search and rendering, without updating the actual deposited file by re-embedding text. (There are pros and cons to this approach, with the primary con being not using built in browser PDF embed functionality/PDFJS. It is possible we decide to switch the workflow to re-embed PDFs with text as HOCR files are edited to achieve that, but for now a future problem)|

## Display Changes

### React on Rails

We are utilizing React on Rails to be able to embed React components, without necessitating rewriting all view pages in one pass to work with React. At the moment, this is primarily used on the work show pages and is configured for use in the homepage, and ultimately we will probably want to move our catalog page to use this setup for browsing and advanced search functionality. 

React components are defined in `/app/javascript/bundles` and `/app/javascript/packs`. These are picked up by our asset pipeline, and can be used in views like so:

```ruby
<%
  provide :page_title, application_name
  add_page_js_pack('homepage-bundler')
%>

<% content_for(:head) do %>
  <%= render_page_pack_tags %>
<% end %>

<div class="row home-content">
  <%= react_component(
    'Homepage',
    props: @homepage_props,
    prerender: false,
    html_options: { data: { turbo_cache: false } }
  ) %>
</div>

```

Our current approach involves defining serializer classes, under `/app/serializers` for each page that we are converting into React components, which parse the IIIF manifest and any other information from the respective controllers into JSON, which is passed to the `<%= react_component(...)%>` block as props.

### Clover

We are utilizing Clover as our IIIF viewer for image content. Along with some tweaks to IIIF manifest generation and Solr indexing, this allows us to us IIIF content search on OCRed image documents. 

### Ramp

We are utilizing RAMP as our A/V content viewer, primarily because it provides a nice interface when given an associated VTT transcription file, allowing for auto-scrolling of transcripts with A/V playing, embedded captions, and the ability to do search within a transcript and jump to relevant time stamps in the A/V location. 

### PDF Viewer

We are not using PDFJS for the reasons mentioned above with the pros/cons of dealing with editable embedded text. The current system involves using React to generate an overlay for the PDF rendering with bounding boxes and words from the HOCR file if the PDF does not have pre-embedded text, and otherwise just using the version with pre-embedded text. 

## Fedora 6

???