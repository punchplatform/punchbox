import argparse
import json
import logging
import os
import subprocess
from sys import exit

import jinja2

# PUNCHBOX NAMES
VAGRANT_TEMPLATE_NAME = "Vagrantfile.j2"
SETTINGS_TEMPLATE_NAME = "punchplatform-deployment.settings.j2"
MODEL_NAME = "model.json"

# PUNCHBOX DIRS
PUNCHBOX_DIR = os.environ.get('PUNCHBOX_DIR')
PUNCHBOX_BUILD_DIR = os.environ.get('PUNCHBOX_BUILD_DIR')
PUNCHBOX_VAGRANT_DIR = os.environ.get('PUNCHBOX_VAGRANT_DIR')
PUNCHPLATFORM_CONF_DIR = os.environ.get('PUNCHPLATFORM_CONF_DIR')
PUNCHBOX_DEPLOYMENT_TEMPLATE_DIR = f"{PUNCHBOX_DIR}/punch/deployment_template"

# PUNCHBOX FILES
VAGRANT_FILE = PUNCHBOX_VAGRANT_DIR + '/Vagrantfile'
MODEL_FILE = f"{PUNCHBOX_BUILD_DIR}/{MODEL_NAME}"

components = ["punch", "minio", "zookeeper", "spark", "elastic", "opendistro_security", "operator", "binaries",
              "analytics-deployment", "analytics-client", "shiva", "gateway", "storm", "kafka", "logstash",
              "metricbeat", "filebeat", "packetbeat", "auditbeat"]


# FUNCTIONS
def load_platform_config(platform_config_file: str):
    """
    Read the given punchbox config file
    :param platform_config_file: absolute
    :return: the json object generated from the config file
    """
    with open(platform_config_file) as f:
        logging.info(' loading platform configuration from file %s', platform_config_file)
        return json.load(f)


def get_versions():
    """
    Call punchplatform-versionof.sh from the current deployer using the user's environment
    :return: Json data structure from the output of punchplatform-versionof.sh
    """
    data = {}
    for component in components:
        cmd = f"punchplatform-versionof.sh --legacy {component}"
        result = subprocess.check_output(cmd, shell=True)
        data[component] = result.decode("utf-8").rstrip()

    return data


def render_and_write(template_dir, template_file, target_file, *args, **kwargs):
    """
    Use jinja2 to generate a file from a given template
    :param template_dir: Where the template file is located
    :param template_file: The template file name
    :param target_file: the output file to write
    """
    env = jinja2.Environment(loader=jinja2.FileSystemLoader(template_dir)) \
        if isinstance(template_dir, str) else template_dir
    template = env.get_template(template_file)
    rendered_content = template.render(*args, **kwargs)
    target = open(target_file, "w+")
    target.write(rendered_content)
    target.close()


def generate_vagrantfile(platform_config):
    """
    Generate the vagrantfile from the given configuration and using the vagrant file template.
    The vagrant file is generated inside $PUNCHBOX_BUILD_DIR/vagrant
    :param platform_config: the platform configuration
    """
    render_and_write(PUNCHBOX_VAGRANT_DIR, VAGRANT_TEMPLATE_NAME, VAGRANT_FILE,
                     targets=platform_config["targets"])
    logging.info(' Vagrantfile successfully generated in %s', VAGRANT_FILE)


def generate_model(platform_config):
    model = {}
    data = get_versions()

    # vagrant model
    model['version'] = data
    # os
    model['iface'] = platform_config['targets']['production_interface']
    # security
    if 'tls' in platform_config['punch'] and bool(platform_config['punch']['tls']):
        model['security_dir'] = f"{PUNCHBOX_DIR}/../punch/resources/secrets"

    model = json.dumps({**model, **platform_config['punch']}, indent=4, sort_keys=True)
    model_file = open(MODEL_FILE, "w+")
    model_file.write(model)
    model_file.close()
    logging.info(' platform model file successfully generated in %s', MODEL_FILE)


def generate_deployment_settings():
    """
    Call punchplatform-deployer.sh to generate the deployment settings file.
    This file is generated using the model file for input values, according to the jinja template in the deployment
    template directory.
    """
    cmd = f"punchplatform-deployer.sh --generate-platform-config --templates-dir {PUNCHBOX_DEPLOYMENT_TEMPLATE_DIR} " \
          f"--model {MODEL_FILE}"
    subprocess.check_output(cmd, shell=True)
    logging.info(' Deployment settings successfully generated in %s', VAGRANT_FILE)


def main():
    logging.basicConfig(format='%(levelname)s:%(message)s', level=logging.DEBUG)

    if "PUNCHBOX_DIR" not in os.environ:
        logging.fatal(' PUNCHBOX_DIR environment variable is not set')
        exit(1)

    parser = argparse.ArgumentParser()
    parser.add_argument("--config", help="Path to your punchbox configuration file", required=True)
    args = parser.parse_args()

    platform_config = load_platform_config(args.config)
    generate_vagrantfile(platform_config)
    if "punch" in platform_config:
        generate_model(platform_config)
        generate_deployment_settings()


if __name__ == "__main__":
    main()
