import argparse
import json
import logging
import os
import subprocess
from datetime import datetime
from shutil import copy2, copytree, ignore_patterns
from sys import exit
from typing import List, Dict
from shutil import copyfile

import jinja2
from jinja2.exceptions import UndefinedError

import vagrant

ROOT_DIR = os.path.dirname(os.path.abspath(__file__))  # This is your Project Root

# Repository layout
punchbox_dir = os.environ.get('PUNCHBOX_DIR')
vagrant_dir = punchbox_dir + '/vagrant'

# Templates path
vagrant_template_file = 'Vagrantfile.j2'
resolv_template_file = 'resolv.hjson.j2'
secrets_template_file = 'deployment_secrets.json.j2'
platform_templates = punchbox_dir + '/punch/platform_template'
check_platform_template = 'check_platform.sh.j2'

# Targets path
build_dir = punchbox_dir + '/punch/build'
build_conf_dir = build_dir + '/pp-conf'
resolv_target = build_conf_dir + '/resolv.hjson'
secret_target = build_conf_dir + '/deployment_secrets.json'
platform_shell_target = build_conf_dir + "/check_platform.sh"
vagrantfile_target = vagrant_dir + '/Vagrantfile'
check_platform_target = build_conf_dir + "/check_platform.sh"
elastalert_tool_target = build_conf_dir + "/punchplatform-elastalert.sh"
generated_model = build_dir + '/model.json'


components = ["punch", "minio", "zookeeper", "spark", "elastic", "opendistro_security", "operator", "binaries",
              "analytics-deployment", "analytics-client", "shiva", "gateway", "storm", "kafka", "logstash",
              "metricbeat", "filebeat", "packetbeat", "auditbeat"]


def check_archive_existence(deployer_folder_name):
    deployers = [f.name for f in list(os.scandir(build_dir))
                 if (f.is_dir() and
                     (f.name.startswith('punch-deployer') or f.name.startswith('punchplatform-deployer')))
                 ]
    if len(deployers) == 1:
        deployer_folder_name = deployers[0]
    elif len(deployers) > 1:
        logging.error(
            'cannot guess deployer path from directories in \"{}\" because multiple possibilities exist :{}'.format(
                build_dir, deployers))
    return deployer_folder_name


def unzip_punch_archive(deployer):
    deployer_folder_name = check_archive_existence(os.path.splitext(os.path.basename(deployer))[0])
    if not os.path.exists(build_dir + "/" + deployer_folder_name + "/.unzipped"):
        cmd = 'unzip -o -d {1} {0}'.format(deployer, build_dir)
        rc = os.system(cmd)
        if rc == 0:
            deployer_folder_name = check_archive_existence(deployer_folder_name)
            with open(build_dir + "/" + deployer_folder_name + "/.unzipped", "w") as activate:
                activate.write(str(datetime.now()))
            logging.info(' punchplatform deployer archive successfully unzipped')
        else:
            logging.error("unable to unzip deployer in folder with command '%s'" % cmd)
            exit(42)


def copy_elastalert_tool(elastalert_tool):
    if not os.path.exists(elastalert_tool_target):
        copy2(elastalert_tool, elastalert_tool_target)


def load_platform_config(platform_config_file):
    with open(platform_config_file) as f:
        logging.info(' loading platform configuration from file %s', platform_config_file)
        return json.load(f)


def my_copy_tree(src, dst, ignore: List[str] = None):
    for item in os.listdir(src):
        if item not in ignore:
            s = os.path.join(src, item)
            d = os.path.join(dst, item)
            if os.path.isdir(s):
                try:
                    copytree(s, d, ignore=ignore_patterns(*ignore))
                except FileExistsError:
                    pass
            else:
                map(lambda x: copy2(s, d), filter(lambda y: y not in s, ignore))

def get_versions (deployer):
    data = {}
    deployer_folder_name = check_archive_existence(os.path.splitext(os.path.basename(deployer))[0])
    for component in cots:
        version_of = build_dir + "/" + deployer_folder_name + "/bin/punchplatform-versionof.sh"
        cmd = "{0} --legacy {1}".format(version_of, component)
        result = subprocess.check_output(cmd, shell=True)
        data[component] = result.decode("utf-8").rstrip()

    return data

## VAGRANT MANAGEMENT ##
def create_vagrantfile(platform_config, vagrant_os: str = None):
    if not vagrant_os:
        vagrant_os = platform_config["targets"]["meta"]["os"]
    render_and_write(vagrant_dir, vagrantfile_template, vagrantfile_target,
                     targets=platform_config["targets"], os=vagrant_os)
    logging.info(' Vagrantfile successfully generated in %s', vagrantfile_target)


