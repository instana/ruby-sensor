#!/usr/bin/env python3

# (c) Copyright IBM Corp. 2023

import json
import logging
import os
import re
import requests
import sys

from github import Github


def ensure_environment_variables_are_present():
    required_env_vars = ('GITHUB_RELEASE_TAG', 'GITHUB_TOKEN',
                         'SLACK_BOT_TOKEN', 'SLACK_CHANNEL_ID_RELEASES')

    for v in required_env_vars:
        if not os.environ.get(v):
            logging.fatal("A required environment variable is missing: %s", v)
            sys.exit(1)


def get_gh_release_info_text_with_token(release_tag, access_token):
    g = Github(access_token)
    repo_name = "instana/ruby-sensor"
    repo = g.get_repo(repo_name)
    release = repo.get_release(release_tag)

    logging.info("GH Release fetched successfully %s", release)

    msg = (
        f":mega: :package: A new version is released in {repo_name}\n"
        f"Name: {release.title}\n"
        f"Tag: {release.tag_name}\n"
        f"Created at: {release.created_at}\n"
        f"Published at: {release.published_at}\n"
        f"{release.body}\n")

    logging.info(msg)
    return msg


def reformat_github_md_to_slack_markup(msg):
    # Based on:
    # https://github.com/atomist/slack-messages/blob
    # /c938c67e957345ba6a0015ca3ace1fd779d0979c/lib/Markdown.ts#LL111C1-L116C44

    msg = re.sub(r'^(\s*)[-*](\s+)', r'\1•\2', msg, flags=re.MULTILINE)
    msg = re.sub(r'(\*|_)\1(\S|\S.*?\S)\1\1(?!\1)', r'<bdmkd>\2</bdmkd>', msg)
    msg = re.sub(r'(\*|_)(?!\1)(\S|\S.*?\S)\1(?!\1)', r'<itmkd>\2</itmkd>', msg)
    msg = msg.replace('<bdmkd>', '*').replace('<itmkd>', '_')
    msg = re.sub(r'^([#]+)\s+([\S ]+)$', r'*\2*', msg, flags=re.MULTILINE)

    # TODO: The message text has to have a partial entity encoding
    # https://api.slack.com/reference/surfaces/formatting#escaping
    # Validate it if we can?
    # A naive replace like this is not enough, because
    # it might already be encoded and then we would encode again.
    #s = s.replace('&', '&amp;')
    #s = s.replace('<', '&lt;')
    #s = s.replace('>', '&gt;')

    # Use the tester here:
    # https://api.slack.com/methods/chat.postMessage/test
    return msg


def post_on_slack_channel(slack_token, slack_channel_id, message_text):
    api_url = "https://slack.com/api/chat.postMessage"

    headers = {"Authorization": f"Bearer {slack_token}",
               "Content-Type": "application/json"}
    body = {"channel": slack_channel_id, "text": message_text}

    response = requests.post(api_url, headers=headers, data=json.dumps(body))
    response_data = json.loads(response.text)

    if response_data["ok"]:
        logging.info("Message sent successfully!")
    else:
        logging.fatal("Error sending message: %s", response_data['error'])


def main():
    # Setting this globally to DEBUG will also debug PyGithub,
    # which will produce even more log output
    logging.basicConfig(level=logging.INFO)
    ensure_environment_variables_are_present()

    msg = get_gh_release_info_text_with_token(os.environ['GITHUB_RELEASE_TAG'],
                                              os.environ['GITHUB_TOKEN'])

    slack_formatted_msg = reformat_github_md_to_slack_markup(msg)

    post_on_slack_channel(os.environ['SLACK_BOT_TOKEN'],
                          os.environ['SLACK_CHANNEL_ID_RELEASES'],
                          slack_formatted_msg)


if __name__ == "__main__":
    main()
