import shutil
import subprocess
from pathlib import Path
from typing import Dict, List
import click
import logging
from copy import deepcopy
import jinja2
import json
import yaml
import sys
import os
import re
import socket

COMPONENTS = [
    "punch", "minio", "zookeeper", "spark",
    "elastic", "opendistro_security", "operator",
    "binaries", "analytics-deployment", "analytics-client",
    "shiva", "gateway", "storm", "kafka", "logstash",
    "metricbeat", "filebeat", "packetbeat", "auditbeat"]

SERVICES = ["zookeeper", "kafka", "shiva_leader", "shiva_worker", "metricbeat"]


# This main module is used to render a jinja2 template
# the rendering environement is loaded with provided customisation data that
# must be provided as a json dictionnary string

class AnsibleJSONEncoder(json.JSONEncoder):
    """
    Simple encoder class to deal with JSON encoding of internal
    types like HostVars
    """

    def default(self, o):
        if isinstance(o):
            return dict(o)
        else:
            return super(AnsibleJSONEncoder, self).default(o)


def print_usage():
    sys.stderr.write('Usage: ' + sys.argv[0] + ' <templateFileName.j2> {jsonCustomisationDictionary}\n')
    sys.stderr.write('            or \n')
    sys.stderr.write('       ' + sys.argv[0] + ' <templateFileName.j2> -f <json property file>\n')


def regex_subst(st, pat, repl):
    if isinstance(st, list):
        return [regex_subst(a_string, pat, repl) for a_string in st]
    return re.sub(pat, repl, st)


def url_to_port(st, default_port=None):
    port_string = re.sub(".*:([0-9]+).*", "\\1", st)
    if port_string == st:
        port_string = default_port
    return port_string


def url_to_path(st):
    path_string = re.sub("[^/]*/(.*)", "/\\1", st)
    if path_string == st:
        path_string = "/"
    return path_string


def url_to_host(st):
    if isinstance(st, list):
        return [url_to_host(a_string) for a_string in st]
    return re.sub(":.*", "", st)


@jinja2.contextfunction
def get_context(c):
    return c


def resolve_hostname_to_ip(st):
    ip = socket.gethostbyname(st)
    if ip == "":
        raise Exception("Could not resolve provided hostname '" + st + "'.")
    return ip


def remove_duplicates(mylist):
    return list(set[mylist])


def is_dict_empty(my_dict):
    return bool(my_dict)


def env_override(value, key):
    return os.getenv(key, value)


def to_json(a, *args, **kw):
    """Convert the value to JSON"""

    return json.dumps(a, cls=AnsibleJSONEncoder, *args, **kw)


def to_yaml(a, *args, **kw):
    return a


def to_basename(path):
    return os.path.basename(path)


def to_nice_yaml(a, indentation=4, line_breaker="\n", optional_indent=0, *args, **kw):
    '''Make verbose, human readable yaml'''
    try:
        import simplejson
    except ImportError:
        pass
    transformed = yaml.safe_dump(a, indent=indentation, default_flow_style=False, line_break=line_breaker)
    shift = ""
    for i in range(optional_indent):
        shift = " " + shift
    transformed2 = ""
    for line in transformed.split("\n"):
        transformed2 += shift + line + "\n"
    return transformed2


def to_nice_json(a, indent=4, *args, **kw):
    """Make verbose, human readable JSON"""
    # python-2.6's json encoder is buggy (can't encode hostvars)
    if sys.version_info < (2, 7):
        try:
            import simplejson
        except ImportError:
            pass
        else:
            try:
                major = int(simplejson.__version__.split('.')[0])
            except:
                pass
            else:
                if major >= 2:
                    return simplejson.dumps(a, indent=indent, sort_keys=True, *args, **kw)

    try:
        return json.dumps(a, indent=indent, sort_keys=True, cls=AnsibleJSONEncoder, *args, **kw)
    except:
        # Fallback to the to_json filter
        return to_json(a, *args, **kw)

