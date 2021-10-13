# Punch Release Validation

The punch team provides and uses this tool to regularly validate the punch development releases. You can either launch a
campaign on-shot, or make it part of a cron so that it is run daily.

Files in the `templates` folder combined with the punch standalone examples provide the required test tenanst and
channels. We use these applications to check the correct end-to-end punch behavior.

You can also use your own channels and create your own validation templates to better fit to your specific use case.

## Basics

* the profile used to run test is based on the configurations/complete_punch_32G.json model
* the os (RHEL/Ubuntu/Centos) is changed as part of the chosen Makefile directive
* the punch operator used is 'vagrant' on server1
* the tenants and channels configuration is provided and installed automatically on vagrant@server1.
* the whole campaign can be automatically scheduled for automated tests.

## Quick Start

### Manual Campaign

Perform the following list of steps.

```sh
# deploy punch
make deploy

# Install the validation configuration files to your punch and run the tests
make local-integration-vagrant
```

## Manual Commands

This chapter is useful to launch only part of the deployment or test. It also is useful to understand the punchbox
tooling and the punch deployer tools.

Deploy your platform with a specific validation configuration :

```sh
punchbox --platform-config-file configurations/complete_punch_16G.json \
        --generate-vagrantfile \
        --punch-validation-config punch/configurations/validation/  \
        --deployer <path_to_your_punchplatform_deployer_zip> \
        --validation
punchplatform-deployer.sh --generate-platform-config --templates-dir punch/platform_template/ --model punch/build/model.json
punchplatform-deployer.sh --deploy -u vagrant
punchplatform-deployer.sh -cp -u vagrant
```

Once your deployment is successful you can check your platform health. Connect to your operator node, you will find a
shell in `pp-conf/check_platform.sh`
Global execution takes around 15 minutes.

To execute it:

```sh
ssh vagrant@server_operator
./pp-conf/check_platform.sh -f
```

This automatic test checks if all the test pass.
