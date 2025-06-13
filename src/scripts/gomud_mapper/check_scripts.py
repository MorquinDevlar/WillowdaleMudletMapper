import json
import os
import sys

def check_directory(dir_path):
    print(f"=== Directory: {dir_path} ===")
    
    # Get lua files
    lua_files = []
    if os.path.exists(dir_path):
        for file in os.listdir(dir_path):
            if file.endswith('.lua'):
                lua_files.append(file[:-4])  # Remove .lua extension
    lua_files.sort()
    
    # Get names from scripts.json
    json_names = []
    json_path = os.path.join(dir_path, 'scripts.json')
    if os.path.exists(json_path):
        with open(json_path, 'r') as f:
            data = json.load(f)
            for item in data:
                if item.get('isFolder') != 'yes':
                    json_names.append(item['name'])
    
    print(f"Lua files: {lua_files}")
    print(f"JSON names: {json_names}")
    
    # Find discrepancies
    mismatches = []
    missing_from_json = []
    
    for lua_file in lua_files:
        if lua_file not in json_names:
            # Check case-insensitive match
            found = False
            for json_name in json_names:
                if lua_file.lower() == json_name.lower():
                    mismatches.append(f"{lua_file} \!= {json_name}")
                    found = True
                    break
            if not found:
                missing_from_json.append(lua_file)
    
    if mismatches:
        print(f"Mismatches: {mismatches}")
    if missing_from_json:
        print(f"Missing from JSON: {missing_from_json}")
    
    print()

# Check all directories
for dir_name in ['.', 'core', 'display', 'game_specific', 'mapping', 'navigation', 'tracking', 'updates']:
    check_directory(dir_name)
