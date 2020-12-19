from setuptools import setup

setup(
    name='punchbox',
    version='0.1',
    py_modules=['punchbox'],
    install_requires=[
        'Click',
    ],
    entry_points='''
        [console_scripts]
        punchbox=punchbox:punchbox
    ''',
)