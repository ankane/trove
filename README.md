# Trove

:fire: Deploy machine learning models in Ruby (and Rails)

Works great with [XGBoost](https://github.com/ankane/xgboost), [Torch.rb](https://github.com/ankane/torch.rb), [fastText](https://github.com/ankane/fastText), and many other gems

## Installation

Add this line to your application’s Gemfile:

```ruby
gem 'trove'
```

And run:

```sh
bundle install
trove init
```

And [configure your storage](#storage) in `.trove.yml`.

## Storage

### Amazon S3

Create a bucket and enable object versioning.

Next, set up your AWS credentials. You can use the [AWS CLI](https://github.com/aws/aws-cli):

```sh
pip install awscli
aws configure
```

Or environment variables:

```sh
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_REGION=...
```

IAM users need:

- `s3:GetObject` and `s3:GetObjectVersion` to pull files
- `s3:PutObject` to push files
- `s3:ListBucket` and `s3:ListBucketVersions` to list files and versions
- `s3:DeleteObject` and `s3:DeleteObjectVersion` to delete files

Here’s an example policy:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Trove",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:PutObject",
                "s3:ListBucket",
                "s3:ListBucketVersions",
                "s3:DeleteObject",
                "s3:DeleteObjectVersion"
            ],
            "Resource": [
                "arn:aws:s3:::my-bucket",
                "arn:aws:s3:::my-bucket/trove/*"
            ]
        }
    ]
}
```

If your production servers only need to pull files, only give them `s3:GetObject` and `s3:GetObjectVersion` permissions.

## How It Works

Git is great for code, but it’s not ideal for large files like models. Instead, we use an object store like Amazon S3 to store and version them.

Trove creates a `trove` directory for you to use as a workspace. Files in this directory are ignored by Git but can be pushed and pulled from the object store. By default, files are tracked in `.trove.yml` to make it easy to deploy specific versions with code changes.

## Getting Started

Use the `trove` directory to save and load models.

```ruby
# training code
model.save_model("trove/model.bin")

# prediction code
model = FastText.load_model("trove/model.bin")
```

When a model is ready, push it to the object store with:

```sh
trove push model.bin
```

And commit the changes to `.trove.yml`. The model is now ready to be deployed.

## Deployment

We recommend pulling files during the build process.

- [Heroku and Dokku](#heroku-and-dokku)
- [Docker](#docker)

Make sure your storage credentials are available in the build environment.

### Heroku and Dokku

Add to your `Rakefile`:

```ruby
Rake::Task["assets:precompile"].enhance do
  Trove.pull
end
```

This will pull files at the very end of the asset precompile. Check the build output for:

```text
remote:        Pulling model.bin...
remote:        Asset precompilation completed (30.00s)
```

### Docker

Add to your `Dockerfile`:

```Dockerfile
RUN bundle exec trove pull
```

## Commands

Push a file

```sh
trove push model.bin
```

Pull all files in `.trove.yml`

```sh
trove pull
```

Pull a specific file (uses the version in `.trove.yml` if present)

```sh
trove pull model.bin
```

Pull a specific version of a file

```sh
trove pull model.bin --version 123
```

Delete a file

```sh
trove delete model.bin
```

List files

```sh
trove list
```

List versions

```sh
trove versions model.bin
```

## Ruby API

You can use the Ruby API in addition to the CLI.

```ruby
Trove.push(filename)
Trove.pull
Trove.pull(filename)
Trove.pull(filename, version: version)
Trove.delete(filename)
Trove.list
Trove.versions(filename)
```

This makes it easy to perform operations from code, iRuby notebooks, and the Rails console.

## Automated Training

By default, Trove tracks files in `.trove.yml` so you can deploy specific versions with `trove pull`. However, this functionality is entirely optional. Disable it with:

```yml
vcs: false
```

This is useful if you want to automate training or build more complex workflows.

## History

View the [changelog](https://github.com/ankane/trove/blob/master/CHANGELOG.md)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/trove/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/trove/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features

To get started with development:

```sh
git clone https://github.com/ankane/trove.git
cd trove
bundle install

export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_REGION=...
export S3_BUCKET=my-bucket

bundle exec rake test
```
