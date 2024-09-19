# Standard Libraries
import glob
import re
from json import load

# Third Party
from requests import get
from pandas import DataFrame
from bs4 import BeautifulSoup

JSON_FILE = "resources/table.json"
REPORT_FILE = "docs/report.md"
API_V1_ENDPOINT = "https://rubygems.org/api/v1/versions/"

def get_bundle_install_output():

    libraries_from_logs = {
        "cuba": "cuba_40_ruby_3.3.",
        "excon": "excon_100_ruby_3.3.",
        "graphql": "graphql_20_ruby_3.3.",
        "grpc": "grpc_10_ruby_3.3.",
        "rack": "rack_30_ruby_3.3.",
        "rest-client": "rest_client_20_ruby_3.3.",
        "roda": "roda_30_ruby_3.3.",
        "sinatra": "sinatra_40_ruby_3.3.",
        "net-http": "net_http_01_ruby_3.1.",
        "rails": "rails_71_sqlite3_ruby_3.3.",
        "dalli": "dalli_32_ruby_3.3.",
        "resque": "resque_20_ruby_3.3.",
        "sidekiq": "sidekiq_70_ruby_3.3.",
        "sequel": "sequel_58_ruby_3.3."
    }

    bundle_install_output = ""

    for library, pattern in libraries_from_logs.items():
        glob_result = glob.glob(f"../../dep_{pattern}*")
        if not glob_result:
            print(f"Could not find bundle install log for gem '{library}'.")
            continue

        with open(glob_result[0], 'r') as file:
            logs = file.read().replace('\n', ' ')

        if "Installing" not in logs:
            print( f"Unable to retrieve logs from for gem '{library}'.")
            continue

        print(f"Retrieving currency for gem '{library}'.")
        match = re.search(f"Installing ({library} [^\s]+)", logs)
        bundle_install_output += f"{match[1]}\n"

    return bundle_install_output


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


def get_last_supported_version(bundle_install_output, dependency):
    """get up-to-date supported version"""
    pattern = r" ([^\s]+)"

    last_supported_version = re.search(dependency + pattern, bundle_install_output, flags=re.I | re.M)

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

    bundle_install_output = get_bundle_install_output()

    items = data["table"]

    for item in items:
        package = item["Package name"]
        package = package.lower().replace("::", "-")

        latest_version = get_upstream_version(package)

        if not package in ["rails lts", "rails-api"]:
            last_supported_version = get_last_supported_version(bundle_install_output, package)
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

    disclaimer = "##### This page is auto-generated. Any change will be overwritten after the next sync. Please apply changes directly to the files in the [ruby tracer](https://github.com/instana/ruby-sensor) repo."
    title = "## Ruby supported packages and versions"

    # Combine disclaimer, title, and markdown table with line breaks
    final_markdown = disclaimer + "\n" + title + "\n" + markdown_table

    with open(REPORT_FILE, "w") as file:
        file.write(final_markdown)

if __name__ == "__main__":
    main()
