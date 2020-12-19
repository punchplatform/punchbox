import json
import os
import subprocess
import zipfile
from pathlib import Path
from typing import Dict, List

import click
import jinja2
import yaml
import logging

COMPONENTS = [
    "punch", "minio", "zookeeper", "spark",
    "elastic", "opendistro_security", "operator",
    "binaries", "analytics-deployment", "analytics-client",
    "shiva", "gateway", "storm", "kafka", "logstash",
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
    """
    Welcome to punchbox. This punch tool is your easy way to punch deployment and testing.
    \f
    """
    pass

@cli.group()
def deploy():
    """
    Deploy your punch.

    The deploy commands lets you quickly setup and deploy a punch environment
    for development or testing purposes.

    Start with 'setup', then review the generate configuration file. Once happy,
    proceed with 'deploy'.

    The play commands assumes you have an empty workspace folder where all the
    VMs, configuration files will be stored.
    \f
    """
    pass

@deploy.command(name="setup")
@click.option("--deployer",
              required=True,
              type=click.Path(exists=True),
              help="path to the punch deployer folder")
@click.option("--workspace", required=True, default=None, type=click.Path("w"), help="the destination folder")
def setup(deployer, workspace):
    punchBoxDir = os.environ.get('PUNCHBOX_DIR')
    confDir = workspace+"/conf"
    confFile = confDir + "/punchbox.yml"
    dictionary = {
        'env' : {
            "punchbox_dir": os.environ.get('PUNCHBOX_DIR'),
            "workspace" : os.path.abspath(workspace),
            "deployer" : os.path.abspath(deployer)
        },
        'vagrant' : {
            "template" : os.path.abspath(punchBoxDir + '/vagrant/Vagrantfile.j2'),
            "vagrantfile" : os.path.abspath(workspace + '/vagrant/Vagrantfile')
        },
        'punch' : {
            "platform_topology" : os.path.abspath(punchBoxDir + '/configurations/complete_topology.json'),
            "platform_settings" : os.path.abspath(punchBoxDir + '/configurations/punch_vagrant_setting.yml'),
            "deployment_settings_template" : os.path.abspath(punchBoxDir + '/templates/deployment-settings.j2'),
            "platform_descriptor" : os.path.abspath(workspace + '/conf/platform_descriptor.yml'),
            "deployment_settings" : os.path.abspath(workspace + '/conf/deployment-settings.json')
        }
    }
    if not os.path.exists(confDir):
        os.makedirs(confDir)
    if  not os.path.exists(confFile) or click.confirm('Overwrite '+confFile+' ?'):
        with open(confFile, 'w+') as outfile:
            yaml.dump(dictionary, outfile)
        print('All done. Checkout and review '+confFile )
        print('You are then ready to deploy')

@deploy.command(name="deploy")
@click.option("--workspace", required=True, default=None, type=click.Path("w"), help="the destination folder")
@click.option('--interactive', '-i', is_flag=True, default=False, help="interactive mode")
@click.pass_context
def deploy(ctx, workspace, interactive):
    conf = {}
    with open(workspace+"/conf/punchbox.yml") as infile:
        conf = yaml.load(infile.read(), Loader=yaml.SafeLoader)

    punchBoxDir = conf['env']['punchbox_dir']
    if not interactive or click.confirm('generate vagrantfile '+conf['vagrant']['vagrantfile'] + ' ?'):
        if not os.path.exists(conf['env']['workspace']+'/vagrant'):
            os.makedirs(conf['env']['workspace']+'/vagrant')
        with open(conf['punch']['platform_topology']) as topology, \
                open(conf['vagrant']['vagrantfile'], 'w+') as vagrantfile:
            ctx.invoke(generate_vagrantfile, topology=topology, template=conf['vagrant']['template'], output=vagrantfile)

    if not interactive or click.confirm('generate platform descriptor '+conf['punch']['platform_descriptor'] + ' ?'):
        if not os.path.exists(conf['env']['workspace']+'/vagrant'):
            os.makedirs(conf['env']['workspace']+'/vagrant')
        with open(conf['punch']['platform_topology']) as topology, \
                open(conf['punch']['platform_descriptor'],"w+") as descriptor :
            ctx.invoke(generate_descriptor,  deployer=conf['env']['deployer'], topology=topology, output=descriptor)

    if not interactive or click.confirm('generate deployment settings '+conf['punch']['deployment_settings'] + ' ?'):
        with  open(conf['punch']['deployment_settings_template'],"r") as template, \
                open(conf['punch']['platform_descriptor'],"r") as descriptor, \
                open(conf['punch']['deployment_settings'],"w+") as output, \
            open(conf['punch']['platform_settings'],"r") as settings:
            ctx.invoke(generate_deployment,
                       descriptor=descriptor,
                       settings=settings,
                       template=conf['punch']['deployment_settings_template'],
                       output=output)

@cli.group()
def generate():
    """
    Generate deployment files.

    The generate command lets you generate some of the configuration files you
    will need to deploy a punch. Prefer using the play commands that
    do all that for you.

    The generate commands are used to finley control each intermediate
    configuration file generation.
    \f
    """
    pass

@generate.command(name="descriptor")
@click.option("--deployer",
              required=True,
              type=click.Path(exists=True),
              help="path to the punch deployer folder")
@click.option("--topology", required=True, type=click.File("rb"), help="a punch topology description file")
@click.option("--output", default=None, type=click.File("w"), help="the generated platform inventory descriptor. Default : none")
def generate_descriptor(deployer, topology, output):
    """
    Generate the bootstrap descriptor file.

    This command generates a platform descriptor file required by the punch deployer.
    That file is built from a so called platform topology file that describes your target
    platform in a simple and human readable format.

    It generates a files that contains useful informations such as version numbers for each
    punch components (including the third-party cots). This file is handy
    for you to avoid filling manually that information in your inventories.
    """
    model_dict = {"versions": get_components_version(deployer)}
    servers = yaml.load(topology.read(), Loader=yaml.SafeLoader)["servers"]
    services_dict = {}
    for s, params in servers.items():
        for service in params["services"]:
            services_dict[service] = services_dict.get(service, []) + [s]
    model_dict = {**model_dict, **{"services": services_dict}}
    formated_model = yaml.dump(model_dict)
    if output is None:
        print(formated_model)
    else:
        output.write(formated_model)

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


@generate.command(name="deployment-settings")
@click.option("--descriptor", required=True, type=click.File("rb"),
              help="the platform descriptor file generated using the 'generate descriptor' command")
@click.option("--settings", required=True, type=click.File("rb"),
              help="the punch settings file. It provides all the required settings "
                   "for each component you selected. If you are in doubt use the punchbox "
                   "configurations/punch_defaults.yml file.")
@click.option("--template", required=False, type=click.Path(exists=True),
              help="the deployment template. The default is  "
                   "templates/deployment_settings.j2 in your punchbox. It provides all the required settings ")
@click.option("--output", type=click.File("w"), help="Output file")
def generate_deployment(descriptor, settings, template, output):
    """
        Generate the punch deployment settings file. That file is your input to use the punch
        deployer. It contains the complete and precise settings of all your components.

        That file is, of course, a rich file. Each section of it is fully described in the punch
        online documentation. It is generated from a ready to use template file and the descriptor
        file generated using the 'generate descriptor' command.

        Once you have that file you are good to go to dploy your punch.
    """
    descriptor_dict = yaml.load(descriptor.read(), Loader=yaml.SafeLoader)

    if settings is None:
        punchbox_dir = os.environ.get('PUNCHBOX_DIR')
        if punchbox_dir is None:
            logging.fatal('if you do not provide settings you must set the PUNCHBOX_DIR environment variable')
            exit(1)
        settings = punchbox_dir + '/configurations/punch_vagrant_setting.yml'
        logging.info('using settings '+template)
    settings_dict = yaml.load(settings.read(), Loader=yaml.SafeLoader)

    if template is None:
        punchbox_dir = os.environ.get('PUNCHBOX_DIR')
        if punchbox_dir is None:
            logging.fatal('if you do not provide a deployment-settings.j2 you must set the PUNCHBOX_DIR environment variable')
            exit(1)
        template = punchbox_dir + '/templates/deployment-settings.j2'
        logging.info('using default punch template '+template)
    deployment_template = load_template(template)
    shiva_servers = {}
    for name, servers in descriptor_dict["services"].items():
        if name == "shiva_leader":
            shiva_servers = {**shiva_servers, **generate_shiva_servers(servers, settings_dict["shiva"], True)}
        elif name == "shiva_worker":
            shiva_servers = {**shiva_servers, **generate_shiva_servers(servers, settings_dict["shiva"])}
        elif name == "zookeeper":
            settings_dict["zookeeper"]["servers"] = descriptor_dict["services"][name]
        elif name == "kafka":
            settings_dict["kafka"]["brokers"] = [{"id": i, "broker": broker} for i, broker in enumerate(servers)]
        elif name == "metricbeat":
            settings_dict["metricbeat"]["servers"] = generate_metricbeat_servers(servers)
        elif name == "storm_leader":
            settings_dict["storm"]["masters"] = descriptor_dict["services"][name]
        elif name == "storm_worker":
            settings_dict["storm"]["slaves"] = descriptor_dict["services"][name]
        elif name == "storm_ui":
            settings_dict["storm"]["ui_servers"] = descriptor_dict["services"][name]
        elif name == "spark_master":
            settings_dict["spark"]["masters"] = descriptor_dict["services"][name]
        elif name == "spark_worker":
            settings_dict["spark"]["slaves"] = generate_spark_workers(servers, settings_dict["spark"],
                                                                           descriptor_dict["interface"])
        else:
            raise NotImplementedError(f"{name} is not supported yet")

    if "shiva" in settings_dict:
        settings_dict["shiva"]["servers"] = shiva_servers

    try:
        output_txt = deployment_template.render(**settings_dict, **descriptor_dict)
    except TypeError:
        logging.exception("your deployment-settings.j2 must be wrong")
        print('Your descriptor:')
        print(descriptor_dict)
        print('Your settings:')
        print(settings_dict)
        exit(1)

    output_json = json.dumps(json.loads(output_txt), indent=4)
    if output is not None:
        output.write(output_json)
    else:
        print(output_json)


@generate.command(name="vagrantfile")
@click.option("--topology", required=True, type=click.File("rb"), help="a punch topology description file")
@click.option("--template", required=False, type=click.Path(exists=True))
@click.option("--output", type=click.File("w"))
def generate_vagrantfile(topology, template: str, output):
    """
    Generate Vagrantfile
    """
    if template is None:
        punchbox_dir = os.environ.get('PUNCHBOX_DIR')
        if punchbox_dir is None:
            logging.fatal('if you do not provide a vagrant template file you must set the PUNCHBOX_DIR environment variable')
            exit(1)
        template = punchbox_dir + '/vagrant/Vagrantfile.j2'
        logging.info('using default vagrant template '+template)

    template_jinja = load_template(template)
    config_dict = yaml.load(topology.read(), Loader=yaml.SafeLoader)
    rendered_template = template_jinja.render(**config_dict)
    if output is not None:
        output.write(rendered_template)
    else:
        print(rendered_template)

if __name__ == '__main__':
    cli()
