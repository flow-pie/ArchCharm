import json
import os
import re

def sync():
    colors_path = os.path.expanduser('~/.config/noctalia/colors.json')
    starship_path = os.path.expanduser('~/.config/prompt/starship.toml')
    
    if not os.path.exists(colors_path) or not os.path.exists(starship_path):
        return

    with open(colors_path, 'r') as f:
        colors = json.load(f)
    
    with open(starship_path, 'r') as f:
        content = f.read()

    # Mapping of Starship palette keys to Noctalia color keys
    mapping = {
        'accent': 'mPrimary',
        'lang': 'mTertiary',
        'go_docker': 'mSecondary',
        'git_status': 'mOnSurfaceVariant',
        'bg': 'mSurface',
        'fg': 'mOnSurface',
        'gray': 'mOutline'
    }

    for starship_key, noctalia_key in mapping.items():
        pattern = rf'{starship_key} = ".*"'
        replacement = f'{starship_key} = "{colors[noctalia_key]}"'
        content = re.sub(pattern, replacement, content)

    with open(starship_path, 'w') as f:
        f.write(content)

if __name__ == "__main__":
    sync()
