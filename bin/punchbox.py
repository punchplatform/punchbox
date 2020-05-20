import json
from jinja2 import Environment, FileSystemLoader
import vagrant
import logging
import subprocess
import zipfile
import argparse
import os
from distutils.dir_util import copy_tree
from shutil import copyfile

ROOT_DIR = os.path.dirname(os.path.abspath(__file__)) # This is your Project Root

# Repository layout 
top_dir = os.environ.get('PUNCHBOX_DIR')
bin_dir = top_dir + '/bin'
punch_dir = top_dir + '/punch/build'
vagrant_dir = top_dir + '/vagrant'
conf_dir = punch_dir + '/pp-conf'

# Templates path
vagrant_template_file = 'Vagrantfile.j2'
resolv_template_file = 'resolv.hjson.j2'
platform_template_shell = 'check_platform.sh.j2'

# Targets path
resolv_target = conf_dir+'/resolv.hjson'
vagrantfile_target = vagrant_dir+'/Vagrantfile'
platform_shell_target = conf_dir+'/check_platform.sh'
generated_model = punch_dir+'/model.json'

cots = ["punch", "minio" , "zookeeper", "spark", "pyspark", "elastic", "opendistro_security", "operator", "analytics-deployment",
        "analytics-client", "shiva", "gateway", "storm", "kafka", "logstash", "metricbeat", "filebeat", "packetbeat", "auditbeat"]

def unzip_punch_archive(deployer):
  deployer_folder_name=os.path.splitext(os.path.basename(deployer))[0]
  if not os.path.exists(punch_dir+"/"+deployer_folder_name):
    cmd='unzip {0} -d {1}'.format(deployer, punch_dir)
    os.system(cmd)
    with open(top_dir+"/activate.sh", "a") as activate:
      activate.write("export PATH=${PATH}:"+punch_dir+"/"+deployer_folder_name+"/bin")
    logging.info(' punchplatform deployer archive successfully unzipped')

def load_user_config(user_config_file):
  with open(user_config_file) as f:
    logging.info(' loading user configuration from file %s', user_config_file)
    return json.load(f)

## VAGRANT MANAGEMENT ##
def create_vagrantfile(user_config):
  file_loader = FileSystemLoader(vagrant_dir)
  env = Environment(loader=file_loader)
  vagrantfile_template = env.get_template(vagrant_template_file)
  vagrantfile_render = vagrantfile_template.render(vagrant=user_config["vagrant"])
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

## GENERATE FILE MODEL ##
def generate_model(user_config, deployer):
  data = {}
  model = {}
  for component in cots :
    version_of = punch_dir+"/"+os.path.splitext(os.path.basename(deployer))[0]+"/bin/punchplatform-versionof.sh"
    cmd = "{0} --legacy {1}".format(version_of, component)
    result = subprocess.check_output(cmd, shell=True)
    data[component] = result.decode("utf-8").rstrip()
  # vagrant model
  model['version'] = data
  if 'centos' in user_config['vagrant']['meta']['os']:
    model['iface'] = "eth1"
  else :
    model['iface'] = "enp0s8"
  # security model
  local_es_certs = "{}/../resources/security/certs/elasticsearch".format(ROOT_DIR)
  local_kibana_certs = "{}/../resources/security/certs/kibana".format(ROOT_DIR)
  local_gateway_keystore = "{}/../resources/security/keystores/gateway/gateway.keystore".format(ROOT_DIR)
  model['security'] = {}
  model['security']['local_es_certs'] = local_es_certs
  model['security']['local_kibana_certs'] = local_kibana_certs
  model['security']['local_gateway_keystore'] = local_gateway_keystore

  model = json.dumps({**model, **user_config['punch']})
  model_file = open(generated_model, "w+")
  model_file.write(model)
  model_file.close()
  logging.info(' platform model file successfully generated in %s', generated_model)
  return model

## CREATE PP-CONF ##
def create_ppconf():
  if not os.path.exists(conf_dir):
    os.makedirs(conf_dir)
    logging.info('Creating conf dir %s', conf_dir)

## CREATE RESOLV FILE ##
def create_resolver(user_config):
  file_loader = FileSystemLoader(bin_dir)
  env = Environment(loader=file_loader)
  resolv_template = env.get_template(resolv_template_file)
  resolv_render = resolv_template.render(punch=user_config["punch"])
  resolv_file = open(resolv_target, "w+")
  resolv_file.write(resolv_render)
  resolv_file.close()
  logging.info(' platform resolv.hjson successfully generated in %s', resolv_target)

## IMPORT CHANNELS AND RESOURCES IN PP-CONF ##
def import_resources(conf):
  copy_tree(conf, conf_dir)
  logging.info(' punchplatform configuration successfully imported oin %s', conf_dir)

## CREATE A VALIDATION SHELL ##
def create_platform_shell(user_config):
  file_loader = FileSystemLoader(bin_dir)
  env = Environment(loader=file_loader)
  platform_template = env.get_template(platform_template_shell)
  platform_render = platform_template.render(punch=user_config["punch"])
  platform_shell = open(platform_shell_target, "w+")
  platform_shell.write(platform_render)
  platform_shell.close()
  os.chmod(platform_shell_target, 0o775)
  logging.info(' punchplatform validation shell successfully generated in %s', platform_shell_target)

def main():

  logging.basicConfig(format='%(levelname)s:%(message)s', level=logging.DEBUG)
  if "PUNCHBOX_DIR" not in os.environ:
    logging.fatal(' PUNCHBOX_DIR environment variable is not set')
    sys.exit(1)

  parser = argparse.ArgumentParser()
  parser.add_argument("--deployer", help="Path to the punch deployer zip archive")
  parser.add_argument("--punch-conf", help="Path to Punchplatform conf folder with your channels and resources")
  parser.add_argument("--config", help="Path to your configuration",required=True)
  parser.add_argument("--destroy-vagrant", help="Vagrant destroy", action="store_true")
  parser.add_argument("--generate-vagrantfile", help="Generate vagrantfile", action="store_true")
  parser.add_argument("--start-vagrant", help="Vagrant up", action="store_true")

  if parser.parse_args().destroy_vagrant is True:
    destroy_vagrant_boxes()
  user_config=load_user_config(parser.parse_args().config)
  create_ppconf()
  if parser.parse_args().generate_vagrantfile is True:
    create_vagrantfile(user_config)
  if parser.parse_args().start_vagrant is True:
    launch_vagrant_boxes()
  if parser.parse_args().deployer is not None:
    unzip_punch_archive(parser.parse_args().deployer)
    generate_model(user_config, parser.parse_args().deployer)
  if parser.parse_args().punch_conf is not None:
    import_resources(parser.parse_args().punch_conf)
    create_resolver(user_config)
    create_platform_shell(user_config)

if __name__ == "__main__":
  main()

