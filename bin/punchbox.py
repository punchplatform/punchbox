import argparse
import fnmatch
import json
import logging
import os
import subprocess
import uuid
from distutils.dir_util import copy_tree
from shutil import copy2, copytree, ignore_patterns
from sys import exit
from typing import List, Dict

import jinja2
from jinja2.exceptions import UndefinedError

import vagrant

ROOT_DIR = os.path.dirname(os.path.abspath(__file__))  # This is your Project Root

# Repository layout
top_dir = os.environ.get('PUNCHBOX_DIR')
bin_dir = top_dir + '/bin'
build_dir = top_dir + '/punch/build'
vagrant_dir = top_dir + '/vagrant'
build_conf_dir = build_dir + '/pp-conf'
ansible_dir = top_dir + '/ansible'
ansible_templates_dir = ansible_dir + '/templates'
rules_target_dir = build_conf_dir + '/tenants/validation/channels/elastalert_validation/rules/'

# Templates path
vagrant_template_file = 'Vagrantfile.j2'
resolv_template_file = 'resolv.hjson.j2'
platform_template_shell = 'check_platform.sh.j2'
punchbox_inv_template = 'punchbox.inv.j2'
punchbox_playbook_template = 'punchbox.yml.j2'

# Targets path
resolv_target = build_conf_dir + '/resolv.hjson'
platform_shell_target = build_conf_dir + "/check_platform.sh"
vagrantfile_target = vagrant_dir + '/Vagrantfile'
generated_model = build_dir + '/model.json'
punchbox_inv_target = ansible_dir + '/punchbox.inv'
punchbox_playbook_target = ansible_dir + '/punchbox.yml'

cots = ["punch", "minio", "zookeeper", "spark", "pyspark", "elastic", "opendistro_security", "operator", "binaries",
        "analytics-deployment",
        "analytics-client", "shiva", "gateway", "storm", "kafka", "logstash", "metricbeat", "filebeat", "packetbeat",
        "auditbeat"]


def unzip_punch_archive(deployer):
    deployer_folder_name = os.path.splitext(os.path.basename(deployer))[0]
    if not os.path.exists(build_dir + "/" + deployer_folder_name):
        cmd = 'unzip {0} -d {1}'.format(deployer, build_dir)
        os.system(cmd)
        with open(top_dir + "/activate.sh", "a") as activate:
            activate.write("export PATH=${PATH}:" + build_dir + "/" + deployer_folder_name + "/bin")
        logging.info(' punchplatform deployer archive successfully unzipped')


def load_user_config(user_config_file):
    with open(user_config_file) as f:
        logging.info(' loading user configuration from file %s', user_config_file)
        return json.load(f)


def my_copy_tree(src, dst, ignore: List[str] = None):
    for item in os.listdir(src):
        if not item in ignore: 
            s = os.path.join(src, item)
            d = os.path.join(dst, item)
            if os.path.isdir(s):
                try:
                    copytree(s, d, ignore=ignore_patterns(*ignore))
                except FileExistsError:
                    pass
            else:
                map(lambda x: copy2(s, d), filter(lambda y: y not in s, ignore))


## VAGRANT MANAGEMENT ##
def create_vagrantfile(platform_config, vagrant_os: str=None):
  if not vagrant_os: 
    vagrant_os=platform_config["targets"]["meta"]["os"]
  file_loader = jinja2.FileSystemLoader(vagrant_dir)
  env = jinja2.Environment(loader=file_loader)
  vagrantfile_template = env.get_template(vagrant_template_file)
  vagrantfile_render = vagrantfile_template.render(targets=platform_config["targets"], os=vagrant_os)
  vagrantfile = open(vagrantfile_target, "w+")
  vagrantfile.write(vagrantfile_render)
  vagrantfile.close()
  logging.info(' Vagrantfile succesfully generated in %s', vagrantfile_target)

def launch_vagrant_boxes():
    v = vagrant.Vagrant(vagrant_dir, quiet_stdout=False, quiet_stderr=False)
    v.up()
    logging.info(' vagrant boxes successfully started')


def destroy_vagrant_boxes():
    if os.path.exists(vagrantfile_target):
        v = vagrant.Vagrant(vagrant_dir, quiet_stdout=False, quiet_stderr=False)
        v.destroy()
        logging.info(' vagrant boxes successfully stopped')


## PUNCHBOX MANAGEMENT ##
def custom_uuid_filter(*args):
    return uuid.uuid4()


def create_inventory(platform_config):
    file_loader = jinja2.FileSystemLoader(ansible_templates_dir)
    env = jinja2.Environment(loader=file_loader)
    env.filters['custom_uuid'] = custom_uuid_filter
    inventory_template = env.get_template(punchbox_inv_template)
    inventory_render = inventory_template.render(targets=platform_config["targets"])
    inventory = open(punchbox_inv_target, "w+")
    inventory.write(inventory_render)
    inventory.close()
    logging.info('Successful generation of inventory in %s', punchbox_inv_target)


