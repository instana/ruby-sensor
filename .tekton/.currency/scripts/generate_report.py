# Standard Libraries
import glob
import re
from json import load
from datetime import datetime

# Third Party
from requests import get
from pandas import DataFrame
from bs4 import BeautifulSoup

JSON_FILE = "resources/table.json"
REPORT_FILE = "docs/report.md"
API_V1_ENDPOINT = "https://rubygems.org/api/v1/versions/"
GEM_INFO_ENDPOINT = "https://rubygems.org/api/v1/gems/"


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
        "sequel": "sequel_58_ruby_3.3.",
    }

    bundle_install_output = ""

    for library, pattern in libraries_from_logs.items():
        glob_result = glob.glob(f"../../dep_{pattern}*")

        if not glob_result:
            print(f"Could not find bundle install log for gem '{library}'.")
            continue

        with open(glob_result[0], "r") as file:
            logs = file.read().replace("\n", " ")

        if "Installing" not in logs:
            print(f"Unable to retrieve logs from for gem '{library}'.")
            continue

        print(f"Retrieving currency for gem '{library}'.")
        match = re.search(f"Installing ({library} [^\s]+)", logs)
        bundle_install_output += f"{match[1]}\n"

    return bundle_install_output


def estimate_days_behind(release_date, last_supported_release_date):
    """Calculate days between release dates"""
    latest_date = datetime.strptime(release_date, "%Y-%m-%d")
    supported_date = datetime.strptime(last_supported_release_date, "%Y-%m-%d")
    days_diff = (latest_date - supported_date).days
    return max(0, days_diff)


def get_upstream_version(dependency):
    """get the latest version available upstream and release date"""
    if dependency != "rails lts":
        try:
            response = get(f"{API_V1_ENDPOINT}{dependency}/latest.json")
            if not response:
                return "Unknown", "Unknown"

            response_json = response.json()
            latest_version = response_json["version"]

            gem_info_response = get(f"{GEM_INFO_ENDPOINT}{dependency}.json")
            if not gem_info_response:
                return latest_version, "Unknown"
            gem_info = gem_info_response.json()

            version_info_response = get(f"{API_V1_ENDPOINT}{dependency}.json")
            if not version_info_response:
                return latest_version, "Unknown"
            version_info = version_info_response.json()

            latest_version_release_date = None
            for version_data in version_info:
                if version_data["number"] == latest_version:
                    if "created_at" in version_data:
                        created_at = version_data["created_at"]
                        latest_version_release_date = datetime.strptime(
                            created_at, "%Y-%m-%dT%H:%M:%S.%fZ"
                        ).strftime("%Y-%m-%d")
                    break

            if not latest_version_release_date and "created_at" in gem_info:
                created_at = gem_info["created_at"]
                latest_version_release_date = datetime.strptime(
                    created_at, "%Y-%m-%dT%H:%M:%S.%fZ"
                ).strftime("%Y-%m-%d")

            if not latest_version_release_date:
                latest_version_release_date = "Unknown"
                print(f"Could not find release date for {dependency}")

            return latest_version, latest_version_release_date
        except Exception as e:
            return "Unknown", "Unknown"
    else:
        try:
            initial_response = get(
                "https://makandracards.com/railslts/16137-installing-rails-lts/read"
            )
            if not initial_response:
                return "Unknown", "Unknown"

            initial_soup = BeautifulSoup(initial_response.text, "html.parser")

            text = initial_soup.find_all("li")[-1].text
            pattern = "(\d+\.\d+\.?\d*)"
            latest_version_match = re.search(pattern, text)

            latest_version = "Unknown"
            if latest_version_match:
                latest_version = latest_version_match[1]
            rails_lts_links = initial_soup.find_all("a", href=re.compile(r"railslts"))
            latest_rails_lts_link = None
            latest_version_num = 0.0

            for link in rails_lts_links:
                href = link.get("href", "")
                link_text = link.text.strip()

                if "Installing Rails" in link_text:
                    version_match = re.search(r"Installing Rails (\d+\.\d+)", link_text)
                    if version_match:
                        version_str = version_match.group(1)
                        try:
                            version_num = float(version_str)
                            if version_num > latest_version_num:
                                latest_version_num = version_num
                                latest_rails_lts_link = href
                                latest_version = version_str
                        except ValueError:
                            pass

            latest_version_release_date = None

            if latest_rails_lts_link:
                if latest_rails_lts_link.startswith("/"):
                    full_url = f"https://makandracards.com{latest_rails_lts_link}"
                else:
                    full_url = latest_rails_lts_link

                detail_response = get(full_url)
                if detail_response:
                    detail_soup = BeautifulSoup(detail_response.text, "html.parser")

                    time_tags = detail_soup.find_all(
                        "time", attrs={"data-relative": "true"}
                    )
                    for time_tag in time_tags:
                        if "Updated" in time_tag.parent.text:
                            if "datetime" in time_tag.attrs:
                                datetime_str = time_tag["datetime"]
                                try:
                                    date_obj = datetime.strptime(
                                        datetime_str, "%Y-%m-%dT%H:%M:%SZ"
                                    )
                                    latest_version_release_date = date_obj.strftime(
                                        "%Y-%m-%d"
                                    )
                                    break
                                except ValueError:
                                    try:
                                        date_obj = datetime.strptime(
                                            datetime_str, "%Y-%m-%dT%H:%M:%S.%fZ"
                                        )
                                        latest_version_release_date = date_obj.strftime(
                                            "%Y-%m-%d"
                                        )
                                        break
                                    except ValueError as e:
                                        print(f"Error parsing datetime: {e}")

            if not latest_version_release_date:
                latest_version_release_date = datetime.now().strftime("%Y-%m-%d")
            return latest_version, latest_version_release_date

        except Exception as e:
            print(f"Error getting Rails LTS information: {str(e)}")
            return "Unknown", datetime.now().strftime("%Y-%m-%d")


