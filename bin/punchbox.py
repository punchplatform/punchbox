import json
import os
import shutil
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
    env = jinja2.Environment(loader=loader, trim_blocks=True, lstrip_blocks=True)
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
    Welcome to punchbox. This punch tool is your easy way todeploy, test or develop on
    top of the punch.

    Two set of commands are available. The one under 'workspace' are the ones you are most likely
    to use. They let you build a workspace folder to configure what you need and deploy your punch.

    The ones under 'generate' are finer grain commands to selectively generate some of
    the configuration files.

    A good starting point is to type 'punchbox workspace create'
    \f
    """
    pass

@cli.group()
def workspace():
    """
    Setup your workspace.

    This method will create a so-called worskpace folder. The workspace
    is a separate folder that will contain all your configuration files,
    and from where you will be able to start your VMs, deploy your punch,
    define your punch tenants and channels.

    The workspace is kept separated from your punchbox and punch deployer
    folders for both simplicity and maintainability.

    The default worskpace is ~/punchbox-workspace.

    \f
    """
    pass

@workspace.command(name="create")
@click.option("--deployer",
              required=True,
              type=click.Path(exists=True),
              help="path to the punch deployer folder")
@click.option("--workspace",
              required=False,
              default=str(Path.home())+'/punchbox-workspace',
              type=click.Path(),
              help="the punchbox workspace")
@click.option("--topology",
              required=False,
              default=None,
              type=click.Path(),
              help="the target platform topology. A sample one will be picked for you if you do not provide one.")
def create_workspace(deployer, workspace, topology):
    """
    Create a punchbox working space.

    This method will create the punchbox worskpace folder. That
    folder will contain all your configuration files.
    From there you will be able to start your VMs, deploy your punch,
    define your punch tenants and channels etc..

    The workspace is kept separated from your punchbox and punch deployer
    folders because it is both simpler and easier for you to maintain
    your configurations safe.

    Should your work with a long-lived workspace we strongly suggest you use git to keep
    track of the changes.
    """
    punchBoxDir = os.environ.get('PUNCHBOX_DIR')
    workspaceConfDir = workspace+"/ws-conf"
    workspacePpConfDir = workspace+"/pp-conf"
    workspaceVagrantDir = workspace+"/vagrant"
    workspaceTemplateDir = workspaceConfDir + '/templates'
    workspacePunchboxFile = workspaceConfDir + "/punchbox.yml"
    workspaceBlueprint = workspaceConfDir + "/blueprint.yml"
    if topology is None:
        topology = punchBoxDir+'/samples/sample_punch_topology.yml'

    dictionary = {
        'env' : {
            "punchbox_dir": os.environ.get('PUNCHBOX_DIR'),
            "workspace" : os.path.abspath(workspace),
            "deployer" : os.path.abspath(deployer)
        },
        'vagrant' : {
            "template" : os.path.abspath(workspaceVagrantDir + '/Vagrantfile.j2'),
            "vagrantfile" : os.path.abspath(workspaceVagrantDir + '/Vagrantfile')
        },
        'punch' : {
            "platform_blueprint" : os.path.abspath(workspaceConfDir + '/platform_blueprint.yml'),
            "platform_topology" : os.path.abspath(workspaceConfDir + '/platform_topology.yml'),
            "platform_settings" : os.path.abspath(workspaceConfDir + '/platform_settings.yml'),
            "deployment_settings_template" : os.path.abspath(workspaceTemplateDir + '/punchplatform-deployment.settings.j2'),
            "platform_descriptor" : os.path.abspath(workspaceConfDir + '/platform_descriptor.yml'),
            "deployment_settings" : os.path.abspath(workspacePpConfDir + '/punchplatform-deployment-settings.yml')
        }
    }
    if not os.path.exists(workspaceTemplateDir):
        os.makedirs(workspaceTemplateDir)
    if not os.path.exists(workspaceConfDir):
        os.makedirs(workspaceConfDir)
    if not os.path.exists(workspacePpConfDir):
        os.makedirs(workspacePpConfDir)
    if not os.path.exists(workspaceVagrantDir):
         os.makedirs(workspaceVagrantDir)
    workspaceVagrantJ2File = os.path.abspath(workspaceVagrantDir + '/Vagrantfile.j2')
    workspaceVagrantFile = os.path.abspath(workspaceVagrantDir + '/Vagrantfile')
    workspaceBlueprintFile = os.path.abspath(workspaceConfDir + '/blueprint.yml')
    workspaceDescriptorFile = os.path.abspath(workspaceConfDir + '/platform_descriptor.yml')
    workspacePlatformSettingsFile = os.path.abspath(workspaceConfDir + '/platform_settings.yml')
    workspaceDeploymentSettingsFile = os.path.abspath(workspaceConfDir + '/deployment-settings.json')
    workspaceActivateFile = os.path.abspath(workspace + '/activate.sh')
    workspaceTopologyFile = os.path.abspath(workspaceConfDir+ '/platform_topology.yml')
    workspaceDeploymenSettingsJ2File = os.path.abspath(workspaceTemplateDir + '/punchplatform-deployment.settings.j2')
    if  not os.path.exists(workspacePunchboxFile) or click.confirm('Overwrite your configurations ?'):
        # for the sake of clarity, we remove all the files that are generated.
        # It makes it clearer to the user what must be generated next.
        if os.path.exists(workspaceVagrantFile):
            os.remove(workspaceVagrantFile)
        if os.path.exists(workspaceBlueprintFile):
            os.remove(workspaceBlueprintFile)
        if os.path.exists(workspaceDescriptorFile):
            os.remove(workspaceDescriptorFile)
        if os.path.exists(workspaceDeploymentSettingsFile):
            os.remove(workspaceDeploymentSettingsFile)
        if os.path.exists(workspaceActivateFile):
            os.remove(workspaceActivateFile)

        # populate the user workspace with the required starting configuration files.
        shutil.copy(os.path.abspath(topology), workspaceTopologyFile)
        shutil.copy(os.path.abspath(punchBoxDir + '/samples/complete_vagrant_settings.yml'),
                    workspacePlatformSettingsFile)
        shutil.copy(os.path.abspath(punchBoxDir + '/vagrant/Vagrantfile.j2'), workspaceVagrantJ2File)
        shutil.copy(os.path.abspath(punchBoxDir + '/templates/punchplatform-deployment.settings.j2'),
                    workspaceDeploymenSettingsJ2File)
        with open(workspaceActivateFile, "w+") as activateFile:
            activateFile.write("export PATH=$PATH:"+os.path.abspath(deployer)+"/bin\n")
            activateFile.write("export PUNCHPLATFORM_CONF_DIR="+workspacePpConfDir+"\n")
        # generate the main descriptor file
        with open(workspacePunchboxFile, 'w+') as outfile:
            yaml.dump(dictionary, outfile)


@workspace.command(name="build")
@click.option("--workspace",
              required=False,
              default=str(Path.home())+'/punchbox-workspace',
              type=click.Path(),
              help="the punchbox workspace")
@click.option('--yes', '-y', is_flag=True, default=True, help="confirmed mode")
@click.pass_context
def build_workspace(ctx, workspace, yes):
    """
    Build you workspace.

    Once created, a few configuration files must be generated from
    various temlplates. This command make your workspace ready to move
    on to deploying a punch.

    By default this command is interactive and prompt before generating a file.
    If you want it to be silent use the confirmed mode.
    """
    conf = {}
    with open(workspace+"/ws-conf/punchbox.yml") as infile:
        conf = yaml.load(infile.read(), Loader=yaml.SafeLoader)

    punchBoxDir = conf['env']['punchbox_dir']
    if not yes or click.confirm('generate vagrantfile '+conf['vagrant']['vagrantfile'] + ' ?'):
        if not os.path.exists(conf['env']['workspace']+'/vagrant'):
            os.makedirs(conf['env']['workspace']+'/vagrant')
        with open(conf['punch']['platform_topology']) as topology, \
                open(conf['vagrant']['vagrantfile'], 'w+') as vagrantfile:
            ctx.invoke(generate_vagrantfile, topology=topology, template=conf['vagrant']['template'], output=vagrantfile)

    if not yes or click.confirm('generate platform descriptor '+conf['punch']['platform_descriptor'] + ' ?'):
        if not os.path.exists(conf['env']['workspace']+'/vagrant'):
            os.makedirs(conf['env']['workspace']+'/vagrant')
        with open(conf['punch']['platform_topology']) as topology, \
                open(conf['punch']['platform_descriptor'],"w+") as descriptor :
            ctx.invoke(generate_descriptor,  deployer=conf['env']['deployer'], topology=topology, output=descriptor)

    if not yes or click.confirm('generate deployment settings '+conf['punch']['deployment_settings'] + ' ?'):
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

    The generate commands lets you generate some of the configuration files you
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
@click.option("--topology", required=True, type=click.File("rb"),
              help="a punch topology description file")
@click.option("--output", default=None, type=click.File("w"),
              help="the generated platform inventory descriptor. "
                "If not provided the file is written to stdout")
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
    blueprintDict = {}
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
        template = punchbox_dir + '/templates/punchplatform-deployment-settings.j2'
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
        blueprintDict['settings'] = settings_dict
        blueprintDict['descriptor'] = descriptor_dict
        outputYml = deployment_template.render(**blueprintDict)
        if output is not None:
            output.write(outputYml)
        else:
            print(outputYml)
    except TypeError:
        logging.exception("your deployment-settings.j2 must be wrong")
        print('Your descriptor:')
        print(descriptor_dict)
        print('Your settings:')
        print(settings_dict)
        exit(1)

@generate.command(name="vagrantfile")
@click.option("--topology", required=True, type=click.File("rb"),
              help="a punch topology description file")
@click.option("--template", required=False, type=click.Path(exists=True),
              help="a vagrant template vile")
@click.option("--output", type=click.File("w"),
              help="the output file where to write the Vagrant file. If not provided the generated file"
                   " is written to stdout")
def generate_vagrantfile(topology, template: str, output):
    """
    Generate Vagrantfile.

    This command lets you easily generate a Vagrantfile from the punchbox provided
    template. You can use you own template in case you have one.

    The default template is located in the punchbox vagrant/Vagrantfile.j2 file.
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