def launch_vagrant_boxes():
    v = vagrant.Vagrant(vagrant_dir, quiet_stdout=False, quiet_stderr=False)
    v.up()
    logging.info(' vagrant boxes successfully started')


def destroy_vagrant_boxes():
    if os.path.exists(vagrantfile_target):
        v = vagrant.Vagrant(vagrant_dir, quiet_stdout=False, quiet_stderr=False)
        v.destroy()
        logging.info(' vagrant boxes successfully stopped')

def patch_security_model(model: Dict):
    security_dir="{}/../punch/resources/security".format(ROOT_DIR)
    model['security'] = {}
    model['security']['security_dir'] = security_dir

    return model


## GENERATE FILE MODEL ##
def generate_model(platform_config, deployer, vagrant_mode, vagrant_os: str = None, vagrant_interface: str = None,
                   security: bool = False):

    model = {}
    data = get_versions(deployer)

    # vagrant model
    model['version'] = data
    # os
    if vagrant_os is not None:
        model['os'] = vagrant_os
    # interface
    if vagrant_interface is not None:
        model['iface'] = vagrant_interface
    elif vagrant_mode is True:
        if 'centos' in platform_config['targets']['meta']['os']:
            model['iface'] = "eth1"
        else:
            model['iface'] = "enp0s8"
    else:
        model['iface'] = "ens4"
    # security model
    if security:
        model = patch_security_model(model)

    model = json.dumps({**model, **platform_config['punch']}, indent=4, sort_keys=True)
    model_file = open(generated_model, "w+")
    model_file.write(model)
    model_file.close()
    logging.info(' platform model file successfully generated in %s', generated_model)
    return model


# CREATE PP-CONF #
def create_ppconf():
    if not os.path.exists(build_conf_dir):
        logging.info(' creating build configuration directory %s', build_conf_dir)
        os.makedirs(build_conf_dir)


## CREATE RESOLV FILE ##
def create_resolver(platform_config, deployer, security=False):
    render_and_write(platform_templates, resolv_template, resolv_target,
                     punch=platform_config["punch"], security=security, versions=get_versions(deployer))
    logging.info(' platform resolv.hjson successfully generated in %s', resolv_target)


# IMPORT CHANNELS AND RESOURCES IN PP-CONF #
def import_user_resources(punch_user_config, platform_config_file, validation, target_os):
    if validation is False:
        # No need to import validation tenant
        ignore = ["*.properties", "resolv.*", "validation"]
        my_copy_tree(punch_user_config, build_conf_dir, ignore=ignore)
        logging.info(' punch user configuration successfully imported in %s', build_conf_dir)
    else:
        # Need to render and import validation tenant files
        ignore = ["*.properties", "resolv.*", "*.j2"]
        my_copy_tree(punch_user_config, build_conf_dir, ignore=ignore)

        # Get constants for template
        rules_dir = os.path.join(punch_user_config, 'tenants/validation/channels/elastalert_validation/rules')
        nb_to_validate = len([f for f in next(os.walk(rules_dir))[1]])

        # Time constants
        validation_now = datetime.now()
        validation_id = int(validation_now.timestamp())
        validation_time = validation_now.isoformat(timespec="seconds")

        # Config constants
        validation_tenant = '/tenants/validation'
        platform_config = load_platform_config(platform_config_file)
        target_os = target_os if target_os is not None else platform_config["targets"]["meta"]["os"]
        spark_master = platform_config["punch"]["spark"]["masters"][0] if "spark" in platform_config["punch"] else ""

        # Git constants
        pp_punch_dir = os.getenv('PUNCH_DIR', default=punchbox_dir)
        branch = subprocess.check_output(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=pp_punch_dir
        ).strip().decode()
        commit = subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"], cwd=pp_punch_dir
        ).strip().decode()
        commit_date = subprocess.check_output(
            ["git", "log", "-1", "--date=format:%Y-%m-%dT%H:%M", "--format=%ad"], cwd=pp_punch_dir
        ).strip().decode()

        loader = jinja2.FileSystemLoader(punch_user_config + validation_tenant)
        env = jinja2.Environment(loader=loader)
        templates = env.list_templates()
        for template in templates:
            try:
                if "check.sh" in template:
                    render_and_write(env, template, build_conf_dir + validation_tenant + '/' + template,
                                     punch=platform_config["punch"], os=platform_config['targets']['meta']['os'])
                else:
                    render_and_write(
                        env, template, build_conf_dir + validation_tenant + '/' + template,
                        spark_master=spark_master,
                        elasticsearch_host=platform_config["punch"]["elasticsearch"]["servers"][0],
                        shiva_host=platform_config["punch"]["shiva"]["servers"][0],
                        validation_id=validation_id,
                        validation_time=validation_time,
                        nb_to_validate=nb_to_validate,
                        livedemo_api_url=os.getenv('LIVEDEMO_API_URL', default="http://test"),
                        user=os.getenv('USER', default='anonymous'),
                        sysname=os.uname().sysname,
                        release=os.uname().release,
                        hostname=os.uname().nodename,
                        target_config=os.path.basename(platform_config_file),
                        target_os=target_os,
                        gateway_host=platform_config["punch"]["gateway"]["servers"][0],
                        branch=branch,
                        commit=commit,
                        commit_date=commit_date
                    )
            except Exception as e:
                logging.error('Failure while working on template "%s".', template)
                raise
        logging.info(' punch validation configuration successfully imported in %s', build_conf_dir)


