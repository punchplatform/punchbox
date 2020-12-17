import click
import os

all_colors = (
    "black",
    "red",
    "green",
    "yellow",
    "blue",
    "magenta",
    "cyan",
    "white",
    "bright_black",
    "bright_red",
    "bright_green",
    "bright_yellow",
    "bright_blue",
    "bright_magenta",
    "bright_cyan",
    "bright_white",
)

@click.group()
def cli():
    pass

@cli.command()
@click.argument("url")
def deployer(url):
    """Demonstrates ANSI color support."""
    for color in "red", "green", "blue":
        click.echo(click.style(f"I am colored {url}", fg=color))
        click.echo(click.style(f"I am background colored {color}", bg=color))

@cli.command()
@click.option("--dir", type=click.Path(file_okay=False))
def ls(dir):
    """Demonstrates simple file listing color support."""
    click.echo("\n".join(os.listdir(dir)))

@cli.command()
def pager():
    """Demonstrates using the pager."""
    lines = []
    for x in range(200):
        lines.append(f"{click.style(str(x), fg='green')}. Hello World!")
    click.echo_via_pager("\n".join(lines))