def load_template(template_filename):
    template_dir = os.path.dirname(template_filename)
    env = jinja2.Environment(loader=jinja2.FileSystemLoader(template_dir),
                             undefined=jinja2.StrictUndefined,
                             extensions=['jinja2.ext.do'],
                             trim_blocks=True, lstrip_blocks=True)
    template_name = os.path.basename(template_filename)
    env.filters['jsonify'] = json.dumps
    env.filters['regex_subst'] = regex_subst
    env.filters['url_to_host'] = url_to_host
    env.filters['url_to_port'] = url_to_port
    env.filters['url_to_path'] = url_to_path
    env.filters['resolve_hostname_to_ip'] = resolve_hostname_to_ip
    env.filters['remove_duplicates'] = remove_duplicates
    env.filters['env_override'] = env_override
    env.filters['to_nice_json'] = to_nice_json
    env.filters['to_nice_yaml'] = to_nice_yaml
    env.filters['to_json'] = to_nice_json
    env.filters['to_yaml'] = to_yaml
    env.filters['to_basename'] = to_basename
    env.filters['is_dict_empty'] = is_dict_empty
    template = env.get_template(template_name)
    template.globals['context'] = get_context
    template.globals['callable'] = callable
    return template


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

def lload_template(template):
    """
    Load Jinja template from file path
    :param template: Template file path
    :return: Jinja2 Template
    """
    template_path = Path(template)
    template_dir = template_path.parent
    loader = jinja2.FileSystemLoader(template_dir)
    env = jinja2.Environment(loader=loader,
                             trim_blocks=True, lstrip_blocks=True)
    return env.get_template(template_path.name)


def dict_to_string(dictionary: dict, file_format: str) -> str:
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
    Welcome to punchbox. This punch tool is your easy way to deploy, test or develop on
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
def deploy():
    """
    Commands required to deploy your punch.
    """
    pass


@deploy.command(name="audit")
@click.option("--workspace",
              required=False,
              default=str(Path.home()) + '/punchbox-workspace',
              type=click.Path(),
              help="the punchbox workspace")
@click.option('--verbose', '-v', is_flag=True, default=False, help="verbose mode")
@click.pass_context
def deploy_audit(ctx, workspace, verbose):
    """
    Audit your configuration before going any further.
    """
    with open(workspace + "/ws-conf/punchbox.yml") as infile:
        conf = yaml.load(infile.read(), Loader=yaml.SafeLoader)
    audit_cmd = conf['env']['deployer'] + '/bin/configuration_audit/audit3.py'
    audit_yml = conf['env']['deployer'] + '/bin/configuration_audit/punchplatform_dependencies.yml'
    conf_file = conf['punch']['deployment_settings']
    if verbose:
        print('audit command:')
        print(' ' + audit_cmd + ' ' + audit_yml + ' ' + conf_file)
    if 0 == os.system(audit_cmd + ' ' + audit_yml + ' ' + conf_file):
        print("INFO: your generated settings " + conf_file + " are correct")
        return 0
    print("ERROR: your generated settings " + conf_file + " are incorrect")
    return 1


