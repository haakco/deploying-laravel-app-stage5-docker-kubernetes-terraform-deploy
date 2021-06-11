# Stage 5: Kubernetes and Terraform deploy

## Intro

This stage covers how to deploy to kubernetes and set up a local kubernetes development enviroment.

### Pros

* Very repeatable
* Faster from nothing to fully setup
* Can replicate the entire infrastructure for dev or staging.
* Everything documented.
* Simple high availability
* Quick to set up entire enviroment once setup.

### Cons

* Very complicated.
* Takes longer to set up initial scripts.
* Require knowledge for far more application and moving pieces.
* As everything is automated you have to be far more careful not so break something.

## Assumptions

1. Php code is in git.
1. You are using PostgreSQL.
1. If not, replace the PostgreSQL step with your DB of choice.
1. You have a server.
1. In this example and future ones, we'll be deploying to [DigitalOcean](https://m.do.co/c/179a47e69ec8)
   but the steps should mostly work with any servers.
1. The server is running Ubuntu 20.04
1. You have SSH key pair.
1. Needed to log into your server securely.
1. You have a Domain Name, and you can add entries to point to the server.
1. We'll be using example.com here. Just replace that with your domain of choice.
1. For DNS, I'll be using [Cloudflare](https://www.cloudflare.com/) in these examples.
1. I would recommend using a DNS provider that supports [Terraform](https://www.terraform.io/) and
   [LetsEncrypt](https://community.letsencrypt.org/t/dns-providers-who-easily-integrate-with-lets-encrypt-dns-validation/86438)

## Steps 1: Build Docker Images
