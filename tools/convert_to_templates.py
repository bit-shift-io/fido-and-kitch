#!/usr/bin/env python3

"""
Tool to convert map objects to use templates.
Usage: python tools/convert_to_templates.py res/map/sandbox.tmj
"""

import json
import os
import sys

def load_templates():
    """Load all templates from res/editor/"""
    templates = {}
    editor_dir = 'res/editor'
    for file in os.listdir(editor_dir):
        if file.endswith('.tj'):
            name = file[:-3]  # remove .tj
            path = os.path.join(editor_dir, file)
            with open(path, 'r') as f:
                tmpl = json.load(f)
                if tmpl and 'object' in tmpl:
                    templates[name] = tmpl
    return templates

def find_template(obj, templates):
    """Find matching template for an object by type or gid"""
    # Try matching by type first
    for name, tmpl in templates.items():
        if tmpl['object'].get('type') == obj.get('type'):
            return name, tmpl
    # Fallback: match by gid
    for name, tmpl in templates.items():
        if tmpl['object'].get('gid') and obj.get('gid') and tmpl['object']['gid'] == obj['gid']:
            return name, tmpl
    return None, None

def props_equal(template_props, object_props):
    """Check if two property lists are equivalent"""
    if not template_props and not object_props:
        return True
    if not template_props or not object_props:
        return False
    if len(template_props) != len(object_props):
        return False
    
    tmpl_lookup = {p['name']: p for p in template_props}
    for p in object_props:
        tmpl_prop = tmpl_lookup.get(p['name'])
        if not tmpl_prop:
            return False
        if tmpl_prop['type'] != p['type']:
            return False
        if tmpl_prop['value'] != p['value']:
            return False
    return True

def get_diff_props(template_props, object_props):
    """Get properties that differ from template"""
    if not object_props:
        return None
    if not template_props:
        return object_props
    
    tmpl_lookup = {p['name']: p for p in template_props}
    diff = []
    for p in object_props:
        tmpl_prop = tmpl_lookup.get(p['name'])
        if not tmpl_prop or tmpl_prop['type'] != p['type'] or tmpl_prop['value'] != p['value']:
            diff.append(p)
    
    return diff if diff else None

def convert_map(map_path):
    with open(map_path, 'r') as f:
        map_data = json.load(f)
    
    templates = load_templates()
    print(f'Loaded {len(templates)} templates')
    
    converted = 0
    for layer in map_data.get('layers', []):
        if layer.get('type') == 'objectgroup' and 'objects' in layer:
            for obj in layer['objects']:
                tmpl_name, tmpl = find_template(obj, templates)
                if tmpl:
                    diff_props = get_diff_props(tmpl['object'].get('properties'), obj.get('properties'))
                    
                    # Build new object with template reference
                    new_obj = {
                        'id': obj['id'],
                        'template': f'../editor/{tmpl_name}.tj',
                        'x': obj['x'],
                        'y': obj['y']
                    }
                    
                    # Only include properties that differ from template
                    if diff_props:
                        new_obj['properties'] = diff_props
                    
                    # Preserve rotation if non-zero
                    if obj.get('rotation', 0) != 0:
                        new_obj['rotation'] = obj['rotation']
                    
                    # Preserve visible if false
                    if obj.get('visible') is False:
                        new_obj['visible'] = False
                    
                    # Preserve name if different from template
                    if obj.get('name') and obj['name'] != '' and obj['name'] != tmpl['object'].get('name', ''):
                        new_obj['name'] = obj['name']
                    
                    # Replace object in place
                    obj.clear()
                    obj.update(new_obj)
                    
                    converted += 1
                    print(f'  Converted object {obj["id"]} ({obj.get("type", "no type")}) -> {tmpl_name}')
                else:
                    print(f'  No template for object {obj["id"]} ({obj.get("type", "no type")})')
    
    # Write back with pretty formatting
    with open(map_path, 'w') as f:
        json.dump(map_data, f, indent=2)
    
    print(f'Converted {converted} objects. Saved to {map_path}')

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('Usage: python tools/convert_to_templates.py <map_file.tmj>')
        sys.exit(1)
    
    convert_map(sys.argv[1])