@cli.group()
def workspace():
    """
    Setup your workspace.

    This method will create a so-called workspace folder. The workspace
    is a separate folder that will contain all your configuration files,
    and from where you will be able to start your VMs, deploy your punch,
    define your punch tenants and channels.

    The workspace is kept separated from your punchbox and punch deployer
    folders for both simplicity and maintainability.

    The default workspace is ~/punchbox-workspace.

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
              default=str(Path.home()) + '/punchbox-workspace',
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

    This method will create the punchbox workspace folder. That
    folder will contain all your configuration files.
    From there you will be able to start your VMs, deploy your punch,
    define your punch tenants and channels etc..

    The workspace is kept separated from your punchbox and punch deployer
    folders because it is both simpler and easier for you to maintain
    your configurations safe.

    Should your work with a long-lived workspace we strongly suggest you use git to keep
    track of the changes.
    """

    punch_box_dir = os.environ.get('PUNCHBOX_DIR')
    if topology is None:
        topology = punch_box_dir + "/samples/user_topology.yml"
    workspace_conf_dir = workspace + "/ws-conf"
    workspace_generated_conf_dir = workspace_conf_dir + "/generated"
    workspace_pp_conf_dir = workspace + "/pp-conf"
    workspace_vagrant_dir = workspace + "/vagrant"
    workspace_template_dir = workspace_conf_dir + '/templates'
    workspace_punchbox_file = workspace_conf_dir + "/punchbox.yml"
    workspace_topology_file = workspace_generated_conf_dir + '/topology.yml'
    workspace_deployment_settings_file = workspace_pp_conf_dir + '/deployment-settings.yml'
    workspace_punchplatform_deployment_settings_file = workspace_pp_conf_dir + '/punchplatform-deployment.settings'
    workspace_deployment_settings_j2_file = workspace_template_dir + '/deployment.settings.j2'
    workspace_vagrant_j2_file = workspace_vagrant_dir + '/Vagrantfile.j2'
    workspace_vagrant_file = workspace_vagrant_dir + '/Vagrantfile'
    workspace_user_resolver_file = workspace_conf_dir + '/user_resolver.yml'
    workspace_user_settings_file = workspace_conf_dir + '/user_settings.yml'
    workspace_user_topology_file = workspace_conf_dir + '/user_topology.yml'
    workspace_platform_blueprint_file = workspace_generated_conf_dir + '/blueprint.yml'
    dictionary = {
        'env': {
            "punchbox_dir": os.environ.get('PUNCHBOX_DIR'),
            "workspace": os.path.abspath(workspace),
            "deployer": os.path.abspath(deployer)
        },
        'vagrant': {
            "template": os.path.abspath(workspace_vagrant_j2_file),
            "vagrantfile": os.path.abspath(workspace_vagrant_file)
        },
        'punch': {
            "blueprint": os.path.abspath(workspace_platform_blueprint_file),
            "user_topology": os.path.abspath(workspace_user_topology_file),
            "user_settings": os.path.abspath(workspace_user_settings_file),
            "user_resolver": os.path.abspath(workspace_user_resolver_file),
            "deployment_settings_template": os.path.abspath(workspace_deployment_settings_j2_file),
            "topology": os.path.abspath(workspace_topology_file),
            "deployment_settings": os.path.abspath(workspace_deployment_settings_file),
            "punchplatform_deployment_settings": os.path.abspath(workspace_punchplatform_deployment_settings_file),
            "resolv_conf": os.path.abspath(workspace_pp_conf_dir + '/resolv.hjson'),
            "resolv_conf_template": os.path.abspath(workspace_template_dir + '/resolv.hjson.j2')
        }
    }

    # Create the required target directories
    if not os.path.exists(workspace_template_dir):
        os.makedirs(workspace_template_dir)
    if not os.path.exists(workspace_conf_dir):
        os.makedirs(workspace_conf_dir)
    if not os.path.exists(workspace_pp_conf_dir):
        os.makedirs(workspace_pp_conf_dir)
    if not os.path.exists(workspace_vagrant_dir):
        os.makedirs(workspace_vagrant_dir)
    if not os.path.exists(workspace_generated_conf_dir):
        os.makedirs(workspace_generated_conf_dir)

    if not os.path.exists(workspace_punchbox_file) or click.confirm('Overwrite your configurations ?'):
        # for the sake of clarity, we remove all the files that are generated.
        # It makes it clearer to the user what must be generated next.
        if os.path.exists(os.path.abspath(workspace_punchbox_file)):
            print("cleaning " + workspace_punchbox_file)
            os.remove(os.path.abspath(workspace_punchbox_file))

        if os.path.exists(os.path.abspath(workspace_vagrant_file)):
            print("cleaning " + workspace_vagrant_file)
            os.remove(os.path.abspath(workspace_vagrant_file))

        if os.path.exists(os.path.abspath(workspace_platform_blueprint_file)):
            print("cleaning " + workspace_platform_blueprint_file)
            os.remove(os.path.abspath(workspace_platform_blueprint_file))

        if os.path.exists(os.path.abspath(workspace_topology_file)):
            print("cleaning " + workspace_topology_file)
            os.remove(os.path.abspath(workspace_topology_file))

        if os.path.exists(workspace_deployment_settings_file):
            print("cleaning " + workspace_deployment_settings_file)
            os.remove(workspace_deployment_settings_file)

        workspace_activate_file = os.path.abspath(workspace + '/activate.sh')
        if os.path.exists(workspace_activate_file):
            print("cleaning " + workspace_activate_file)
            os.remove(workspace_activate_file)

        # populate the user workspace with the required starting configuration files.
        shutil.copy(os.path.abspath(topology),
                    os.path.abspath(workspace_user_topology_file))
        shutil.copy(os.path.abspath(punch_box_dir + '/samples/user_settings.yml'),
                    os.path.abspath(workspace_user_settings_file))
        shutil.copy(os.path.abspath(punch_box_dir + '/samples/user_resolver.yml'),
                    os.path.abspath(workspace_user_resolver_file))
        shutil.copy(os.path.abspath(punch_box_dir + '/vagrant/Vagrantfile.j2'),
                    os.path.abspath(workspace_vagrant_j2_file))

        # copy all templates
        template_dir = os.path.abspath(punch_box_dir + '/templates/')
        src_files = os.listdir(template_dir)
        for file_name in src_files:
            full_file_name = os.path.join(template_dir, file_name)
            if os.path.isfile(full_file_name):
                shutil.copy(full_file_name, os.path.abspath(workspace_template_dir))

        # and finally create the activate.sh file
        with open(workspace_activate_file, "w+") as activateFile:
            activateFile.write("export PATH=" + os.path.abspath(deployer) + "/bin:$PATH\n")
            activateFile.write("export PUNCHPLATFORM_CONF_DIR=" + workspace_pp_conf_dir + "\n")

        # All done, generate the main punchbox yaml file. That file will be used
        # for all the subsequent build phases.
        with open(workspace_punchbox_file, 'w+') as outfile:
            yaml.dump(dictionary, outfile)
        print("workspace created")


