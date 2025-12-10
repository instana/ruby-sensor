#!/usr/bin/env python3

# (c) Copyright IBM Corp. 2023

import logging
import os
import re
import sys

import httpx
from github import Github


def ensure_environment_variables_are_present() -> None:
    required_env_vars = (
        "GITHUB_RELEASE_TAG",
        "GITHUB_TOKEN",
        "SLACK_TOKEN",
        "SLACK_SERVICE",
        "SLACK_TEAM",
    )

    for env_var in required_env_vars:
        if env_var not in os.environ:
            logging.fatal(f"❌ A required environment variable is missing: {env_var}")
            sys.exit(1)


def get_gh_release_info_text_with_token(release_tag: str, access_token: str) -> str:
    gh = Github(access_token)
    repo_name = "instana/ruby-sensor"
    repo = gh.get_repo(repo_name)
    release = repo.get_release(release_tag)

    logging.info("GH Release fetched successfully %s", release)

    msg = (
        f":mega: Oyez! Oyez! Oyez!\n"
        f"The Instana Ruby Tracer {release_tag} has been released.\n"
        f":ruby: https://rubygems.org/gems/instana \n"
        f":github: {release.html_url} \n"
        f"**Release Notes:**\n"
        f"{release.body}\n"
    )

    logging.info(msg)
    return msg


def reformat_github_md_to_slack_markup(msg):
    # Based on:
    # https://github.com/atomist/slack-messages/blob
    # /c938c67e957345ba6a0015ca3ace1fd779d0979c/lib/Markdown.ts#LL111C1-L116C44

    msg = re.sub(r"^(\s*)[-*](\s+)", r"\1•\2", msg, flags=re.MULTILINE)
    msg = re.sub(r"(\*|_)\1(\S|\S.*?\S)\1\1(?!\1)", r"<bdmkd>\2</bdmkd>", msg)
    msg = re.sub(r"(\*|_)(?!\1)(\S|\S.*?\S)\1(?!\1)", r"<itmkd>\2</itmkd>", msg)
    msg = msg.replace("<bdmkd>", "*").replace("<itmkd>", "_")
    msg = re.sub(r"^([#]+)\s+([\S ]+)$", r"*\2*", msg, flags=re.MULTILINE)

    # TODO: The message text has to have a partial entity encoding
    # https://api.slack.com/reference/surfaces/formatting#escaping
    # Validate it if we can?
    # A naive replace like this is not enough, because
    # it might already be encoded and then we would encode again.
    # s = s.replace("&", "&amp;")
    # s = s.replace("<", "&lt;")
    # s = s.replace(">", "&gt;")

    # Use the tester here:
    # https://api.slack.com/methods/chat.postMessage/test
    return msg


def post_on_slack_channel(
    slack_team: str, slack_service: str, slack_token: str, message_text: str
) -> None:
    """Send a message to Slack channel."""

    url = (
        f"https://hooks.slack.com/services/T{slack_team}/B{slack_service}/{slack_token}"
    )

    headers = {
        "Content-Type": "application/json",
    }
    body = {"text": message_text}

    with httpx.Client() as client:
        response = client.post(url, headers=headers, json=body)
        response.raise_for_status()

        result = response.text
        if "ok" in result:
            print("✅ Slack message sent successfully")
        else:
            print(f"❌ Slack API error: {result}")


def main():
    # Setting this globally to DEBUG will also debug PyGithub,
    # which will produce even more log output
    logging.basicConfig(level=logging.INFO)
    ensure_environment_variables_are_present()

    msg = get_gh_release_info_text_with_token(
        os.environ["GITHUB_RELEASE_TAG"], os.environ["GITHUB_TOKEN"]
    )

    slack_formatted_msg = reformat_github_md_to_slack_markup(msg)

    post_on_slack_channel(
        os.environ["SLACK_TEAM"],
        os.environ["SLACK_SERVICE"],
        os.environ["SLACK_TOKEN"],
        slack_formatted_msg,
    )


if __name__ == "__main__":
    main()
