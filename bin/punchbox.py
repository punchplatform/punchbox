import argparse
import json
import logging
import os
import subprocess
from datetime import datetime
from shutil import copy2, copytree, ignore_patterns
from shutil import copyfile
from typing import List, Dict

import jinja2
from jinja2.exceptions import UndefinedError
from sys import exit

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
            ' punchbox: cannot guess deployer path from directories in \"{}\" because multiple possibilities exist :{}'.format(
                build_dir, deployers))
    return deployer_folder_name


def unzip_punch_archive(deployer):
    deployer_folder_name = check_archive_existence(os.path.splitext(os.path.basename(deployer))[0])
    if not os.path.exists(build_dir + "/" + deployer_folder_name + "/.unzipped"):
        logging.info(' punchbox: unzipping deployer from %s', deployer)
        cmd = 'unzip -q -o -d {1} {0}'.format(deployer, build_dir)
        rc = os.system(cmd)
        if rc == 0:
            deployer_folder_name = check_archive_existence(deployer_folder_name)
            with open(build_dir + "/" + deployer_folder_name + "/.unzipped", "w") as activate:
                activate.write(str(datetime.now()))
            logging.info(' punchbox: punchplatform deployer archive successfully unzipped')
        else:
            logging.error(" punchbox: unable to unzip deployer in folder with command '%s'" % cmd)
            exit(42)


def load_platform_config(platform_config_file):
    with open(platform_config_file) as f:
        logging.info(' punchbox: loading platform configuration from file %s', platform_config_file)
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


def get_versions(deployer):
    data = {}
    deployer_folder_name = check_archive_existence(os.path.splitext(os.path.basename(deployer))[0])
    for component in components:
        version_of = build_dir + "/" + deployer_folder_name + "/bin/punchplatform-versionof.sh"
        cmd = "{0} --legacy {1}".format(version_of, component)
        result = subprocess.check_output(cmd, shell=True)
        data[component] = result.decode("utf-8").rstrip()

    return data


# VAGRANT MANAGEMENT #
def create_vagrantfile(platform_config, vagrant_os: str = None):
    if not vagrant_os:
        vagrant_os = platform_config["targets"]["meta"]["os"]
    render_and_write(vagrant_dir, vagrant_template_file, vagrantfile_target,
                     targets=platform_config["targets"], os=vagrant_os)
    logging.info(' punchbox: Vagrantfile successfully generated in %s', vagrantfile_target)


def launch_vagrant_boxes():
    v = vagrant.Vagrant(vagrant_dir, quiet_stdout=False, quiet_stderr=False)
    v.up()
    logging.info(' punchbox: vagrant boxes successfully started')


def stop_vagrant_boxes():
    v = vagrant.Vagrant(vagrant_dir, quiet_stdout=False, quiet_stderr=False)
    v.halt()
    logging.info(' punchbox: vagrant boxes successfully stopped')


def destroy_vagrant_boxes():
    if os.path.exists(vagrantfile_target):
        v = vagrant.Vagrant(vagrant_dir, quiet_stdout=False, quiet_stderr=False)
        v.destroy()
        logging.info(' punchbox: vagrant boxes successfully stopped')


# GENERATE FILE MODEL #
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
        security_dir = "{}/../punch/resources/security".format(ROOT_DIR)
        model['security'] = {}
        model['security']['security_dir'] = security_dir

    model = json.dumps({**model, **platform_config['punch']}, indent=4, sort_keys=True)
    model_file = open(generated_model, "w+")
    model_file.write(model)
    model_file.close()
    logging.info(' punchbox: platform model file successfully generated in %s', generated_model)
    return model


# CREATE PP-CONF #
def create_ppconf():
    if not os.path.exists(build_conf_dir):
        logging.info(' punchbox: creating build configuration directory %s', build_conf_dir)
        os.makedirs(build_conf_dir)


# CREATE RESOLV FILE #
def create_resolver(platform_config, deployer, security=False):
    render_and_write(platform_templates, resolv_template_file, resolv_target,
                     punch=platform_config["punch"], security=security, versions=get_versions(deployer))
    logging.info(' punchbox: platform resolv.hjson successfully generated in %s', resolv_target)


# IMPORT CHANNELS AND RESOURCES IN PP-CONF #
def import_user_resources(punch_user_config, validation):
    if validation is False:
        # No need to import validation tenant
        ignore = ["*.properties", "resolv.*", "validation"]
    else:
        logging.info(' punchbox: configuration import with validation')
        # Need to render and import validation tenant files
        ignore = ["*.properties", "resolv.*", "*.j2"]
    my_copy_tree(punch_user_config, build_conf_dir, ignore=ignore)
    logging.info(' punchbox: punch configuration successfully imported in %s', build_conf_dir)


# CREATE A VALIDATION SHELL #
def create_check_platform(platform_config, security=False):
    try:
        render_and_write(platform_templates, check_platform_template, check_platform_target,
                         punch=platform_config['punch'], security=security)
        os.chmod(check_platform_target, 0o775)
        logging.info(' punchbox: punchplatform validation shell successfully generated in %s', check_platform_target)
    except UndefinedError as err:
        logging.error(' punchbox: cannot create \"check_platform\" properly: {}'.format(err))


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
        logging.fatal(' punchbox: PUNCHBOX_DIR environment variable is not set')
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
        "--platform-config-file",
        help="Path to your platform json configuration. "
             "Check the punchbox/configurations folder for ready to use configurations."
             " For example complete_punch_16G.json for a complete punch assuming 16Gb ram on your laptop.")
    parser.add_argument("--destroy-vagrant", help="Vagrant destroy", action="store_true")
    parser.add_argument("--generate-vagrantfile", help="Generate vagrantfile", action="store_true")
    parser.add_argument("--start-vagrant", help="Vagrant up", action="store_true")
    parser.add_argument("--stop-vagrant", help="Vagrant halt", action="store_true")
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

    if args.stop_vagrant is True:
        stop_vagrant_boxes()

    if args.deployer is not None:
        unzip_punch_archive(args.deployer)
        generate_model(platform_config, args.deployer, args.generate_vagrantfile, args.os, args.interface,
                       args.security)

    if args.security is True:
        copyfile(platform_templates + "/" + secrets_template_file, secret_target)

    if args.punch_user_config is not None:
        import_user_resources(args.punch_user_config, args.validation)
        if "empty" not in args.platform_config_file:
            create_resolver(platform_config, args.deployer, args.security)
            if args.validation is True:
                create_check_platform(platform_config, args.security)
        else:
            logging.info(" punchbox: empty configuration detected: skipping \'resolv.hjson\' "
                         "and \'check_platform\' generation")


if __name__ == "__main__":
    main()
