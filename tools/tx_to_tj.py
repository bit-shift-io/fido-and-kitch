#!/usr/bin/env python3
"""
Convert Tiled .tx template files to .tj (JSON) format.
"""

import xml.etree.ElementTree as ET
import json
import glob
import os
import sys


def convert_value(val, val_type):
    """Convert string value to appropriate type based on type attribute."""
    if val_type == "int":
        return int(val)
    elif val_type == "float":
        return float(val)
    elif val_type == "bool":
        return val.lower() == "true"
    return val


def convert_tx_to_tj(tx_path):
    tree = ET.parse(tx_path)
    root = tree.getroot()

    tj_data = {
        "type": "template"
    }

    # Process referenced tileset
    tileset = root.find("tileset")
    if tileset is not None:
        tj_data["tileset"] = {
            "firstgid": int(tileset.attrib.get("firstgid", 1)),
            "source": tileset.attrib.get("source", "")
        }

    # Process main object
    obj = root.find("object")
    if obj is not None:
        object_data = {}

        # Simple attributes
        for attr in ["name", "type", "width", "height", "gid", "rotation"]:
            if attr in obj.attrib:
                val = obj.attrib[attr]
                # Convert numbers
                if val.isdigit() or (val.startswith('-') and val[1:].isdigit()):
                    val = int(val)
                elif val.replace('.', '', 1).replace('-', '', 1).isdigit():
                    val = float(val)
                object_data[attr] = val

        # Custom properties
        properties = obj.find("properties")
        if properties is not None:
            props_list = []
            for prop in properties.findall("property"):
                p_entry = {"name": prop.attrib.get("name")}
                p_type = prop.attrib.get("type", "string")
                val = prop.attrib.get("value", "")

                p_entry["type"] = p_type
                p_entry["value"] = convert_value(val, p_type)
                props_list.append(p_entry)
            object_data["properties"] = props_list

        # Handle polyline/polygon if present
        polyline = obj.find("polyline")
        if polyline is not None:
            points_str = polyline.attrib.get("points", "")
            points = []
            for pair in points_str.split():
                if pair:
                    x, y = pair.split(",")
                    points.append({"x": float(x), "y": float(y)})
            object_data["polyline"] = points

        polygon = obj.find("polygon")
        if polygon is not None:
            points_str = polygon.attrib.get("points", "")
            points = []
            for pair in points_str.split():
                if pair:
                    x, y = pair.split(",")
                    points.append({"x": float(x), "y": float(y)})
            object_data["polygon"] = points

        tj_data["object"] = object_data

    tj_path = os.path.splitext(tx_path)[0] + ".tj"
    with open(tj_path, "w") as f:
        json.dump(tj_data, f, indent=4)
    print(f"Converted: {tx_path} -> {tj_path}")


def main():
    # Default to res/editor directory if no args
    if len(sys.argv) > 1:
        pattern = sys.argv[1]
    else:
        pattern = "res/editor/*.tx"

    tx_files = glob.glob(pattern)
    if not tx_files:
        print(f"No .tx files found matching: {pattern}")
        return

    for tx_file in tx_files:
        try:
            convert_tx_to_tj(tx_file)
        except Exception as e:
            print(f"Error converting {tx_file}: {e}")

    print(f"Done. Converted {len(tx_files)} file(s).")


if __name__ == "__main__":
    main()