import json
import os
import subprocess
import zipfile
from pathlib import Path
from typing import Dict

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
    Generate a file (model, deployment settings, ...)
    """
    pass


@generate.command()
@click.option("--deployer", required=True, type=click.Path(exists=True))
@click.option("--config", required=True, type=click.File("rb"), help="Configuration file")
@click.option("--output", default=None, type=click.File("w"), help="File where to save model. Default : none")
def model(deployer, config, output):
    """
    Generate model.json
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
@click.option("--archive", required=True, type=click.Path(exists=True))
@click.option("--output", required=True, type=click.Path(exists=True))
def extract(archive, output):
    """
    Extract archive
    """
    with zipfile.ZipFile(archive, 'r') as zip_file:
        zip_file.extract(output)


@generate.command(name="deployment")
@click.option("--model", required=True, type=click.File("rb"), help="Model.json needed to generate deployment")
@click.option("--template-dir", required=True, type=click.Path(exists=True), help="Jinja template directory")
@click.option("--output", type=click.File("wb"), help="Output file")
def generate_deployment(model, template_dir, output):
    """
    Generate deployment settings
    """
    loader = jinja2.FileSystemLoader(template_dir)
    env = jinja2.Environment(loader=loader)

    res = {}
    for template_file in env.list_templates():
        template = env.get_template(template_file)
        render = template.render(**json.loads(model.read()))
        res = {**res, **json.loads(render)}

    res_json = json.dumps(res, indent=4)

    # TODO: support override variable ?
    if output is not None:
        output.write(res_json)
    else:
        print(res_json)


@generate.command(name="vagrantfile")
@click.option("--configuration", required=True, type=click.File("rb"),
              help="Configuration file containing all vagrant machines configuration")
@click.option("--template", required=True, type=click.Path(exists=True))
@click.option("--output", type=click.File("w"))
def generate_vagrantfile(configuration, template: str, output):
    """
    Generate Vagrantfile
    """
    template_path = Path(template)
    template_dir = template_path.parent

    loader = jinja2.FileSystemLoader(template_dir)
    env = jinja2.Environment(loader=loader)
    template_jinja = env.get_template(template_path.name)
    config_dict = json.loads(configuration.read())
    rendered_template = template_jinja.render(**config_dict)

    if output is not None:
        output.write(rendered_template)
    else:
        print(rendered_template)



if __name__ == '__main__':
    cli()