@workspace.command(name="build")
@click.option("--workspace",
              required=False,
              default=str(Path.home()) + '/punchbox-workspace',
              type=click.Path(),
              help="the punchbox workspace")
@click.option('--yes', '-y', is_flag=True, default=True, help="confirmed mode")
@click.pass_context
def build_workspace(ctx, workspace, yes):
    """
    Build you workspace.

    Once created, a few configuration files must be generated from
    various templates. This command make your workspace ready to move
    on to deploying a punch.

    By default this command is interactive and prompt before generating a file.
    If you want it to be silent use the confirmed mode.
    """
    with open(workspace + "/ws-conf/punchbox.yml") as infile:
        conf = yaml.load(infile.read(), Loader=yaml.SafeLoader)

    if not yes or click.confirm('generate vagrantfile ' + conf['vagrant']['vagrantfile'] + ' ?'):
        if not os.path.exists(conf['env']['workspace'] + '/vagrant'):
            os.makedirs(conf['env']['workspace'] + '/vagrant')
        with open(conf['punch']['user_topology']) as topology, \
                open(conf['vagrant']['vagrantfile'], 'w+') as vagrantfile:
            print("  punchbox generate vagrantfile \\\n" +
                  "    --topology " + conf['punch']['user_topology'] + "  \\\n" +
                  "    --template " + conf['vagrant']['template'] + "  \\\n" +
                  "    --output " + conf['vagrant']['vagrantfile'] + "\n"
                  )
            ctx.invoke(generate_vagrantfile, topology=topology,
                       template=conf['vagrant']['template'], output=vagrantfile)

    if not yes or click.confirm('generate platform topology ' + conf['punch']['topology'] + ' ?'):
        with open(conf['punch']['user_topology']) as topology, \
                open(conf['punch']['topology'], "w+") as output:
            print("  punchbox generate topology \\\n" +
                  "    --topology " + conf['punch']['user_topology'] + "  \\\n" +
                  "    --output " + conf['punch']['topology'] + "\n")
            ctx.invoke(generate_topology, deployer=conf['env']['deployer'],
                       topology=topology, output=output)

    if not yes or click.confirm('generate platform blueprint ' + conf['punch']['blueprint'] + ' ?'):
        with open(conf['punch']['topology'], "r") as topology, \
                open(conf['punch']['blueprint'], "w+") as output, \
                open(conf['punch']['user_settings'], "r") as settings:
            print("  punchbox generate blueprint \\\n" +
                  "    --topology " + conf['punch']['user_topology'] + "  \\\n" +
                  "    --settings " + conf['punch']['user_settings'] + "  \\\n" +
                  "    --output " + conf['punch']['blueprint'] + "\n")
            ctx.invoke(generate_blueprint,
                       topology=topology,
                       settings=settings,
                       output=output)

    if not yes or click.confirm('generate deployment settings ' + conf['punch']['deployment_settings'] + ' ?'):
        with open(conf['punch']['blueprint'], "r") as blueprint, \
                open(conf['punch']['deployment_settings'], "w+") as output:
            print("  punchbox generate deployment-settings \\\n" +
                  "    --blueprint " + conf['punch']['blueprint'] + "  \\\n" +
                  "    --template " + conf['punch']['deployment_settings_template'] + "  \\\n" +
                  '    --output ' + conf['punch']['deployment_settings'] + "\n")
            ctx.invoke(generate_deployment, blueprint=blueprint, template=conf['punch']['deployment_settings_template'],
                       output=output)

        with open(conf['punch']['deployment_settings'], 'r') as yaml_in, \
                open(conf['punch']['punchplatform_deployment_settings'], "w+") as json_out:
            print("  backward compatibility generation : convert\n" +
                  "    " + conf['punch']['deployment_settings'] + " into \n" +
                  "            into \n" +
                  "    " + conf['punch']['punchplatform_deployment_settings'] + "\n")
            yaml_object = yaml.load(yaml_in, Loader=yaml.SafeLoader)
            # yaml_object = yaml.safe_load(yaml_in)
            json.dump(yaml_object, json_out)

    #if not yes or click.confirm('generate resolv.conf ' + conf['punch']['resolv_conf'] + ' ?'):
    #    with open(conf['punch']['blueprint'], "r") as blueprint, \
    #            open(conf['punch']['resolv_conf'], "w+") as output:
    #        ctx.invoke(generate_resolver,
    #                   blueprint=blueprint,
    #                   template=conf['punch']['resolv_conf_template'],
    #                   output=output)


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


