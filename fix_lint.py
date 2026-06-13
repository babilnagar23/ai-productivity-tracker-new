import os
import re
import subprocess

def get_eslint_output():
    result = subprocess.run(["npm.cmd", "run", "lint"], cwd="client", capture_output=True, text=True)
    return result.stdout

def fix_unused_vars(eslint_output):
    # Parses:  Line:Col  error  'VarName' is defined but never used  no-unused-vars
    # or 'React' is defined but never used
    file_errors = {}
    current_file = None
    for line in eslint_output.splitlines():
        if line.startswith("C:\\") or line.startswith("/"):
            current_file = line.strip()
            file_errors[current_file] = []
        elif "no-unused-vars" in line and current_file:
            match = re.search(r"'([^']+)' (is defined but never used|is assigned a value but never used)", line)
            if match:
                var_name = match.group(1)
                file_errors[current_file].append(var_name)
    
    for filepath, vars in file_errors.items():
        if not vars: continue
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            for var in vars:
                # Remove from import { Var1, Var2 }
                content = re.sub(r',\s*' + var + r'\b', '', content)
                content = re.sub(r'\b' + var + r'\s*,', '', content)
                # Remove import Var from '...'
                content = re.sub(r'import\s+' + var + r'\s+from\s+[^\n]+\n', '', content)
                # Remove import { Var } from '...'
                content = re.sub(r'import\s*\{\s*' + var + r'\s*\}\s*from\s+[^\n]+\n', '', content)
                # If there are empty braces left import {} from '...', remove the whole line
                content = re.sub(r'import\s*\{\s*\}\s*from\s+[^\n]+\n', '', content)
                
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
        except Exception as e:
            pass

eslint_out = get_eslint_output()
fix_unused_vars(eslint_out)