## CREATE A VALIDATION SHELL ##
def create_check_platform(platform_config, punch_user_config, security=False):
    try:
        rules_dir = os.path.join(punch_user_config, 'tenants/validation/channels/elastalert_validation/rules')
        rules = [f for f in next(os.walk(rules_dir))[1]]
        render_and_write(platform_templates, check_platform_template, check_platform_target,
                         punch=platform_config['punch'], rules=rules, security=security)
        os.chmod(check_platform_target, 0o775)
        logging.info(' punchplatform validation shell successfully generated in %s', check_platform_target)
    except UndefinedError as err:
        logging.error('cannot create \"check_platform\" properly: {}'.format(err))


def render_and_write(template_dir, template_file, target_file, *args, **kwargs):
    env = jinja2.Environment(loader=jinja2.FileSystemLoader(template_dir)) \
        if isinstance(template_dir, str) else template_dir
    template = env.get_template(template_file)
    rendered_content = template.render(*args, **kwargs)
    target = open(target_file, "w+")
    target.write(rendered_content)
    target.close()


def main():
    logging.basicConfig(format='%(levelname)s:%(message)s', level=logging.DEBUG)

    if "PUNCHBOX_DIR" not in os.environ:
        logging.fatal(' PUNCHBOX_DIR environment variable is not set')
        exit(1)

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--deployer",
        help="Path to the punch deployer zip archive. Something like punchplatform-deployer-6.1.0.zip.")
    parser.add_argument(
        "--punch-user-config",
        help="Path to a punch configuration folder with your channels and resources."
             " If you have no idea, check and use the punchbox/punch/configurations/sample/conf folder.")
    parser.add_argument(
        "--validation",
        help="Activate punch validation. Default to false", action="store_true")
    parser.add_argument(
        "--elastalert-tool",
        help="Path to the punchplatform-elastalert.sh tool. Required to launch single validation rules.")
    parser.add_argument(
        "--platform-config-file",
        help="Path to your platform json configuration. "
             "Check the punchbox/configurations folder for ready to use configurations."
             " For example complete_punch_16G.json for a complete punch assuming 16Gb ram on your laptop.")
    parser.add_argument("--destroy-vagrant", help="Vagrant destroy", action="store_true")
    parser.add_argument("--generate-vagrantfile", help="Generate vagrantfile", action="store_true")
    parser.add_argument("--start-vagrant", help="Vagrant up", action="store_true")
    parser.add_argument("--os", help="Operating system to deploy with Vagrant. If set, it overwrites configuration")
    parser.add_argument("--interface", help="Interface to apply to deployed services")
    parser.add_argument("--security", help="Enable security deployment", action="store_true")
    args = parser.parse_args()

    if args.destroy_vagrant is True:
        destroy_vagrant_boxes()

    if args.platform_config_file is not None:
        platform_config = load_platform_config(args.platform_config_file)
        create_ppconf()

    if args.generate_vagrantfile is True:
        create_vagrantfile(platform_config, args.os)

    if args.start_vagrant is True:
        launch_vagrant_boxes()

    if args.deployer is not None:
        unzip_punch_archive(args.deployer)
        generate_model(platform_config, args.deployer, args.generate_vagrantfile, args.os, args.interface,
                       args.security)

    if parser.parse_args().security is not None:
        copyfile(platform_templates+"/"+secrets_template_file, secret_target)
    if args.punch_user_config is not None:
        import_user_resources(args.punch_user_config, args.platform_config_file, args.validation, args.os,)
        if "empty" not in args.platform_config_file:
            create_resolver(platform_config, args.security)
            if args.validation is True:
                create_check_platform(platform_config, args.punch_user_config, args.security)
                if args.elastalert_tool is not None:
                    copy_elastalert_tool(args.elastalert_tool)
        else:
            logging.info(" empty configuration detected: skipping \'resolv.hjson\' and \'check_platform\' generation")


if __name__ == "__main__":
    main()
