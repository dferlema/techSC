import os
import re

files = [
    'lib/core/widgets/app_drawer.dart', 
    'lib/features/auth/screens/login_page.dart', 
    'lib/features/catalog/screens/product_detail_page.dart', 
    'lib/features/reservations/screens/service_detail_page.dart'
]

def fix_broken_alpha(text):
    def repl(m):
        val = float(m.group(1))
        return f".withAlpha({int(round(val * 255))})"
    
    text = re.sub(r'\.withAlpha\(\(\s*([\d\.]+)\s*,\s*\*\s*255\)\.toInt\(\)\)', repl, text)
    return text

for f in files:
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    
    new_content = fix_broken_alpha(content)
    
    if content != new_content:
        with open(f, 'w', encoding='utf-8') as file:
            file.write(new_content)