@generate.command(name="topology")
@click.option("--deployer",
              required=True,
              type=click.Path(exists=True),
              help="path to the punch deployer folder")
@click.option("--topology", required=True, type=click.File("rb"),
              help="a punch topology description file")
@click.option("--output", default=None, type=click.File("w"),
              help="the generated platform inventory topology. "
                   "If not provided the file is written to stdout")
def generate_topology(deployer, topology, output):
    """
    Generate the bootstrap topology file.

    This command generates a platform topology file required by the punch deployer.
    That file is built from a so called platform topology file that describes your target
    platform in a simple and human readable format.

    It generates a files that contains useful information such as version numbers for each
    punch components (including the third-party cots). This file is handy
    for you to avoid filling manually that information in your inventories.
    """
    topology_dict = yaml.load(topology.read(), Loader=yaml.SafeLoader)
    servers = topology_dict["servers"]
    services_dict = {}
    users_dict = {}

    for host, item in servers.items():
        if 'users' in item:
            for s in item["users"]:
                params = {}
                user = None
                for key, value in s.items():
                    if key == "user":
                        user = s[key]
                    elif key == "params":
                        params = s[key]
                    else:
                        raise Exception("only 'user' and 'params' keys are allowed for a host 'users'")
                if user not in users_dict:
                    users_dict[user] = {}
                users_dict[user][host] = params
        if 'services' in item:
            for s in item["services"]:
                params = {}
                service = None
                cluster = None
                for key, value in s.items():
                    if key == "service":
                        service = s[key]
                    elif key == "cluster":
                        cluster = s[key]
                    elif key == "params":
                        params = s[key]
                    else:
                        raise Exception("only 'service' , 'cluster' and 'params' keys are allowed for 'services'")
                if cluster is None:
                    cluster = "common"
                if service is None:
                    raise Exception("a service key is mandatory for declaring services")
                if service not in services_dict:
                    services_dict[service] = {}
                if cluster not in services_dict[service]:
                    services_dict[service][cluster] = {}
                services_dict[service][cluster][host] = params

    topology_dict['network'] = deepcopy(topology_dict['network'])
    topology_dict['services'] = deepcopy(services_dict)
    topology_dict['users'] = deepcopy(users_dict)
    topology_dict['versions'] = deepcopy(get_components_version(deployer))
    formatted_model = yaml.dump(topology_dict)
    if output is None:
        print(formatted_model)
    else:
        output.write(formatted_model)


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


@generate.command(name="blueprint")
@click.option("--topology", required=True, type=click.File("rb"),
              help="the platform topology file generated using the 'generate topology' command")
@click.option("--settings", required=True, type=click.File("rb"),
              help="the punch settings file. It provides all the required settings "
                   "for each component you selected. If you are in doubt use the punchbox "
                   "samples/complete_vagrant_settings.yml file.")