def generate_playbook(deployer):
    version_of = build_dir + "/" + os.path.splitext(os.path.basename(deployer))[0] + "/bin/punchplatform-versionof.sh"
    cmd = "{0} --legacy {1}".format(version_of, "punch")
    result = subprocess.check_output(cmd, shell=True)
    file_loader = jinja2.FileSystemLoader(ansible_templates_dir)
    env = jinja2.Environment(loader=file_loader)
    playbook_template = env.get_template(punchbox_playbook_template)
    playbook_render = playbook_template.render(version=result.decode("utf-8").rstrip())
    playbook = open(punchbox_playbook_target, "w+")
    playbook.write(playbook_render)
    playbook.close()
    logging.info('Successful generation of playbook in %s', punchbox_playbook_target)


def patch_security_model(model: Dict):
    local_es_certs = "{}/../punch/resources/security/certs/elasticsearch".format(ROOT_DIR)
    local_kibana_certs = "{}/../punch/resources/security/certs/kibana".format(ROOT_DIR)
    local_user_certs = "{}/../punch/resources/security/certs/user".format(ROOT_DIR)
    local_gateway_keystore = "{}/../punch/resources/security/keystores/gateway/gateway.keystore".format(ROOT_DIR)
    model['security'] = {}
    model['security']['local_es_certs'] = local_es_certs
    model['security']['local_kibana_certs'] = local_kibana_certs
    model['security']['local_user_certs'] = local_user_certs
    model['security']['local_gateway_keystore'] = local_gateway_keystore

    return model


## GENERATE FILE MODEL ##
def generate_model(platform_config, deployer, vagrant_mode, vagrant_os: str = None, vagrant_interface: str = None,
                   security: bool = False):
    data = {}
    model = {}
    for component in cots:
        version_of = build_dir + "/" + os.path.splitext(os.path.basename(deployer))[
            0] + "/bin/punchplatform-versionof.sh"
        cmd = "{0} --legacy {1}".format(version_of, component)
        result = subprocess.check_output(cmd, shell=True)
        data[component] = result.decode("utf-8").rstrip()
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


## CREATE PP-CONF ##
def create_ppconf():
    if not os.path.exists(build_conf_dir):
        logging.info(' creating build configuration directory %s', build_conf_dir)
        os.makedirs(build_conf_dir)

## CREATE RESOLV FILE ##
def create_resolver(validation_config, platform_config, target_os, security=False):
  file_loader = jinja2.FileSystemLoader(validation_config + "/templates")
  env = jinja2.Environment(loader=file_loader)
  resolv_template = env.get_template(resolv_template_file)
  if not target_os:
    target_os=platform_config["targets"]["meta"]["os"]
  resolv_render = resolv_template.render(punch=platform_config["punch"],
                                         security=security)
  resolv_file = open(resolv_target, "w+")
  resolv_file.write(resolv_render)
  resolv_file.close()
  logging.info(' platform resolv.hjson successfully generated in %s', resolv_target)

# GENERATE ELASTALERT RULES
def create_elastalert_rules(validation_conf_dir, platform_config_file):
    platform_config= load_user_config(platform_config_file)
    loader = jinja2.FileSystemLoader(validation_conf_dir + '/tenants/validation/channels/elastalert_validation/rules/')
    env = jinja2.Environment(loader=loader)
    ltemplates = env.list_templates()
    for t in ltemplates: 
        rule_template = env.get_template(t)
        rule_render = rule_template.render(
            livedemo_api_url= os.getenv('LIVEDEMO_API_URL', default=''),
            user= os.getenv('USER', default='anonymous'),
            sysname= os.uname().sysname,
            release= os.uname().release,
            machine= os.uname().machine,
            vagrant_config= os.path.basename(platform_config_file),
            vagrant_os= platform_config["targets"]["meta"]["os"],
            branch= subprocess.check_output(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=os.environ.get('PP_PUNCH_DIR')).strip().decode(),
            commit= subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], cwd=os.environ.get('PP_PUNCH_DIR')).strip().decode())
        rule_file = open(rules_target_dir + t, "w+")
        rule_file.write(rule_render)
        rule_file.close()
        logging.info('rule %s successfully generated in build dir', t)

## FIND AND REPLACE - RESOLVER ALTERNATIVE FOR 5.* BRANCHES"
def find_replace(directory, find, replace, file_pattern):
    for path, dirs, files in os.walk(os.path.abspath(directory)):
        for filename in fnmatch.filter(files, file_pattern):
            filepath = os.path.join(path, filename)
            with open(filepath) as f:
                s = f.read()
            s = s.replace(find, replace)
            with open(filepath, "w") as f:
                f.write(s)

## IMPORT CHANNELS AND RESOURCES IN PP-CONF ##
def import_user_resources(punch_user_config):
    ignore = ["*.properties", "resolv.*"]
    my_copy_tree(punch_user_config, build_conf_dir, ignore=ignore)
    logging.info(' punch user configuration successfully imported in %s', build_conf_dir)


