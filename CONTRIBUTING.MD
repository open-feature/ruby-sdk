# Contributing to the OpenFeature project

## Development

You can contribute to this project from a Windows, macOS or Linux machine.

On all platforms, the minimum requirements are:

* Git client and command line tools.
* Ruby 3.0 or higher

## Pull Request

All contributions to the OpenFeature project are welcome via GitHub pull requests.

To create a new PR, you will need to first fork the GitHub repository and clone upstream.

```bash
git clone https://github.com/open-feature/ruby-sdk.git openfeature-ruby-sdk
```

Navigate to the repository folder
```bash
cd openfeature-ruby-sdk
```

Add your fork as an origin
```bash
git remote add fork https://github.com/YOUR_GITHUB_USERNAME/ruby-sdk.git
```

To start working on a new feature or bugfix, create a new branch and start working on it.

```bash
git checkout -b feat/NAME_OF_FEATURE
# Make your changes
git commit
git push fork feat/NAME_OF_FEATURE
```

Open a pull request against the main ruby-sdk repository.

### Running checks locally

#### Unit tests

To run unit tests and other checks:

```bash
bundle exec rake
```

### How to Receive Comments

* If the PR is not ready for review, please mark it as
  [`draft`](https://github.blog/2019-02-14-introducing-draft-pull-requests/).
* Make sure all required CI checks are clear.
* Submit small, focused PRs addressing a single concern/issue.
* Make sure the PR title reflects the contribution.
* Write a summary that helps understand the change.
* Include usage examples in the summary, where applicable.

### How to Get PRs Merged

A PR is considered to be **ready to merge** when:

* Major feedbacks are resolved.
* It has been open for review for at least one working day. This gives people
  reasonable time to review.
* Trivial change (typo, cosmetic, doc, etc.) doesn't have to wait for one day.
* Urgent fix can take exception as long as it has been actively communicated.

Any Maintainer can merge the PR once it is **ready to merge**. Note, that some
PRs may not be merged immediately if the repo is in the process of a release and
the maintainers decided to defer the PR to the next release train.

If a PR has been stuck (e.g. there are lots of debates and people couldn't agree
on each other), the owner should try to get people aligned by:

* Consolidating the perspectives and putting a summary in the PR. It is
  recommended to add a link into the PR description, which points to a comment
  with a summary in the PR conversation.
* Tagging subdomain experts (by looking at the change history) in the PR asking
  for suggestion.
* Reaching out to more people on the [CNCF OpenFeature Slack channel](https://cloud-native.slack.com/archives/C0344AANLA1).
* Stepping back to see if it makes sense to narrow down the scope of the PR or
  split it up.
* If none of the above worked and the PR has been stuck for more than 2 weeks,
  the owner should bring it to the OpenFeatures [meeting](README.md#contributing).

## Automated Changelog

Each time a release is published the changelogs will be generated automatically using `release-please`.

## Design Choices

As with other OpenFeature SDKs, ruby-sdk follows the
[openfeature-specification](https://github.com/open-feature/spec).