@click.option("--output", type=click.File("w"), help="Output file")
def generate_blueprint(topology, settings, output):
    """
        Generate the punch blueprint configuration file. That file is the one used
        to in turn generate deployment and resolver files using templates.

        It fully summarizes the information you provided through the topology
        and the settings files.

        You should not need to understand it, and certainly not to edit it as it is generated.
        It can be useful to debug a deployment issue.
    """
    blueprint_dict = {}
    topology_dict = yaml.load(topology.read(), Loader=yaml.SafeLoader)
    settings_dict = yaml.load(settings.read(), Loader=yaml.SafeLoader)
    shiva_servers = {}

    # this pass is a typical inventory generation improvement. We transform
    # shiva_leader and shiva_worker in finer grain shiva dictionary.
    #for name, value in topology_dict["services"].items():
    #    if name == "shiva":
    #        settings_dict["shiva"]["servers"] = topology_dict["services"][name]
    #    elif name == "zookeeper":
    #        settings_dict["zookeeper"]["servers"] = topology_dict["services"][name]
    #    #elif name == "kafka":
    #    #    settings_dict["kafka"]["brokers"] = [{"id": i, "broker": broker} for i, broker in enumerate(value)]
    #    elif name == "metricbeat":
    #        settings_dict["metricbeat"]["servers"] = generate_metricbeat_servers(value)
    #    elif name == "storm_leader":
    #        settings_dict["storm"]["masters"] = topology_dict["services"][name]
    #    elif name == "storm_worker":
    #        settings_dict["storm"]["slaves"] = topology_dict["services"][name]
    #    elif name == "storm_ui":
    #        settings_dict["storm"]["ui_servers"] = topology_dict["services"][name]
    #    elif name == "spark_master":
    #        settings_dict["spark"]["masters"] = topology_dict["services"][name]
    #    elif name == "spark_worker":
    #        settings_dict["spark"]["slaves"] = generate_spark_workers(value, settings_dict["spark"],
    #                                                                  topology_dict["interface"])
    #    else:
    #    raise NotImplementedError(f"{name} is not a known configuration item")

    #if "shiva" in settings_dict:
    #    settings_dict["shiva"]["servers"] = shiva_servers

    blueprint_dict['settings'] = deepcopy(settings_dict)
    blueprint_dict['topology'] = deepcopy(topology_dict)
    if output is not None:
        yaml.dump(blueprint_dict, output)
    else:
        print(yaml.dump(blueprint_dict, None))


@generate.command(name="deployment-settings")
@click.option("--blueprint", required=True, type=click.File("rb"),
              help="the platform blueprint file generated using the 'generate blueprint' command")
@click.option("--template", required=False, type=click.Path(exists=True),
              help="the deployment template. The default is  "
                   "templates/punchplatform_deployment_settings.j2 in your punchbox. It provides all the required "
                   "settings ")
@click.option("--output", type=click.File("w"), help="Output file")
def generate_deployment(blueprint, template, output):
    """
        Generate the punch deployment settings file. That file is your input to use the punch
        deployer. It contains the complete and precise settings of all your components.

        That file is, of course, a rich file. Each section of it is fully described in the punch
        online documentation. It is generated from a ready to use template file and the topology
        file generated using the 'generate topology' command.

        Once you have that file you are good to go to deploy your punch.
    """
    blueprint_dict = yaml.load(blueprint.read(), Loader=yaml.SafeLoader)
    deployment_template = load_template(template)
    try:
        output_yml = deployment_template.render(**blueprint_dict)
        if output is not None:
            output.write(output_yml)
        else:
            print(output_yml)
    except TypeError:
        logging.exception("your punchplatform-deployment-settings.j2.yaml template must be wrong")
        exit(1)


@generate.command(name="resolver")
@click.option("--blueprint", required=True, type=click.File("rb"),
              help="the platform blueprint file generated using the 'generate blueprint' command")
@click.option("--template", required=True, type=click.Path(exists=True),
              help="the resolver template. In doubt use the  "
                   "templates/resolv.hjson.j2 in your punchbox.")
@click.option("--output", type=click.File("w"), help="Output file")
def generate_resolver(blueprint, template, output):
    """
        Generate the punch deployment resolver file. That file is required to
        deploy the punch but can be empty.
    """
    blueprint_dict = yaml.load(blueprint.read(), Loader=yaml.SafeLoader)
    deployment_template = load_template(template)
    try:
        output_yml = deployment_template.render(**blueprint_dict)
        if output is not None:
            output.write(output_yml)
        else:
            print(output_yml)
    except TypeError:
        logging.exception("your resolv_hjson.j2.yaml template must be wrong")
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
            logging.fatal(
                'if you do not provide a vagrant template file you must set the PUNCHBOX_DIR environment variable')
            exit(1)
        template = punchbox_dir + '/vagrant/Vagrantfile.j2'
        logging.info('using default vagrant template ' + template)

    template_jinja = load_template(template)
    config_dict = yaml.load(topology.read(), Loader=yaml.SafeLoader)
    rendered_template = template_jinja.render(**config_dict)
    if output is not None:
        output.write(rendered_template)
    else:
        print(rendered_template)


if __name__ == '__main__':
    cli()
