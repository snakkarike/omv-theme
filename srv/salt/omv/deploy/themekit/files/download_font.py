#!/usr/bin/env python3
import sys
import urllib.request
import urllib.parse
import re
import os
import shutil
import ssl
import json

def log(msg):
    log_dir = "/var/log/themekit"
    log_file = f"{log_dir}/font_download.log"
    os.makedirs(log_dir, exist_ok=True)
    # Rotate log if it exceeds 500 KB
    if os.path.exists(log_file) and os.path.getsize(log_file) > 512000:
        os.replace(log_file, f"{log_file}.1")
    with open(log_file, "a") as f:
        f.write(msg + "\n")

def finish(changed, comment, result=True):
    log(comment)
    print(json.dumps({
        "changed": changed,
        "comment": comment,
        "result": result
    }))
    sys.exit(0 if result else 1)

def write_if_changed(filepath, content):
    if os.path.exists(filepath):
        with open(filepath, "r") as f:
            if f.read() == content:
                return False
    with open(filepath, "w") as f:
        f.write(content)
    return True

def copy_if_changed(src, dst):
    if os.path.exists(dst):
        with open(src, "r") as fs, open(dst, "r") as fd:
            if fs.read() == fd.read():
                return False
    shutil.copy2(src, dst)
    return True

def main():
    font_name = os.environ.get('THEMEKIT_ACTIVE_FONT', '').strip(' "\'')
    active_css = "/var/www/openmediavault/assets/theme-font.css"
    
    if not font_name:
        changed = write_if_changed(active_css, "")
        finish(changed, "No font provided in environment.")
        return

    fonts_dir = "/var/www/openmediavault/assets/fonts"
    PLUGIN_DIR = "/usr/share/openmediavault/scripts/themekit"

    if font_name.lower() == "none":
        changed = write_if_changed(active_css, "")
        finish(changed, "Font cleared.")
        return

    with open(f'{PLUGIN_DIR}/google-fonts.json', 'r') as f:
        fonts_db = json.load(f)
        
    font_data = None
    if isinstance(fonts_db, list):
        for font in fonts_db:
            if font.get('family') == font_name:
                font_data = font
                break
    else:
        font_data = fonts_db.get(font_name)

    if not font_data:
        finish(False, f"Error: Font '{font_name}' not found in database.", result=False)

    os.makedirs(fonts_dir, exist_ok=True)
    
    font_id = font_name.lower().replace(' ', '_')
    cached_css = os.path.join(fonts_dir, f"{font_id}.css")
    
    if os.path.exists(cached_css):
        changed = copy_if_changed(cached_css, active_css)
        finish(changed, f"Used cached CSS for {font_name}.")

    encoded_font = urllib.parse.quote_plus(font_name)
    font_url = f"https://fonts.googleapis.com/css?family={encoded_font}&display=swap"
    log(f"Fetching CSS from: {font_url}")
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'
    }
    
    req = urllib.request.Request(font_url, headers=headers)
    ctx = ssl.create_default_context()
    ctx.check_hostname = True
    ctx.verify_mode = ssl.CERT_REQUIRED

    try:
        response = urllib.request.urlopen(req, context=ctx)
        css_content = response.read().decode('utf-8')
    except Exception as e:
        finish(False, f"Failed to fetch Google Fonts CSS: {e}", result=False)

    urls = re.findall(r"url\(['\"]?(https://[^)'\"]+)['\"]?\)", css_content)
    log(f"Found {len(urls)} font files to download.")
    
    for url in urls:
        parsed_url = urllib.parse.urlparse(url)
        filename = os.path.basename(parsed_url.path)
        if not filename:
            continue
            
        local_path = os.path.abspath(os.path.join(fonts_dir, filename))
        if not local_path.startswith(os.path.abspath(fonts_dir)):
            log(f"Security Error: Path traversal attempt blocked for {filename}")
            continue
            
        if not os.path.exists(local_path):
            try:
                font_req = urllib.request.Request(url, headers=headers)
                font_binary = urllib.request.urlopen(font_req, context=ctx).read()
                with open(local_path, 'wb') as f:
                    f.write(font_binary)
                log(f"Downloaded {filename}")
            except Exception as e:
                log(f"Failed to download font file {url}: {e}")
                continue
                
        css_content = css_content.replace(url, f"fonts/{filename}")

    with open(cached_css, "w") as f:
        f.write(css_content)
        
    changed = copy_if_changed(cached_css, active_css)
    finish(changed, f"Successfully downloaded and activated font {font_name}")

if __name__ == "__main__":
    main()
