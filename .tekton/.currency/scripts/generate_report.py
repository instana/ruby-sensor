# Standard Libraries
import re
from json import load

# Third Party
from requests import get
from pandas import DataFrame
from bs4 import BeautifulSoup
from kubernetes import client, config

JSON_FILE = "resources/table.json"
REPORT_FILE = "docs/report.md"
API_V1_ENDPOINT = "https://rubygems.org/api/v1/versions/"
LATEST_SUPPORTED_RUBY_VERSION = "3.3.1"

def filter_taskruns(taskrun_filter, taskruns):
    filtered_taskruns = list(filter(taskrun_filter, taskruns))
    filtered_taskruns.sort(
        key=lambda tr: tr["metadata"]["creationTimestamp"], reverse=True
    )

    return filtered_taskruns


def get_taskruns(namespace, task_name):
    group = "tekton.dev"
    version = "v1"
    plural = "taskruns"

    # access the custom resource from tekton
    tektonV1 = client.CustomObjectsApi()
    taskruns = tektonV1.list_namespaced_custom_object(
        group,
        version,
        namespace,
        plural,
        label_selector=f"{group}/task={task_name}, triggers.tekton.dev/trigger=ruby-tracer-scheduled-pipeline-triggger",
    )["items"]

    return taskruns


def process_taskrun_logs(
    taskruns, core_v1_client, namespace, task_name, library, tekton_ci_output
):
    for tr in taskruns:
        pod_name = tr["status"]["podName"]
        taskrun_name = tr["metadata"]["name"]
        logs = core_v1_client.read_namespaced_pod_log(
            pod_name, namespace, container="step-unittest"
        )
        if "Installing" in logs:
            print(
                f"Retrieving container logs from the successful taskrun pod {pod_name} of taskrun {taskrun_name}.."
            )
            match = re.search(f"Installing ({library} [^\s]+)", logs)
            tekton_ci_output += f"{match[1]}\n"
            break
        else:
            print(
                f"Unable to retrieve container logs from the successful taskrun pod {pod_name} of taskrun {taskrun_name}."
            )
    return tekton_ci_output


def get_tekton_ci_output():
    # config.load_kube_config()
    config.load_incluster_config()

    namespace = "default"
    core_v1_client = client.CoreV1Api()

    default_libraries_dict = {
        "cuba": 1,
        "excon": 4,
        "graphql": 6,
        "grpc": 7,
        "rack": 10,
        "rest-client": 11,
        "roda": 13,
        "sinatra": 16,
    }

    tekton_ci_output = ""
    task_name = "ruby-tracer-unittest-default-libraries-task"
    default_taskruns = get_taskruns(namespace, task_name)

    for library, pattern in default_libraries_dict.items():
        taskrun_filter = (
            lambda tr: tr["metadata"]["name"].endswith(
                f"unittest-default-ruby-33-{pattern}"
            )
            and tr["status"]["conditions"][0]["type"] == "Succeeded"
        )
        filtered_default_taskruns = filter_taskruns(taskrun_filter, default_taskruns)

        tekton_ci_output = process_taskrun_logs(
            filtered_default_taskruns,
            core_v1_client,
            namespace,
            task_name,
            library,
            tekton_ci_output,
        )

    other_libraries_dict = {
        "rails": {
            "pattern": "rails-postgres-11",
            "task_name": "ruby-tracer-unittest-rails-postgres-task",
        },
        "dalli": {
            "pattern": "memcached-11",
            "task_name": "ruby-tracer-unittest-memcached-libraries-task",
        },
        "resque": {
            "pattern": "unittest-redis-ruby-32-33-9",
            "task_name": "ruby-tracer-unittest-redis-libraries-task",
        },
        "sidekiq": {
            "pattern": "unittest-redis-ruby-32-33-18",
            "task_name": "ruby-tracer-unittest-redis-libraries-task",
        },
    }

    for library, inner_dict in other_libraries_dict.items():
        pattern = inner_dict["pattern"]
        task_name = inner_dict["task_name"]
        taskrun_filter = (
            lambda tr: tr["metadata"]["name"].endswith(pattern)
            and tr["status"]["conditions"][0]["type"] == "Succeeded"
        )
        other_taskruns = get_taskruns(namespace, task_name)
        filtered_other_taskruns = filter_taskruns(taskrun_filter, other_taskruns)

        tekton_ci_output = process_taskrun_logs(
            filtered_other_taskruns,
            core_v1_client,
            namespace,
            task_name,
            library,
            tekton_ci_output,
        )

    return tekton_ci_output


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


def get_last_supported_version(tekton_ci_output, dependency):
    """get up-to-date supported version"""
    pattern = r" ([^\s]+)"

    last_supported_version = re.search(dependency + pattern, tekton_ci_output, flags=re.I | re.M)

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

    tekton_ci_output = get_tekton_ci_output()

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
                last_supported_version = get_last_supported_version(tekton_ci_output, package)
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
