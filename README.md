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
- Store the values of your `.env` in AWS Secrets Manager. This can be done via CLI with:
  - `aws ssm put-parameter --region YOUR-AWS-REGION --name /YOUR/KEY/NAME --type SecureString --value "$(cat .env)" --overwrite`
  - Adjust the `YOUR-AWS-REGION` and `/YOUR/KEY/NAME` with your AWS region and a name for the secure string, e.g. `/scholarspace/prod/env`. This value is pulled and decrypted as part of `user_data` script in `main.tf` on deployment.
- Make a copy of `terraform.tfvars.example` named `terraform.tfvars`. This is also where you can configure the EC2 instance type and root volume size. Other necessary variables to configure:
  - `public_key_path` - point to a `.pub` file you have stored locally. `key_name` is the name of the corresponding private key, but can just be name and not a file path. 
  - `ssh_allowed_cidrs` - Array of cidrs (like `10.0.0.0/16`) that will be able to access the EC2 instance via ssh.
  - `ssm_env_parameter_name` MUST be the same as the secure string stored in AWS (e.g. `/scholarspace/prod/env`)
  - `s3_bucket_name` - bucket name that will be used for Fedora repository in S3. 
- Install the Terraform CLI (https://developer.hashicorp.com/terraform/install).
- Run `terraform init` to create the terraform backend file. 
- Run `terraform plan` to see what changes will be applied, and if satisfied, run `terraform apply` to provision the AWS resources. The output should be the public IP for the EC2 instance, though it may take 10-20 minutes for full provisioning, building of docker images, etc. 

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