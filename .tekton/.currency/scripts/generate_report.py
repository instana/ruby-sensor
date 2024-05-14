# Standard Libraries
import re
from json import load

# Third Party
from requests import get
from pandas import DataFrame
from bs4 import BeautifulSoup

JSON_FILE = "resources/table.json"
REPORT_FILE = "docs/report.md"
TEKTON_CI_OUT_FILE = "resources/tekton-ci-output.txt"
API_V1_ENDPOINT = "https://rubygems.org/api/v1/versions/"
LATEST_SUPPORTED_RUBY_VERSION = "3.3.0"


def get_latest_stable_ruby_version():
    url = "https://www.ruby-lang.org/en/downloads/"
    page = get(url)
    soup = BeautifulSoup(page.text, "html.parser")
    text = soup.find(string=re.compile("The current stable version is")).text
    pattern = "(\d+\.\d+\.?\d*)"
    latest_stable_ruby_version = re.search(pattern, text)[1]
    return latest_stable_ruby_version


def get_upstream_version(dependency):
    """get the latest version available upstream"""
    if dependency != "rails lts":
        response = get(f"{API_V1_ENDPOINT}/{dependency}/latest.json")
        response_json = response.json()
        latest_version = response_json["version"]
    else:
        url = "https://makandracards.com/railslts/16137-installing-rails-lts/read"
        page = get(url)
        soup = BeautifulSoup(page.text, "html.parser")
        text = soup.findAll("li")[-1].text
        pattern = "(\d+\.\d+\.?\d*)"
        latest_version = re.search(pattern, text)[1]
    return latest_version


with open(TEKTON_CI_OUT_FILE) as file:
    content = file.read()


def get_last_supported_version(dependency):
    """get up-to-date supported version"""
    pattern = r" ([^\s]+)"

    last_supported_version = re.search(dependency + pattern, content, flags=re.I | re.M)

    return last_supported_version[1]


def isUptodate(last_supported_version, latest_version):
    if last_supported_version == latest_version:
        up_to_date = "Yes"
    else:
        up_to_date = "No"

    return up_to_date

def main():
    # Read the JSON file
    with open(JSON_FILE) as file:
        data = load(file)

    items = data["table"]

    for item in items:
        package = item["Package name"]
        package = package.lower().replace("::", "-")

        if package == "net-http":
            last_supported_version = LATEST_SUPPORTED_RUBY_VERSION
            latest_version = get_latest_stable_ruby_version()

        else:
            latest_version = get_upstream_version(package)

            if not package in ["rails lts", "rails-api"]:
                last_supported_version = get_last_supported_version(package)
            else:
                last_supported_version = latest_version

        up_to_date = isUptodate(last_supported_version, latest_version)

        item.update(
            {
                "Last Supported Version": last_supported_version,
                "Latest version": latest_version,
                "Up-to-date": up_to_date,
            },
        )

    # Create a DataFrame from the list of dictionaries
    df = DataFrame(items)
    df.insert(len(df.columns) - 1, "Cloud Native", df.pop("Cloud Native"))

    # Convert dataframe to markdown
    markdown_table = df.to_markdown(index=False)

    disclaimer = f"##### This page is auto-generated. Any change will be overwritten after the next sync. Please apply changes directly to the files in the [ruby tracer](https://github.com/instana/ruby-sensor) repo."
    title = "## Ruby supported packages and versions"

    # Combine disclaimer, title, and markdown table with line breaks
    final_markdown = disclaimer + "\n" + title + "\n" + markdown_table

    with open(REPORT_FILE, "w") as file:
        file.write(final_markdown)

if __name__ == "__main__":
    main()
