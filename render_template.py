#!/usr/bin/env python3
# render_template.py - Tool to render Jinja2 device templates

import os
import sys
import yaml
import jinja2
import argparse
from pathlib import Path

def load_yaml_config(config_file):
    """Load YAML configuration from file"""
    with open(config_file, 'r') as f:
        try:
            config = yaml.safe_load(f)
            return config
        except yaml.YAMLError as e:
            print(f"Error parsing YAML file: {e}")
            sys.exit(1)

def render_template(template_file, config_data):
    """Render a Jinja2 template with the provided configuration data"""
    # Setup Jinja2 environment
    template_dir = os.path.dirname(template_file)
    template_name = os.path.basename(template_file)

    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(template_dir),
        trim_blocks=True,
        lstrip_blocks=True
    )

    try:
        template = env.get_template(template_name)
        return template.render(**config_data)
    except jinja2.exceptions.TemplateError as e:
        print(f"Error rendering template: {e}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description='Render Jinja2 device templates with YAML configuration')
    parser.add_argument('config_file', help='YAML configuration file')
    parser.add_argument('-o', '--output', help='Output file (default is stdout)')
    parser.add_argument('-t', '--template-dir', default='templates/devices',
                        help='Directory containing Jinja2 templates (default: templates/devices)')

    args = parser.parse_args()

    # Load the configuration
    config_data = load_yaml_config(args.config_file)

    # Get the template name from the configuration file
    template_name = config_data.get('template')
    if not template_name:
        print("Error: No 'template' key specified in the configuration file")
        sys.exit(1)

    # Full path to the template
    template_file = os.path.join(args.template_dir, template_name)
    if not os.path.exists(template_file):
        print(f"Error: Template file {template_file} not found")
        sys.exit(1)

    # Render the template
    rendered_output = render_template(template_file, config_data)

    # Write output
    if args.output:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(args.output, 'w') as f:
            f.write(rendered_output)
        print(f"Output written to {args.output}")
    else:
        print(rendered_output)

if __name__ == "__main__":
    main()
