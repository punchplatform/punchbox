import json
import os
import subprocess
import zipfile
from pathlib import Path
from typing import Dict, List

import click
import jinja2
import yaml

COMPONENTS = ["punch", "minio", "zookeeper", "spark", "elastic", "opendistro_security", "operator", "binaries",
              "analytics-deployment", "analytics-client", "shiva", "gateway", "storm", "kafka", "logstash",
              "metricbeat", "filebeat", "packetbeat", "auditbeat"]

SERVICES = ["zookeeper", "kafka", "shiva_leader", "shiva_worker", "metricbeat"]


def get_components_version(deployer_path: str) -> Dict[str, str]:
    """
    Return a map containing all component version
    """
    data = {}
    versionof_shell = os.path.join(deployer_path, "bin/punchplatform-versionof.sh")
    for component in COMPONENTS:
        cmd = "{0} --legacy {1}".format(versionof_shell, component)
        result = subprocess.check_output(cmd, shell=True)
        data[component] = result.decode("utf-8").rstrip()
    return data


def load_template(template):
    """
    Load Jinja template from file path
    :param template: Template file path
    :return: Jinja2 Template
    """
    template_path = Path(template)
    template_dir = template_path.parent
    loader = jinja2.FileSystemLoader(template_dir)
    env = jinja2.Environment(loader=loader)
    return env.get_template(template_path.name)


def format(dictionary: dict, file_format: str) -> str:
    """
    Format a dictionary
    :param dictionary: Dictionary to format
    :param file_format: Output format (json, yaml)
    """
    if file_format.lower() == "json":
        return json.dumps(dictionary, indent=4)
    elif file_format.lower() == "yaml":
        return yaml.safe_dump(dictionary)
    else:
        raise NotImplementedError(f"Unknown file format {file_format}")


@click.group()
def cli():
    pass


@cli.group()
def generate():
    """
    The generate command lets you generate some of the configuration files you
    will need to deploy a punch.

    Checkout the command described below for each specific target file.
    """
    pass


@generate.command(name="model")
@click.option("--deployer",
              required=True,
              type=click.Path(exists=True),
              help="path to the punch deployer folder")
@click.option("--config", required=True, type=click.File("rb"), help="Configuration file")
@click.option("--output", default=None, type=click.File("w"), help="File where to save model. Default : none")
def generate_model(deployer, config, output):
    """
    This command generates a model.json file that lists all the precise versions
    of all punch components (including the third-party cots). This file is handy
    for you to avoid filling manually that information in your deployment descriptors.
    """
    model_dict = {"versions": get_components_version(deployer)}

    servers = json.loads(config.read())["servers"]
    services_dict = {}
    for s, params in servers.items():
        for service in params["services"]:
            services_dict[service] = services_dict.get(service, []) + [s]
    model_dict = {**model_dict, **{"services": services_dict}}

    json_formated_model = json.dumps(model_dict, indent=4)
    if output is None:
        print(json_formated_model)
    else:
        output.write(json_formated_model)


@cli.command()
@click.option("--archive",
              required=True,
              type=click.Path(exists=True),
              help="path to the punch deployer zip archive"
              )
@click.option("--output",
              required=True,
              type=click.Path(exists=True),
              help="path to the destination folder")
def extract(archive, output):
    """
    Extract the punch deployer archive. The punch deployer archive is a self contained
    zip archive that provides everything you need to deploy a punch.

    It contains
    the various cots (elasticsearch, kafka, etc..) at play, the punch software packages,
    and the punch deployer tool itself in charge of deployoing a complete punch
    on a target servers.
    """
    with zipfile.ZipFile(archive, 'r') as zip_file:
        zip_file.extract(output)


def generate_shiva_servers(servers: List[str], conf, is_leader=False):
    servers_dict = {}
    for server in servers:
        servers_dict[server] = {
            "runner": True,
            "can_be_master": is_leader,
            "tags": conf["tags"]
        }
    return servers_dict


def generate_metricbeat_servers(servers: List[str]):
    servers_dict = {}
    for server in servers:
        servers_dict[server] = {}
    return servers_dict


def generate_spark_workers(servers: List[str], conf, interface):
    slaves = {}
    for server in servers:
        slaves[server] = {
            "listen_interface": interface,
            "slave_port": conf["slave_port"],
            "webui_port": conf["webui_port"]
        }
    return slaves


@generate.command(name="deployment")
@click.option("--model", required=True, type=click.File("rb"), help="Model.json needed to generate deployment")
@click.option("--configuration", required=True, type=click.File("rb"),
              help="File containing all variables needed for deployment")
@click.option("--template", required=True, type=click.Path(exists=True))
@click.option("--output", type=click.File("w"), help="Output file")
def generate_deployment(model, configuration, template, output):
    """
    Generate deployment settings
    """
    model_dict = json.loads(model.read())
    configuration_dict = yaml.load(configuration.read(), Loader=yaml.SafeLoader)

    deployment_template = load_template(template)
    shiva_servers = {}
    for name, servers in model_dict["services"].items():
        if name == "shiva_leader":
            shiva_servers = {**shiva_servers, **generate_shiva_servers(servers, configuration_dict["shiva"], True)}
        elif name == "shiva_worker":
            shiva_servers = {**shiva_servers, **generate_shiva_servers(servers, configuration_dict["shiva"])}
        elif name == "zookeeper":
            configuration_dict["zookeeper"]["servers"] = model_dict["services"][name]
        elif name == "kafka":
            configuration_dict["kafka"]["brokers"] = [{"id": i, "broker": broker} for i, broker in enumerate(servers)]
        elif name == "metricbeat":
            configuration_dict["metricbeat"]["servers"] = generate_metricbeat_servers(servers)
        elif name == "storm_leader":
            configuration_dict["storm"]["masters"] = model_dict["services"][name]
        elif name == "storm_worker":
            configuration_dict["storm"]["slaves"] = model_dict["services"][name]
        elif name == "storm_ui":
            configuration_dict["storm"]["ui_servers"] = model_dict["services"][name]
        elif name == "spark_master":
            configuration_dict["spark"]["masters"] = model_dict["services"][name]
        elif name == "spark_worker":
            configuration_dict["spark"]["slaves"] = generate_spark_workers(servers, configuration_dict["spark"],
                                                                           model_dict["interface"])
        else:
            raise NotImplementedError(f"{name} is not supported yet")

    configuration_dict["shiva"]["servers"] = shiva_servers
    output_txt = deployment_template.render(**configuration_dict, **model_dict)
    output_json = json.dumps(json.loads(output_txt), indent=4)
    if output is not None:
        output.write(output_json)
    else:
        print(output_json)


@generate.command(name="vagrantfile")
@click.option("--configuration",
              required=True,
              type=click.File("rb"),
              help="configuration file containing all vagrant machines configuration")
@click.option("--template", required=True, type=click.Path(exists=True))
@click.option("--output", type=click.File("w"))
def generate_vagrantfile(configuration, template: str, output):
    """
    Generate Vagrantfile
    """
    template_jinja = load_template(template)
    config_dict = json.loads(configuration.read())
    rendered_template = template_jinja.render(**config_dict)

    if output is not None:
        output.write(rendered_template)
    else:
        print(rendered_template)


if __name__ == '__main__':
    cli()