## IMPORT CHANNELS AND RESOURCES IN PP-CONF ##
def import_validation_resources(validation_conf_dir, platform_config):
    ignore = ["*.properties", "resolv.*", "binutils", "*.j2"]
    my_copy_tree(validation_conf_dir, build_conf_dir, ignore=ignore)

    ## HACK HACK HACK
    replace_spark = "spark"
    replace_es = "elasticsearch"

    try:
        find_replace(build_conf_dir + "/tenants/validation", "{{spark_master}}",
                     platform_config["punch"][replace_spark]["masters"][0], "*")
    except KeyError:
        logging.warn(' key \"{}\" not found. Skipping key for replacement'.format(replace_spark))
    try:
        find_replace(build_conf_dir + "/tenants", "{{elasticsearch_host}}",
                     platform_config["punch"][replace_es]["servers"][0], "*.yaml")
    except KeyError:
        logging.warn(' key \"{}\" not found. Skipping key for replacement'.format(replace_es))

    logging.info(' punch validation configuration successfully imported in %s', build_conf_dir)


## CREATE A VALIDATION SHELL ##
def create_platform_shell(validation_config, platform_config, security=False):
    file_loader = jinja2.FileSystemLoader(validation_config + "/templates")
    env = jinja2.Environment(loader=file_loader)
    platform_template = env.get_template(platform_template_shell)
    try:
        platform_render = platform_template.render(punch=platform_config["punch"])
        platform_shell = open(platform_shell_target, "w+")
        platform_shell.write(platform_render)
        platform_shell.close()
        os.chmod(platform_shell_target, 0o775)
        logging.info(' punchplatform validation shell successfully generated in %s', platform_shell_target)
    except UndefinedError as err:
        logging.error('cannot create \"check_platform\" properly: {}'.format(err))


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
        help="Path to a punch configuration folder with your channels and resources."\
        " If you have no idea, check and use the punchbox/punch/configurations/sample/conf folder.")
    parser.add_argument(
        "--punch-validation-config", 
        help="Path to Punchplatform conf folder with your channels and resources.")
    parser.add_argument(
        "--platform-config-file", 
        help="Path to your platform json configuration. Check the punchbox/configurations folder for ready to use configurations."\
        " For example complete_punch_16G.json for a complete punch assuming 16Gb ram on your laptop.", required=True)
    parser.add_argument("--destroy-vagrant", help="Vagrant destroy", action="store_true")
    parser.add_argument("--generate-vagrantfile", help="Generate vagrantfile", action="store_true")
    parser.add_argument("--start-vagrant", help="Vagrant up", action="store_true")
    parser.add_argument("--generate-inventory", help="Generate ansible inventory to launch Punch roles",
                        action="store_true")
    parser.add_argument("--generate-playbook", help="Generate ansible playbook to launch Punch roles",
                        action="store_true")
    parser.add_argument("--os", help="Operating system to deploy with Vagrant. If set, it overwrites configuration")
    parser.add_argument("--interface", help="Interface to apply to deployed services")
    parser.add_argument("--security", help="Enable security deployment", action="store_true")

    if parser.parse_args().destroy_vagrant is True:
        destroy_vagrant_boxes()

    platform_config = load_user_config(parser.parse_args().platform_config_file)
    create_ppconf()

    if parser.parse_args().generate_vagrantfile is True:
        create_vagrantfile(platform_config, parser.parse_args().os)
    
    if parser.parse_args().start_vagrant is True:
        launch_vagrant_boxes()
    
    if parser.parse_args().generate_inventory is True:
        create_inventory(platform_config)
    
    if parser.parse_args().deployer is not None:
        unzip_punch_archive(parser.parse_args().deployer)
        generate_model(platform_config, parser.parse_args().deployer, parser.parse_args().generate_vagrantfile,
                       parser.parse_args().os, parser.parse_args().interface, parser.parse_args().security)
        if parser.parse_args().generate_playbook is True:
            generate_playbook(parser.parse_args().deployer)

    if parser.parse_args().punch_validation_config is not None:
        import_validation_resources(parser.parse_args().punch_validation_config, platform_config)
        if "empty" not in parser.parse_args().platform_config_file:
            create_resolver(parser.parse_args().punch_validation_config, platform_config,  parser.parse_args().os, parser.parse_args().security)
            create_platform_shell(parser.parse_args().punch_validation_config, platform_config, parser.parse_args().security)
            create_elastalert_rules(parser.parse_args().punch_validation_config, parser.parse_args().platform_config_file)
        else:
            logging.info(" empty configuration detected: skipping \'resolv.hjson\' and \'check_platform\' generation")
    if parser.parse_args().punch_user_config is not None:
        import_user_resources(parser.parse_args().punch_user_config)

if __name__ == "__main__":
    main()