def get_version_release_date(dependency, version):
    if dependency == "rails lts":
        _, release_date = get_upstream_version(dependency)
        return release_date

    try:
        response = get(f"{API_V1_ENDPOINT}/{dependency}.json")
        if not response:
            print(f"Failed to get version info for {dependency}")
            return "Unknown"

        version_info = response.json()
        for version_data in version_info:
            if version_data["number"] == version and "created_at" in version_data:
                created_at = version_data["created_at"]
                release_date = datetime.strptime(
                    created_at, "%Y-%m-%dT%H:%M:%S.%fZ"
                ).strftime("%Y-%m-%d")
                return release_date
    except Exception as e:
        print(f"Error getting release date for {dependency} {version}: {str(e)}")

    return "Unknown"


def get_last_supported_version(bundle_install_output, dependency):
    """get up-to-date supported version"""
    pattern = r" ([^\s]+)"

    last_supported_version = re.search(
        dependency + pattern, bundle_install_output, flags=re.I | re.M
    )

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

        latest_version, release_date = get_upstream_version(package)
        if package not in ["rails lts", "rails-api"]:
            last_supported_version = get_last_supported_version(
                bundle_install_output, package
            )
        else:
            last_supported_version = latest_version

        last_supported_version_release_date = get_version_release_date(
            package, last_supported_version
        )

        up_to_date = isUptodate(last_supported_version, latest_version)

        days_behind = "0 day/s"
        if (
            up_to_date == "No"
            and release_date != "Unknown"
            and last_supported_version_release_date != "Unknown"
        ):
            days = estimate_days_behind(
                release_date, last_supported_version_release_date
            )
            days_behind = f"{days} day/s"

        item.update(
            {
                "Last Supported Version": last_supported_version,
                "Latest version": latest_version,
                "Up-to-date": up_to_date,
                "Release date": release_date,
                "Latest Version Published At": last_supported_version_release_date,
                "Days behind": days_behind,
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
