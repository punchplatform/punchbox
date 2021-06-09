import argparse
import json
import logging
import os
import subprocess
import sys
from json import JSONDecodeError
from sys import exit
from typing import Dict

import jinja2

# PUNCHBOX NAMES
VAGRANT_TEMPLATE_NAME = "Vagrantfile.j2"
SETTINGS_TEMPLATE_NAME = "punchplatform-deployment.settings.j2"

# PUNCHBOX DIRS
PUNCHBOX_DIR = os.environ.get('PUNCHBOX_DIR')
PUNCHBOX_BUILD_DIR = os.environ.get('PUNCHBOX_BUILD_DIR')
PUNCHPLATFORM_CONF_DIR = os.environ.get('PUNCHPLATFORM_CONF_DIR')
PUNCHBOX_TEMPLATES_DIR = os.environ.get('PUNCHBOX_TEMPLATES_DIR')

# PUNCHBOX FILES
VAGRANT_FILE = f"{PUNCHBOX_BUILD_DIR}/Vagrantfile"
MODEL_FILE = f"{PUNCHBOX_BUILD_DIR}/model.json"
SETTINGS_FILE = f"{PUNCHPLATFORM_CONF_DIR}/punchplatform-deployment.settings"

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
        logging.debug(' Loading platform configuration from file %s', platform_config_file)
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


def write_json(json_str: str, output: str):
    try:
        parsed_json_str = json.loads(json_str)
    except JSONDecodeError as err:
        bad_json = "/tmp/punchbox_bad.json"
        with open(bad_json, "w") as f:
            f.write(json_str)
        logging.error(f" Bad Json : {err}")
        print(f"Check {bad_json}")
        sys.exit(1)

    with open(output, 'w') as f:
        f.write(json.dumps(parsed_json_str, indent=4, sort_keys=False))


def render(template_dir: str, template_file: str, model: Dict):
    env = jinja2.Environment(loader=jinja2.FileSystemLoader(template_dir)) if isinstance(template_dir, str) \
        else template_dir
    template = env.get_template(template_file)
    return template.render(**model)


def generate_vagrantfile(platform_config):
    """
    Generate the vagrantfile from the given configuration and using the vagrant file template.
    The vagrant file is generated inside $PUNCHBOX_BUILD_DIR/vagrant
    :param platform_config: the platform configuration
    """
    vagrantfile_str = render(PUNCHBOX_TEMPLATES_DIR, VAGRANT_TEMPLATE_NAME, platform_config)
    with open(VAGRANT_FILE, "w") as f:
        f.write(vagrantfile_str)
    logging.debug(' Vagrantfile successfully generated in %s', VAGRANT_FILE)


def generate_model(platform_config) -> Dict:
    model = {}
    data = get_versions()

    # vagrant model
    model['version'] = data
    # os
    model['iface'] = platform_config['targets']['production_interface']
    # security
    if 'tls' in platform_config['punch'] and bool(platform_config['punch']['tls']):
        model['security_dir'] = f"{PUNCHPLATFORM_CONF_DIR}/security"

    model_str = json.dumps({**model, **platform_config['punch']}, indent=4, sort_keys=True)
    model_file = open(MODEL_FILE, "w+")
    model_file.write(model_str)
    model_file.close()
    logging.debug(' Platform model file successfully generated in %s', MODEL_FILE)
    return json.loads(model_str)


def generate_deployment_settings(model: Dict):
    """
    Call punchplatform-deployer.sh to generate the deployment settings file.
    This file is generated using the model file for input values, according to the jinja template in the deployment
    template directory.
    """
    settings_str = render(PUNCHBOX_TEMPLATES_DIR, SETTINGS_TEMPLATE_NAME, model)
    write_json(settings_str, SETTINGS_FILE)
    logging.debug(' Vagrantfile successfully generated in %s', SETTINGS_FILE)


def generate_resolv_file():
    with open(f"{PUNCHPLATFORM_CONF_DIR}/resolv.yaml", "w") as f:
        f.write("")


def main():
    logging.basicConfig(format='%(levelname)s:%(message)s', level=logging.INFO)

    if "PUNCHBOX_DIR" not in os.environ:
        logging.fatal(' PUNCHBOX_DIR environment variable is not set')
        exit(1)

    parser = argparse.ArgumentParser()
    parser.add_argument("--config", help="Path to your punchbox configuration file", required=True)
    args = parser.parse_args()

    platform_config = load_platform_config(args.config)
    generate_vagrantfile(platform_config)
    if "punch" in platform_config:
        model = generate_model(platform_config)
        generate_deployment_settings(model)
        generate_resolv_file()


if __name__ == "__main__":
    main()
